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

MODE=sync
[ "${1:-}" = "--status" ] && MODE=status

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
      cargo install --list 2>/dev/null | awk '/^[^ ]/ { sub(/ v.*/, ""); print }' | sort -u
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
      echo "$pkgs" | backend_filter_for_install arch \
        | paru -S --needed --batchinstall -
      ;;
    ubuntu)
      # shellcheck disable=SC2086
      sudo apt-get install -y $pkgs
      ;;
    cargo)
      local installed; installed=$(backend_list_installed cargo)
      while IFS= read -r pkg; do
        echo "$installed" | grep -qx "$pkg" || cargo install "$pkg"
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
    arch)   paru -Syu --batchinstall ;;
    ubuntu) sudo apt-get update -qq && sudo apt-get upgrade -y ;;
    uv)     uv tool upgrade --all 2>&1 || true ;;
    npm)    npm update -g 2>&1 || true ;;
    cargo)  : ;;  # use `cargo-update` (cargo install-update -a) if you want this
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
  # 1. Upgrade
  for backend in "${BACKENDS[@]}"; do
    backend_available "$backend" || continue
    echo "==> [$backend] upgrade"
    backend_upgrade "$backend"
  done

  # 2. Drift handling (interactive)
  for backend in "${BACKENDS[@]}"; do
    backend_available "$backend" || continue
    handle_drift "$backend"
  done

  # 3. Install whatever's listed but missing
  for backend in "${BACKENDS[@]}"; do
    backend_available "$backend" || continue
    echo "==> [$backend] install missing"
    backend_install_missing "$backend"
  done
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
