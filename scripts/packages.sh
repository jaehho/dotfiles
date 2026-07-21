#!/usr/bin/env bash
# packages.sh: declarative package management across pacman/AUR (paru),
# apt, cargo, npm, and uv. Interactive — every untracked install and every
# stale list entry is confirmed before files are modified.
#
# Source of truth: packages/<backend>.txt (one package per line, # comments).
# packages/common.txt is read in addition to arch.txt and ubuntu.txt — put
# packages with identical names across distros there.
#
# Usage:
#   packages.sh             # upgrade, prompt on drift, install missing
#   packages.sh --status    # read-only drift report
#
# Env:
#   SKIP_UPGRADE=1  skip the upgrade pass, still reconcile drift and install
#                   what's missing. sync.sh sets this when a full upgrade ran
#                   recently, so re-syncing after a config edit stays cheap.

set -euo pipefail
export LC_ALL=C  # `comm` requires byte-order sort.

DOTFILES="${DOTFILES:-$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)}"
PKGDIR="$DOTFILES/packages"

# Distro family detection mirrors the Makefile.
if command -v pacman >/dev/null 2>&1; then
  DISTRO=arch
elif command -v apt-get >/dev/null 2>&1; then
  DISTRO=debian
else
  DISTRO=unknown
fi

case "$DISTRO" in
  arch)   BACKENDS=(arch cargo npm uv) ;;
  debian) BACKENDS=(ubuntu cargo npm uv) ;;
  *)      BACKENDS=(cargo npm uv) ;;
esac

# mermaid-cli and mermaid-filter pull in puppeteer, which otherwise downloads a
# private ~150MB Chrome on every version bump — and hard-fails the whole npm
# sync if a prior download was interrupted (it leaves an empty cache dir and
# refuses to re-fetch, erroring instead). Point puppeteer at the system chromium
# and skip the bundled download. Guarded so hosts without chromium fall back to
# puppeteer's default behavior.
for _chrome in /usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome-stable; do
  if [ -x "$_chrome" ]; then
    export PUPPETEER_SKIP_DOWNLOAD=1
    export PUPPETEER_EXECUTABLE_PATH="$_chrome"
    break
  fi
done
unset _chrome

MODE=sync
[ "${1:-}" = "--status" ] && MODE=status

# --- unattended operation -------------------------------------------------
# A long AUR build outlives sudo's timestamp: nvidia's 440 MB download plus a
# Rust rebuild ran ~20 minutes here, and paru then died at the install step
# with "sudo: timed out reading password", losing the whole run. --sudoloop is
# the load-bearing flag — it refreshes the timestamp in the background.
# --noconfirm alone still stalls on a password prompt nobody is watching.
#
# --skipreview applies AUR PKGBUILD diffs without showing them. That is a real
# trade: an upstream AUR maintainer's change lands unread. Set PKG_INTERACTIVE=1
# to restore both the review step and the confirmation prompts.
if [ "${PKG_INTERACTIVE:-0}" = 1 ]; then
  PARU_FLAGS=(--sudoloop --review)
else
  PARU_FLAGS=(--sudoloop --noconfirm --skipreview)
fi

# --- backend abstraction --------------------------------------------------

backend_file() { echo "$PKGDIR/$1.txt"; }

backend_available() {
  case "$1" in
    arch)   command -v pacman >/dev/null 2>&1 ;;
    ubuntu) command -v apt-get >/dev/null 2>&1 ;;
    cargo)  command -v cargo  >/dev/null 2>&1 ;;
    npm)    command -v npm    >/dev/null 2>&1 ;;
    uv)     command -v uv     >/dev/null 2>&1 ;;
  esac
}

