#!/usr/bin/env bash
# packages.sh: declarative packages across pacman/AUR (paru), apt, cargo, npm
# and uv. Run by converge.sh; never prompts.
#
# Source of truth: packages/<backend>.txt (one package per line, # comments),
# except arch, which is a directory of category files: packages/arch/*.txt.
# packages/common.txt is read in addition to both arch and ubuntu -- put
# packages with identical names across distros there.
#
#   packages.sh system    as root: upgrade (gated), install missing, report drift
#   packages.sh user      as the owner: the same for cargo, npm and uv
#   packages.sh --status  read-only drift report, for status.sh
#
# Nothing here edits the manifests. Installed-but-untracked and
# tracked-but-uninstallable packages are decisions: filing a package, or
# dropping it, is the owner's call. New arch packages go in
# packages/arch/99-inbox.txt until filed.

set -euo pipefail
export LC_ALL=C  # `comm` requires byte-order sort.

# shellcheck source=lib.sh
. "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh"

MODE="${1:---status}"
case "$MODE" in
  system)   case "$DISTRO_FAMILY" in arch) BACKENDS=(arch) ;; debian) BACKENDS=(ubuntu) ;; *) BACKENDS=() ;; esac ;;
  user)     BACKENDS=(cargo npm uv) ;;
  --status) case "$DISTRO_FAMILY" in arch) BACKENDS=(arch cargo npm uv) ;; debian) BACKENDS=(ubuntu cargo npm uv) ;; *) BACKENDS=(cargo npm uv) ;; esac ;;
  *) echo "usage: packages.sh system|user|--status" >&2; exit 2 ;;
esac

# mermaid-cli and mermaid-filter pull in puppeteer, which otherwise downloads a
# private ~150MB Chrome on every version bump -- and hard-fails the whole npm
# install if a prior download was interrupted. Point it at the system browser.
for _chrome in /usr/bin/google-chrome-stable /usr/bin/chromium /usr/bin/chromium-browser; do
  if [ -x "$_chrome" ]; then
    export PUPPETEER_SKIP_DOWNLOAD=1
    export PUPPETEER_EXECUTABLE_PATH="$_chrome"
    break
  fi
done
unset _chrome

# --- running paru from root -----------------------------------------------
# paru refuses to run as root, and it installs through `sudo pacman`. So the
# system half runs it as the owner, under a pacman-only NOPASSWD rule that
# exists for this process's lifetime and no longer. It opens nothing new: the
# owner can already reach root (docker group, and this repo is applied as root).
#
# --skipreview applies AUR PKGBUILD diffs unread. That is the trade of an
# unattended upgrade; `paru -Sua --review` by hand restores it.
PARU_FLAGS=(--noconfirm --skipreview --batchinstall)
SUDOERS=/etc/sudoers.d/90-dotfiles-converge

as_owner() {
  if [ "$(id -u)" = 0 ]; then
    runuser -u "$OWNER" -- env -i HOME="$OWNER_HOME" USER="$OWNER" LOGNAME="$OWNER" \
      LANG=C.UTF-8 PATH="$OWNER_HOME/.local/bin:/usr/local/bin:/usr/bin" "$@"
  else
    "$@"
  fi
}

grant_pacman() {
  local tmp; tmp=$(mktemp)
  printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$OWNER" > "$tmp"
  chmod 0440 "$tmp"
  visudo -cqf "$tmp"
  install -m 0440 -o root -g root "$tmp" "$SUDOERS"
  rm -f "$tmp"
  trap revoke_pacman EXIT
}
revoke_pacman() { rm -f "$SUDOERS"; }

# --- backend abstraction --------------------------------------------------

