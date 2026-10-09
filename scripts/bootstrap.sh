#!/usr/bin/env bash
# bootstrap.sh: new machine, once. Interactive.
#
#   sudo ~/dotfiles/scripts/bootstrap.sh
#
# Installs packages/bootstrap.txt (portable tools), asks the per-host
# questions, then applies configs. After that: `scripts/apply.sh`, plain
# `stow` for a single package, and the distro's package manager.

set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "run with sudo: sudo $0" >&2; exit 1; }

# shellcheck source=lib.sh
. "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh"

as_owner() {
  runuser -u "$OWNER" -- env HOME="$OWNER_HOME" USER="$OWNER" \
    XDG_RUNTIME_DIR="/run/user/$(id -u "$OWNER")" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$OWNER")/bus" "$@"
}

echo "==> $HOST_NAME ($DISTRO_FAMILY), repo owned by $OWNER"

case "$HOST_NAME" in
  archlinux|ubuntu|debian|localhost|localhost.localdomain|"")
    echo "WARNING: hostname '$HOST_NAME' looks like an installer default." >&2
    echo "  Set one first: hostnamectl set-hostname <name>, then re-run." >&2
    exit 1 ;;
esac

if [ ! -f "$HOST_FILE" ]; then
  echo
  echo "==> First run on $HOST_NAME. Answers go to hosts/$HOST_NAME.sh (commit it)."
  read -r -p "    Stow packages to skip (space-separated, blank for none): " drop
  read -r -p "    Force 'options no-aaaa' in resolv.conf (no IPv6 here)? [y/N] " ans
  case "$ans" in y|Y|yes|YES) no_aaaa=1 ;; *) no_aaaa=0 ;; esac
  as_owner tee "$HOST_FILE" >/dev/null <<EOF
# Per-host config for $HOST_NAME, written by scripts/bootstrap.sh. Safe to
# hand-edit. Sourced by scripts/lib.sh -- plain shell assignments only.
HOST_DROP_PKGS="$drop"
HOST_NO_AAAA=$no_aaaa
EOF
  . "$HOST_FILE"
fi

# --- packages (portable tools) ---------------------------------------------

# Ignore comments and the commented Hyprland block; install only active names.
mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$PKGDIR/bootstrap.txt")

case "$DISTRO_FAMILY" in
  arch)
    pacman -S --needed --noconfirm git stow curl base-devel file
    if ! have paru; then
      echo "==> building paru"
      tmp=$(as_owner mktemp -d)
      as_owner git clone -q https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
      (cd "$tmp/paru-bin" && as_owner makepkg --noconfirm)
      pacman -U --noconfirm "$tmp"/paru-bin/paru-bin-*.pkg.tar.zst
      rm -rf "$tmp"
    fi
    echo "==> packages/bootstrap.txt"
    as_owner paru -S --needed --noconfirm --skipreview --batchinstall "${pkgs[@]}"
    ;;
  debian)
    apt-get update -qq
    echo "==> packages/bootstrap.txt"
    # fd is fd-find on Debian; everything else matches or is absent.
    deb_pkgs=()
    for p in "${pkgs[@]}"; do
      [ "$p" = fd ] && p=fd-find
      deb_pkgs+=("$p")
    done
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${deb_pkgs[@]}"
    ;;
  *) echo "unsupported distro" >&2; exit 1 ;;
esac

echo "==> apply (system + user)"
bash "$DOTFILES/scripts/apply.sh" all

echo
echo "Done. Day to day:"
echo "  scripts/apply.sh              stow + user units"
echo "  stow -d home -t ~ <pkg>       one package"
echo "  sudo scripts/apply.sh system  after editing system/"
echo "  <distro pkg manager>          upgrades are yours"