# Lists what's currently installed for a backend, one name per line, sorted.
backend_list_installed() {
  case "$1" in
    arch)
      { pacman -Qqen; pacman -Qqem | grep -vE -- '-debug$'; } | sort -u
      ;;
    ubuntu)
      # apt's "manually installed" set
      apt-mark showmanual 2>/dev/null | sort -u
      ;;
    cargo)
      # Report a crate as installed only if the binaries cargo recorded for it
      # are actually on disk. cargo's metadata outlives both manual deletions
      # and `--path` installs whose source directory is gone, so trusting it
      # blindly lets a phantom entry read as "in sync" forever. Verifying
      # against $CARGO_HOME/bin makes such entries surface as drift instead.
      local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
      local meta="$cargo_home/.crates2.json"
      if [ ! -r "$meta" ] || ! command -v jq >/dev/null 2>&1; then
        cargo install --list 2>/dev/null | awk '/^[^ ]/ { sub(/ v.*/, ""); print }' | sort -u
        return 0
      fi
      local crate bins b ok
      while read -r crate bins; do
        [ -n "$bins" ] || continue
        ok=1
        for b in $bins; do [ -x "$cargo_home/bin/$b" ] || ok=0; done
        [ "$ok" = 1 ] && echo "$crate"
      done < <(jq -r '.installs | to_entries[]
                      | (.key | split(" ")[0]) + " " + ((.value.bins // []) | join(" "))' \
                 "$meta") | sort -u
      ;;
    npm)
      # Filter out packages whose global node_modules dir is owned by
      # pacman (e.g. arch's `tree-sitter-cli` ships an npm module too).
      local prefix; prefix=$(npm root -g 2>/dev/null)
      npm ls -g --depth=0 --json 2>/dev/null \
        | jq -r '.dependencies // {} | keys[]' \
        | grep -vE '^(npm|corepack)$' \
        | while IFS= read -r pkg; do
            if [ -n "$prefix" ] && command -v pacman >/dev/null 2>&1 \
                 && pacman -Qo "$prefix/$pkg" >/dev/null 2>&1; then
              continue
            fi
            echo "$pkg"
          done \
        | sort -u
      ;;
    uv)
      uv tool list 2>/dev/null | awk '/^[a-zA-Z]/ {print $1}' | sort -u
      ;;
  esac
}

# Reads the list file(s), ignoring comments and blanks. arch/ubuntu also
# include packages/common.txt so cross-distro packages need one entry only.
#
# Per-line tags filter by hostname:
#   pkgname                      everywhere
#   pkgname @host1,host2         only those hosts (whitelist)
#   pkgname !host3               everywhere except those (blacklist)
backend_list_tracked() {
  local hostname; hostname="$(uname -n)"
  local files=()
  files+=("$(backend_file "$1")")
  case "$1" in arch|ubuntu) files+=("$PKGDIR/common.txt") ;; esac

  local file
  for file in "${files[@]}"; do
    [ -f "$file" ] || continue
    awk -v hn="$hostname" '
      /^[[:space:]]*(#|$)/ { next }
      {
        pkg = $1; tag = $2
        if (tag == "") { print pkg; next }
        first = substr(tag, 1, 1); rest = substr(tag, 2)
        # Wrap in commas for substring match: ",host1,host2," contains ",hn,"
        wrapped = "," rest ","; needle = "," hn ","
        if (first == "@") {
          if (index(wrapped, needle)) print pkg
        } else if (first == "!") {
          if (!index(wrapped, needle)) print pkg
        } else {
          print pkg  # unrecognized tag prefix — treat as untagged
        }
      }
    ' "$file"
  done | sort -u
}

# Filters the install list. Currently only `arch` needs filtering.
backend_filter_for_install() {
  case "$1" in
    arch)
      grep -vE -- '-debug$' \
        | if [ "${HOST_DEV_TOOLS:-0}" = 1 ]; then
            grep -vE '^(hypr-wallpaper-git|hypr-monitor-git)$'
          else
            cat
          fi
      ;;
    *) cat ;;
  esac
}

# Installs the tracked-but-missing packages for a backend.
backend_install_missing() {
  local backend="$1"
  local pkgs; pkgs=$(backend_list_tracked "$backend")
  [ -z "$pkgs" ] && return 0

  case "$backend" in
    arch)
      # Pass as args (not piped) so stdin stays on the TTY and pacman's
      # confirmation prompts work. Piping closes stdin once the package list
      # is consumed, which makes pacman bail at "Proceed with installation?".
      local filtered
      filtered=$(echo "$pkgs" | backend_filter_for_install arch)
      [ -z "$filtered" ] && return 0
      # shellcheck disable=SC2086
      paru -S --needed --batchinstall "${PARU_FLAGS[@]}" $filtered
      ;;
    ubuntu)
      # shellcheck disable=SC2086
      sudo apt-get install -y $pkgs
      ;;
    cargo)
      local installed; installed=$(backend_list_installed cargo)
      while IFS= read -r pkg; do
        grep -qx "$pkg" <<<"$installed" || cargo install "$pkg"
      done <<< "$pkgs"
      ;;
    npm)
      # `npm install -g` is idempotent (updates if newer). No sudo —
      # this respects ~/.npmrc's user prefix (~/.npm-global), so
      # puppeteer's Chrome cache lands in $HOME/.cache. Sudo'd installs
      # would scatter packages into /usr/lib/node_modules and cache into
      # /root/.cache, mismatched with what `npm ls -g` reads.
      # shellcheck disable=SC2086
      npm install -g $pkgs
      ;;
    uv)
      # `uv tool install` is idempotent.
      while IFS= read -r pkg; do uv tool install "$pkg"; done <<< "$pkgs"
      ;;
  esac
}

