#!/usr/bin/env bash
# status.sh: would `apply` change anything? Read-only.
#
#   status.sh
#
# Reports the three config layers only: stow dry-run, system links, system
# copies. Packages are yours (`paru`), and manifests are a bootstrap list.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  YELLOW=; RESET=
fi

warn() { printf '  %s%s%s\n' "$YELLOW" "$1" "$RESET"; }

echo "Stow packages:"
for pkg in "${STOW_PACKAGES[@]}"; do
  if pkg_is_stowed "$pkg"; then
    echo "  $pkg: stowed"
  else
    warn "$pkg: not stowed"
  fi
done
if have stow; then
  while IFS= read -r line; do
    case "$line" in
      "LINK: "*)
        dst="${line#LINK: }"; dst="${dst%% => *}"
        warn "~/$dst: not linked"
        ;;
      *"cannot stow"*|*"existing target"*)
        warn "${line#"${line%%[! ]*}"}"
        ;;
    esac
  done < <(stow --no-folding -n -v -d "$STOW_DIR" -t "$HOME" "${STOW_PACKAGES[@]}" 2>&1 || true)
fi

echo
echo "System configs (symlinked):"
for pair in "${SYSTEM_LINKS[@]}"; do
  dst="${pair##*:}"
  if [ ! -e "$(src_path "${pair%%:*}")" ]; then
    echo "  $dst: source not shipped here"
  elif [ -L "$dst" ]; then
    echo "  $dst: linked"
  elif [ -e "$dst" ]; then
    warn "$dst: exists (not linked)"
  else
    warn "$dst: missing"
  fi
done

echo
echo "System configs (copied):"
for pair in "${SYSTEM_COPIES[@]}" "${SYSTEM_INSTALLS[@]}"; do
  src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
  if [ -L "$dst" ]; then
    warn "$dst: symlink, not a copy"
  elif [ ! -f "$dst" ]; then
    warn "$dst: missing"
  elif cmp -s "$src" "$dst"; then
    echo "  $dst: synced"
  else
    warn "$dst: out of sync"
  fi
done

# NetworkManager dispatcher scripts are copies, but live outside the lists.
nm="$DOTFILES/system/NetworkManager/dispatcher.d"
for f in 50-restart-sshfs 60-tzupdate; do
  dst="/etc/NetworkManager/dispatcher.d/$f"
  if [ ! -f "$dst" ]; then
    warn "$dst: missing"
  elif cmp -s "$nm/$f" "$dst"; then
    echo "  $dst: synced"
  else
    warn "$dst: out of sync"
  fi
done

pacnew=$(find /etc -xdev \( -name '*.pacnew' -o -name '*.dpkg-dist' \) 2>/dev/null | sort || true)
if [ -n "$pacnew" ]; then
  echo
  echo "Package-shipped configs to merge by hand:"
  printf '%s\n' "$pacnew" | sed 's/^/  /'
fi

if [ "$DISTRO_FAMILY" = arch ] && [ -r /var/log/pacman.log ]; then
  last=$(grep -F 'starting full system upgrade' /var/log/pacman.log 2>/dev/null | tail -1 |
           sed -n 's/^\[\([^]]*\)\].*/\1/p')
  [ -z "$last" ] || echo
  [ -z "$last" ] || echo "Last full upgrade: $last (you run paru -Syu)"
fi
