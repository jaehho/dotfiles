#!/usr/bin/env bash
# status.sh: read-only report of stow / system / service / package state.
# Never modifies anything. Lists come from lib.sh, so this cannot drift out of
# step with what sync.sh actually installs.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh"

YELLOW=$'\033[33m'
RESET=$'\033[0m'

echo "Stow packages:"
for pkg in "${STOW_PACKAGES[@]}"; do
  if pkg_is_stowed "$pkg"; then
    echo "  $pkg: stowed"
  else
    echo "  $pkg: not stowed"
  fi
done

echo
echo "System configs (symlinked):"
for pair in "${SYSTEM_LINKS[@]}"; do
  dst="${pair##*:}"
  if [ -L "$dst" ]; then echo "  $dst: linked"
  elif [ -e "$dst" ]; then echo "  $dst: exists (not linked)"
  else echo "  $dst: missing"
  fi
done

echo "System configs (copied):"
for pair in "${SYSTEM_COPIES[@]}"; do
  src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
  if [ ! -f "$dst" ]; then
    echo "  $dst: missing"
  elif cmp -s "$src" "$dst"; then
    echo "  $dst: synced"
  else
    printf '  %s: %sout of sync%s\n' "$dst" "$YELLOW" "$RESET"
  fi
done

echo
echo "Services:"
for svc in keyd sshfs-ice sshfs-cdn sshfs-msi restic-backup.timer; do
  case "$svc" in
    keyd) active="$(systemctl is-active "$svc" 2>/dev/null || true)" ;;
    *)    active="$(systemctl --user is-active "$svc" 2>/dev/null || true)" ;;
  esac
  if [ "$active" = active ]; then echo "  $svc: active"; else echo "  $svc: inactive"; fi
done

echo
echo "Packages:"
DOTFILES="$DOTFILES" bash "$DOTFILES/scripts/packages.sh" --status | sed 's/^/  /'

# --- maintenance ----------------------------------------------------------
# State that stays invisible until it bites: a kernel upgrade that needs a
# reboot, a cache quietly eating tens of GB, orphans, and .pacnew files
# shadowing configs. Every command here is read-only and needs no sudo.
if [ "$DISTRO_FAMILY" = arch ]; then
  echo
  echo "Maintenance:"
  row() { printf '  %-18s %s\n' "$1" "$2"; }

  if have checkupdates; then
    pending="$(checkupdates 2>/dev/null || true)"
    n_pending="$(printf '%s' "$pending" | grep -c . || true)"
    # Here-string, not a pipe: `grep -q` SIGPIPEs its producer, which trips
    # `set -o pipefail`.
    kernel_note=""
    grep -qE '^linux ' <<<"$pending" && kernel_note=" (includes kernel)"
    row "pending updates:" "$n_pending$kernel_note"
  else
    row "pending updates:" "unknown — pacman-contrib not installed"
  fi

  # The functional signal, not a version-string compare: uname reports
  # 7.0.14-arch1-1 where pacman says 7.0.14.arch1-1 (dash vs dot). What
  # actually breaks is module loading, so test for the module directory.
  if [ -d "/usr/lib/modules/$(uname -r)" ]; then
    row "reboot required:" "no"
  else
    row "reboot required:" "${YELLOW}yes — running kernel's modules are gone${RESET}"
  fi

  cache="$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1 || true)"
  if have paccache; then
    # paccache prints "no candidate packages found for pruning" instead of a
    # size when there is nothing to reclaim, so fall back to "none".
    saved() {
      local out
      out="$(paccache -d "$@" 2>&1 | grep -oE 'disk space saved: [0-9.]+ [KMG]iB' || true)"
      printf '%s' "${out#*saved: }"
    }
    old="$(saved)"; gone="$(saved -uk0)"
    row "pacman cache:" "${cache:-?} (reclaimable: ${old:-none} old, ${gone:-none} removed)"
  else
    row "pacman cache:" "${cache:-?}"
  fi

  orphans="$(pacman -Qtdq 2>/dev/null || true)"
  n_orph="$(printf '%s' "$orphans" | grep -c . || true)"
  if [ "$n_orph" -gt 0 ]; then
    orph_size="$(printf '%s\n' "$orphans" | xargs -r pacman -Qi 2>/dev/null |
      awk -F': +' '/Installed Size/{v=$2; sub(/ .*/,"",v); u=$2;
        if(u~/KiB/)v/=1024; else if(u~/GiB/)v*=1024; s+=v} END{printf "%.0f MiB", s}')"
    row "orphans:" "$n_orph ($orph_size) — review before removing, -bin pkgs underdeclare deps"
  else
    row "orphans:" "0"
  fi

  pacnew="$(find /etc -name '*.pacnew' -o -name '*.pacsave' 2>/dev/null || true)"
  n_pacnew="$(printf '%s' "$pacnew" | grep -c . || true)"
  row ".pacnew/.pacsave:" "$n_pacnew"
  [ "$n_pacnew" -gt 0 ] && printf '%s\n' "$pacnew" | sed 's/^/      /'
fi