# Per-backend upgrade. Skip backends without a clean upgrade-all path
# rather than mandate an extra dependency (e.g., cargo-update).
backend_upgrade() {
  case "$1" in
    arch)   paru -Syu --batchinstall "${PARU_FLAGS[@]}" ;;
    ubuntu) sudo apt-get update -qq && sudo apt-get upgrade -y ;;
    uv)     uv tool upgrade --all 2>&1 || true ;;
    npm)    npm update -g 2>&1 || true ;;
    # cargo has no built-in upgrade-all; cargo-update (tracked in arch.txt)
    # supplies one. Guard on the binary rather than the package so a fresh host
    # — where cargo-update is still queued for install later in this same run —
    # skips the step instead of failing it.
    cargo)
      if command -v cargo-install-update >/dev/null 2>&1; then
        cargo install-update --all 2>&1 || true
      else
        echo "  cargo-update not installed yet — skipping (installs later this run)"
      fi
      ;;
  esac
}

# --- prompt helpers -------------------------------------------------------

# Yes/no/interactive prompt. Echoes 'y', 'n', or 'i'. Defaults to 'y'.
# Without a TTY, defaults to 'n' (no changes) so scripted runs don't mutate.
ask_yni() {
  local label="$1"
  if [ ! -t 0 ]; then echo n; return; fi
  printf '  %s [Y/n/i for per-item] ' "$label" >&2
  local ans; read -r ans </dev/tty
  case "$ans" in n|N) echo n ;; i|I) echo i ;; *) echo y ;; esac
}

# Per-item prompt. Defaults to 'n'.
ask_yn() {
  local label="$1"
  if [ ! -t 0 ]; then return 1; fi
  printf '    %s [y/N] ' "$label" >&2
  local ans; read -r ans </dev/tty
  case "$ans" in y|Y) return 0 ;; *) return 1 ;; esac
}

# --- core flows -----------------------------------------------------------

handle_drift() {
  local backend="$1"
  local file new stale tracked installed
  file=$(backend_file "$backend")
  [ -f "$file" ] || : > "$file"

  installed=$(backend_list_installed "$backend")
  tracked=$(backend_list_tracked "$backend")
  new=$(comm -23 <(echo "$installed")  <(echo "$tracked")  || true)
  stale=$(comm -23 <(echo "$tracked")   <(echo "$installed") || true)

  [ -z "$new$stale" ] && return 0

  echo "==> [$backend] drift"

  if [ -n "$new" ]; then
    echo "  Installed but not tracked in $file:"
    echo "$new" | sed 's/^/    + /'
    case "$(ask_yni "Add these to the list?")" in
      y) echo "$new" >> "$file" ;;
      i) while IFS= read -r pkg; do
           ask_yn "add  $pkg?" && echo "$pkg" >> "$file"
         done <<< "$new" ;;
      n) ;;
    esac
    LC_ALL=C sort -u -o "$file" "$file"
  fi

  if [ -n "$stale" ]; then
    echo "  Tracked in $file but not installed:"
    echo "$stale" | sed 's/^/    - /'
    # Stale entries may live in either the per-distro file or common.txt;
    # sed -i is a no-op when there's no match, so passing both is safe.
    local sed_targets=("$file")
    case "$backend" in arch|ubuntu) sed_targets+=("$PKGDIR/common.txt") ;; esac
    case "$(ask_yni "Remove these from the list?")" in
      y) while IFS= read -r pkg; do
           sed -i "/^${pkg}\$/d" "${sed_targets[@]}"
         done <<< "$stale" ;;
      i) while IFS= read -r pkg; do
           ask_yn "rm   $pkg?" && sed -i "/^${pkg}\$/d" "${sed_targets[@]}"
         done <<< "$stale" ;;
      n) ;;
    esac
  fi
}