# Every file contributing tracked packages for a backend, one path per line.
#
# arch is split into packages/arch/<NN>-<category>.txt so the manifest is
# readable by category instead of one 200-line alphabetical wall.
backend_files() {
  local f
  case "$1" in
    arch)
      for f in "$PKGDIR"/arch/*.txt; do [ -e "$f" ] && echo "$f"; done
      echo "$PKGDIR/common.txt"
      ;;
    ubuntu)
      echo "$PKGDIR/ubuntu.txt"
      echo "$PKGDIR/common.txt"
      ;;
    *) echo "$PKGDIR/$1.txt" ;;
  esac
}

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
      # apt's "manually installed" set, minus the release's base system, which
      # apt counts as manual too: what the installer put down, the base
      # priorities, and shared libraries (images mark those manual). A tracked
      # package stays, whatever its priority.
      comm -23 <(apt-mark showmanual 2>/dev/null | sort -u) <(comm -23 <({
        dpkg-query -W -f='${Package} ${Priority} ${Section}\n' |
          awk '$2 ~ /^(required|important|standard)$/ || $3 ~ /(^|\/)libs$/ { print $1 }'
        gzip -dc /var/log/installer/initial-status.gz 2>/dev/null | sed -n 's/^Package: //p'
      } | sort -u) <(backend_list_tracked ubuntu))
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
  mapfile -t files < <(backend_files "$1")

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
      grep -vE -- '-debug$'
      ;;
    *) cat ;;
  esac
}

# Tracked, wanted on this host, and not installed — one name per line.
#
# Every install path goes through this rather than handing the package manager
# the whole tracked list and letting --needed sort it out. That shortcut cost
# 10-30s on every single run: paru re-resolves all ~190 names against the AUR
# RPC (a network round trip that has failed mid-sync), re-clones every -git
# package to evaluate pkgver(), and prints a screen of "is up to date --
# skipping". Computing the set locally takes well under a second, so the
# common case — nothing missing — becomes a no-op instead.
#
# Both sides are already sorted (LC_ALL=C at the top of this file), which is
# what comm needs.
backend_missing() {
  local backend="$1" tracked installed
  tracked=$(backend_list_tracked "$backend" | backend_filter_for_install "$backend")
  [ -z "$tracked" ] && return 0
  installed=$(backend_list_installed "$backend")
  comm -23 <(echo "$tracked") <(echo "$installed") || true
}

# --- installing ------------------------------------------------------------

install_missing() {
  local backend="$1" pkgs promote
  pkgs=$(backend_missing "$backend")
  [ -n "$pkgs" ] || return 0
  echo "==> [$backend] installing: $(echo $pkgs)"
  # shellcheck disable=SC2086
  case "$backend" in
    arch)
      as_owner paru -S --needed "${PARU_FLAGS[@]}" $pkgs
      # --needed leaves the install reason alone, so a tracked package that
      # something else depends on stays a "dependency", invisible to
      # `pacman -Qqe`, and drift would call it missing forever. Being in the
      # manifest is the explicit request. See ISSUES.md.
      promote=$(comm -12 <(echo "$pkgs" | sort -u) <(pacman -Qqd | sort -u) || true)
      [ -z "$promote" ] || pacman -D -q --asexplicit -- $promote
      ;;
    ubuntu) DEBIAN_FRONTEND=noninteractive apt-get install -y $pkgs ;;
    cargo)  while IFS= read -r p; do cargo install "$p"; done <<< "$pkgs" ;;
    # No sudo: ~/.npmrc's user prefix keeps globals where `npm ls -g` reads.
    npm)    npm install -g $pkgs ;;
    uv)     while IFS= read -r p; do uv tool install "$p"; done <<< "$pkgs" ;;
  esac
}

# Installed but untracked, and tracked but still not installed after the
# install above: both are the owner's call. The id carries the lists, so the
# decision re-notifies only when they change.
report_drift() {
  local backend="$1" installed tracked new stale body=""
  installed=$(backend_list_installed "$backend")
  tracked=$(backend_list_tracked "$backend")
  new=$(comm -23 <(echo "$installed") <(echo "$tracked") || true)
  stale=$(comm -23 <(echo "$tracked" | backend_filter_for_install "$backend") <(echo "$installed") || true)
  [ -n "$new$stale" ] || return 0
  [ -z "$new" ]   || body+="Installed, not in packages/ (file under packages/$backend* or uninstall):"$'\n'"$(sed 's/^/  + /' <<<"$new")"$'\n'
  [ -z "$stale" ] || body+="In packages/ but not installed (fix the install or drop the entry):"$'\n'"$(sed 's/^/  - /' <<<"$stale")"
  printf '%s\n' "$body"
  decide "drift-$backend-$(digest_of <<<"$body")" \
    "$backend: $(grep -c . <<<"$new" || true) untracked, $(grep -c . <<<"$stale" || true) not installed" "$body"
}

# --- upgrading --------------------------------------------------------------

# AC unless a battery exists and no supply (Mains or USB-C) is online.
on_battery() {
  local p battery=
  for p in /sys/class/power_supply/*; do
    case "$(cat "$p/type" 2>/dev/null)" in
      Battery) battery=1 ;;
      Mains|USB) [ "$(cat "$p/online" 2>/dev/null)" = 1 ] && return 1 ;;
    esac
  done
  [ -n "$battery" ]
}

# Arch news newer than epoch $1, as "epoch<TAB>title<TAB>link", newest first.
# Manual interventions are announced here; an upgrade past one unread is the
# classic way to break an Arch install.
arch_news_since() {
  curl -fsS --max-time 20 https://archlinux.org/feeds/news/ | python3 -c '
import sys, email.utils, xml.etree.ElementTree as ET
since = int(sys.argv[1])
for item in ET.parse(sys.stdin).getroot().iter("item"):
    t = int(email.utils.parsedate_to_datetime(item.findtext("pubDate")).timestamp())
    if t > since:
        print(t, item.findtext("title"), item.findtext("link"), sep="\t")
' "$1"
}

# nvidia beta bumps deadlock paru (ISSUES.md "nvidia beta upgrade deadlocks
# paru"). Everything else upgrades; the beta set waits for the manual recipe.
nvidia_beta_hold() {
  local pending held
  pending=$(as_owner paru -Qua 2>/dev/null | awk '$1 ~ /nvidia.*-beta/ {print $1 " " $2 " -> " $4}' || true)
  [ -n "$pending" ] || return 0
  held=$(pacman -Qq | grep -E '^(lib32-)?(nvidia|opencl-nvidia).*-beta' | paste -sd, || true)
  decide "nvidia-beta-$(digest_of <<<"$pending")" \
    "nvidia beta update held back: it needs the manual build in ISSUES.md" \
    "$pending"$'\n'"Held: $held. Recipe: ISSUES.md \"make sync: nvidia beta upgrade deadlocks paru\", then reboot."
  echo "--ignore=$held"
}

UPGRADE_MAX_AGE=$(( 20 * 3600 ))   # daily timer, randomized: 24h would skip days

upgrade_arch() {
  local age last news id ignore before n
  age=$(upgrade_age)
  if [ -n "$age" ] && [ "$age" -lt "$UPGRADE_MAX_AGE" ]; then
    echo "==> [arch] upgraded $(fmt_age "$age") ago, not yet"
    return 0
  fi
  if on_battery; then
    echo "==> [arch] on battery, upgrade waits for AC"
    [ -n "$age" ] && [ "$age" -gt $(( 7 * 86400 )) ] &&
      decide "upgrade-battery-$(date +%G-%V)" "No upgrade for $(fmt_age "$age"): the machine is never on AC when converge runs" \
        "Plug in and run: dotfiles sync"
    return 0
  fi

  last=$(( $(date +%s) - ${age:-0} ))
  news=$(arch_news_since "$last")
  if [ -n "$news" ]; then
    id="arch-news-$(head -1 <<<"$news" | cut -f1)"
    if ! acked "$id"; then
      echo "==> [arch] upgrade held: Arch news since the last upgrade"
      decide "$id" "Upgrade held: read the Arch news posted since the last upgrade" \
        "$(cut -f2,3 <<<"$news" | tr '\t' ' ')"$'\n'"When nothing in it needs doing first: touch $ACK_DIR/$id"
      return 0
    fi
  fi

  ignore=$(nvidia_beta_hold | tail -1)
  echo "==> [arch] upgrade"
  before=$(pacman -Q)
  # shellcheck disable=SC2086
  as_owner paru -Syu "${PARU_FLAGS[@]}" $ignore
  n=$(comm -13 <(echo "$before") <(pacman -Q) | wc -l)
  echo "==> [arch] $n packages upgraded"
}

# cargo has no upgrade-all of its own (cargo-update supplies one), and Arch's
# rustup package never updates the toolchain, so crates outgrow it (ISSUES.md).
upgrade_tools() {
  local stamp="$DOTFILES_STATE/tools-upgraded"
  if [ -f "$stamp" ] && [ $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt "$UPGRADE_MAX_AGE" ]; then
    return 0
  fi
  echo "==> [tools] upgrade"
  have uv  && uv tool upgrade --all
  have npm && npm update -g
  have rustup && rustup update
  have cargo-install-update && cargo install-update --all
  mkdir -p "$DOTFILES_STATE" && touch "$stamp"
}

# --- modes ------------------------------------------------------------------

cmd_system() {
  [ "$(id -u)" = 0 ] || { echo "packages.sh system runs as root" >&2; exit 1; }
  [ ${#BACKENDS[@]} -gt 0 ] || return 0
  if ! online; then
    echo "==> offline: no upgrade or installs this run"
    report_drift "${BACKENDS[0]}"
    return 0
  fi
  case "$DISTRO_FAMILY" in
    arch)
      grant_pacman
      upgrade_arch
      install_missing arch
      ;;
    # unattended-upgrades (packages/ubuntu.txt) owns upgrades on Ubuntu.
    debian)
      apt-get update -qq
      install_missing ubuntu
      ;;
  esac
  report_drift "${BACKENDS[0]}"
}

# uv and Claude Code ship self-updating installers into ~/.local/bin on both
# distros; rustup comes from the distro but starts with no toolchain.
install_toolchains() {
  if ! have uv; then
    echo "==> [uv] installing"
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
  fi
  if ! have claude; then
    echo "==> [claude] installing"
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  if have rustup && ! rustup default >/dev/null 2>&1; then
    rustup default stable
  fi
  # Globals go to ~/.npm-global (on PATH in fish and the converge unit), not
  # the root-owned system prefix.
  if have npm && [ "$(npm config get prefix)" != "$HOME/.npm-global" ]; then
    npm config set prefix "$HOME/.npm-global"
  fi
}

cmd_user() {
  local backend failed=0
  if online; then
    install_toolchains || failed=1
    upgrade_tools || failed=1
    for backend in "${BACKENDS[@]}"; do
      backend_available "$backend" || continue
      install_missing "$backend" || { echo "!! [$backend] install failed"; failed=1; }
    done
  else
    echo "==> offline: no upgrades or installs this run"
  fi
  for backend in "${BACKENDS[@]}"; do
    if backend_available "$backend"; then
      report_drift "$backend"
    elif [ -n "$(backend_list_tracked "$backend")" ]; then
      decide "no-tool-$backend" "$backend is not installed, so packages/$backend.txt is not applied"
    fi
  done
  return "$failed"
}

cmd_status() {
  local backend installed tracked new stale
  for backend in "${BACKENDS[@]}"; do
    if ! backend_available "$backend"; then
      echo "[$backend] (tool not installed — skipped)"
      continue
    fi
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
  system)   cmd_system ;;
  user)     cmd_user ;;
  --status) cmd_status ;;
esac