# Move packages that appear in both arch.txt and ubuntu.txt into common.txt.
# Only untagged lines (NF==1, no @/! host tag) are eligible — tagged entries
# might mean different things on the two distros.
auto_dedup() {
  local common="$PKGDIR/common.txt"
  local arch_f="$PKGDIR/arch.txt"
  local ubuntu_f="$PKGDIR/ubuntu.txt"
  [ -f "$arch_f" ] && [ -f "$ubuntu_f" ] || return 0

  local dupes already new
  dupes=$(comm -12 \
    <(awk '!/^(#|$)/ && NF==1 { print $1 }' "$arch_f"   | sort -u) \
    <(awk '!/^(#|$)/ && NF==1 { print $1 }' "$ubuntu_f" | sort -u))
  already=$(awk '!/^(#|$)/ && NF==1 { print $1 }' "$common" 2>/dev/null | sort -u || true)
  new=$(comm -23 <(echo "$dupes") <(echo "$already") || true)
  [ -z "$new" ] && return 0

  echo "==> dedup: moving $(echo "$new" | wc -l) shared packages into common.txt"
  echo "$new" | sed 's/^/    /'
  echo "$new" >> "$common"
  sort -u -o "$common" "$common"
  while IFS= read -r pkg; do
    sed -i "/^${pkg}\$/d" "$arch_f" "$ubuntu_f"
  done <<< "$new"
}

cmd_sync() {
  auto_dedup
  local failed=() install_failed=()

  # 1. Upgrade
  if [ "${SKIP_UPGRADE:-0}" = 1 ]; then
    echo "==> upgrade skipped"
  else
    for backend in "${BACKENDS[@]}"; do
      backend_available "$backend" || continue
      echo "==> [$backend] upgrade"
      backend_upgrade "$backend" || failed+=("$backend/upgrade")
    done
  fi

  # 2. Install whatever's listed but missing.
  #
  # This MUST come before drift handling. Drift reports anything tracked but
  # not installed as "stale" and offers to delete it from the list — so a
  # package you just added by hand (or one a previous failed run never got to)
  # gets offered for removal before anything ever tried to install it. Running
  # the install first means the only entries drift can still call stale are the
  # ones that genuinely could not be installed.
  for backend in "${BACKENDS[@]}"; do
    backend_available "$backend" || continue
    echo "==> [$backend] install missing"
    backend_install_missing "$backend" || {
      failed+=("$backend/install")
      install_failed+=("$backend")
      echo "  !! [$backend] install failed — continuing with other backends"
    }
  done

  # 3. Drift handling (interactive) — left interactive on purpose. These
  # prompts are curation decisions about what belongs in the manifest, not
  # package-manager noise, and auto-answering them silently rewrites the lists.
  #
  # Skipped entirely for any backend whose install just failed: the failure
  # leaves tracked-but-not-installed entries that drift would then offer to
  # delete from the manifest. That is exactly how cargo-update got dropped —
  # one unrelated AUR package broke the transaction, and the next prompt
  # proposed removing the package that never got its chance to install.
  for backend in "${BACKENDS[@]}"; do
    backend_available "$backend" || continue
    if [[ " ${install_failed[*]:-} " == *" $backend "* ]]; then
      echo "==> [$backend] drift check skipped (install failed this run)"
      continue
    fi
    handle_drift "$backend"
  done

  if [ ${#failed[@]} -gt 0 ]; then
    echo
    echo "!! package steps that failed: ${failed[*]}"
    return 1
  fi
}

cmd_status() {
  for backend in "${BACKENDS[@]}"; do
    if ! backend_available "$backend"; then
      echo "[$backend] (tool not installed — skipped)"
      continue
    fi
    local file installed tracked new stale
    file=$(backend_file "$backend")
    [ -f "$file" ] || : > "$file"
    installed=$(backend_list_installed "$backend")
    tracked=$(backend_list_tracked "$backend")
    new=$(comm -23   <(echo "$installed") <(echo "$tracked")  || true)
    stale=$(comm -23 <(echo "$tracked")   <(echo "$installed") || true)

    if [ -z "$new$stale" ]; then
      echo "[$backend] in sync"
    else
      echo "[$backend]"
      if [ -n "$new"   ]; then echo "$new"   | sed 's/^/  + /'; fi
      if [ -n "$stale" ]; then echo "$stale" | sed 's/^/  - /'; fi
    fi
  done
}

case "$MODE" in
  sync)   cmd_sync ;;
  status) cmd_status ;;
esac
