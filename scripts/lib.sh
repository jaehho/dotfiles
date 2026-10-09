#!/usr/bin/env bash
# lib.sh: shared configuration for apply.sh and status.sh.
#
# Sourced, never executed. Owns every list that both applying and reporting
# need, so adding a stow package or a system config is a one-line edit in
# exactly one place.

DOTFILES="${DOTFILES:-$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)}"
PKGDIR="$DOTFILES/packages"
STOW_DIR="$DOTFILES/home"     # stow packages; system/ holds what the system phase installs

# --- distro ---------------------------------------------------------------
# Detect by package manager rather than os-release ID so derivatives
# (Manjaro/EndeavourOS) resolve to their parent family.
if command -v pacman >/dev/null 2>&1; then
  DISTRO_FAMILY=arch
elif command -v apt-get >/dev/null 2>&1; then
  DISTRO_FAMILY=debian
else
  DISTRO_FAMILY=unknown
fi

# --- per-host choices -----------------------------------------------------
# Capability-based variation (distro, gcloud, ssh reachability) is detected at
# use site. This file holds *choices* only, written by scripts/bootstrap.sh.
#
# HOST_DROP_PKGS  : stow packages to skip on this host
# HOST_NO_AAAA    : 1 = install the NM dispatcher forcing 'options no-aaaa'
HOST_NAME="$(uname -n)"
HOST_FILE="$DOTFILES/hosts/$HOST_NAME.sh"
# shellcheck source=/dev/null
[ -f "$HOST_FILE" ] && . "$HOST_FILE"

HOST_DROP_PKGS="${HOST_DROP_PKGS:-}"
HOST_NO_AAAA="${HOST_NO_AAAA:-0}"

# --- stow packages --------------------------------------------------------
COMMON_STOW=(fish git tmux nvim claude codex sshfs bin laptop kitty ssh mime restic zathura
             visidata tridactyl tailscale audio marimo theme)
ARCH_STOW=(hypr swaync rofi waybar sunshine)

STOW_PACKAGES=()
for _p in "${COMMON_STOW[@]}"; do STOW_PACKAGES+=("$_p"); done
if [ "$DISTRO_FAMILY" = arch ]; then
  for _p in "${ARCH_STOW[@]}"; do STOW_PACKAGES+=("$_p"); done
fi
# Drop anything this host opted out of.
if [ -n "$HOST_DROP_PKGS" ]; then
  _kept=()
  for _p in "${STOW_PACKAGES[@]}"; do
    [[ " $HOST_DROP_PKGS " == *" $_p "* ]] || _kept+=("$_p")
  done
  STOW_PACKAGES=("${_kept[@]}")
fi
unset _p _kept

# Files inside a stow package that sync must neither link nor back up: the live
# copy is generated at runtime and owned by another process, so the repo copy is
# a seed/template rather than the source of truth. Each still needs bespoke
# handling at the end of phase_stow. Paths are repo-relative.
#
# Without this the pre-stow cleanup treats a generated file as a stray and moves
# it to .bak on every run, clobbering the previous backup each time.
STOW_SKIP=(
  "mime/.config/mimeapps.list"       # absolute symlink; GLib safe-write needs it
)

stow_skipped() {
  local needle="$1" s
  for s in "${STOW_SKIP[@]}"; do
    [ "$s" = "$needle" ] && return 0
  done
  return 1
}

# --- sshfs mounts (stow package only; enable the units by hand) ------------

# --- system configs -------------------------------------------------------
# Symlinked: read at runtime, so a link into the repo is fine.
# Format "src:dst"; src is relative to system/ unless it starts with '/'.
SYSTEM_LINKS=(
  "keyd/default.conf:/etc/keyd/default.conf"
  "libinput/local-overrides.quirks:/etc/libinput/local-overrides.quirks"
  "security/limits.d/10-rtprio.conf:/etc/security/limits.d/10-rtprio.conf"
  "sysctl/99-sysrq.conf:/etc/sysctl.d/99-sysrq.conf"
  "systemd/system-sleep/fuse-mounts:/usr/lib/systemd/system-sleep/fuse-mounts"
  "systemd/system-sleep/batenergy:/usr/lib/systemd/system-sleep/batenergy"
  "/usr/share/alsa/alsa.conf.d/99-pipewire-default.conf:/etc/alsa/conf.d/99-pipewire-default.conf"
)

# Arch-only drop-ins. See each conf for what it changes and why.
if [ "$DISTRO_FAMILY" = arch ]; then
  SYSTEM_LINKS+=(
    "systemd/paccache.service.d/10-uninstalled.conf:/etc/systemd/system/paccache.service.d/10-uninstalled.conf"
    "systemd/linux-modules-cleanup.service.d/10-prune-old.conf:/etc/systemd/system/linux-modules-cleanup.service.d/10-prune-old.conf"
    "systemd/reflector.service.d/10-retry.conf:/etc/systemd/system/reflector.service.d/10-retry.conf"
  )
fi

# Installed as real root-owned files (not symlinks, not prompted): ours alone,
# no upstream version to diff against, but the reader is sandboxed away from
# /home so a link into the repo silently does nothing.
#   - systemd-logind runs ProtectHome=yes + ProtectSystem=strict, so /home is an
#     empty tmpfs in its namespace and a drop-in symlinked there just dangles.
#     logind skips it without a word -- `systemd-analyze cat-config` still shows
#     it, which is what made this look like a precedence bug in April 2026.
#     Verify with: busctl get-property org.freedesktop.login1 \
#       /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch
#   - udev rules are read by systemd-udevd, which runs PrivateMounts=yes and can
#     be invoked from the initramfs, where /home does not exist at all. A real
#     root-owned file is the only form that is guaranteed readable in both.
SYSTEM_INSTALLS=(
  "systemd/logind.conf.d/10-lid.conf:/etc/systemd/logind.conf.d/10-lid.conf"
  "udev/rules.d/90-no-wake-i2c-hid.rules:/etc/udev/rules.d/90-no-wake-i2c-hid.rules"
  "upower/UPower.conf.d/70-hibernate-earlier.conf:/etc/UPower/UPower.conf.d/70-hibernate-earlier.conf"
  "NetworkManager/conf.d/10-dns-resolved.conf:/etc/NetworkManager/conf.d/10-dns-resolved.conf"
)

# Copied, not symlinked, for two different "the reader can't see /home" reasons:
#   - boot configs (grub/mkinitcpio/modprobe) are read before /home is mounted,
#     so they must survive a broken /home and work from a rescue/chroot env;
#   - reflector.conf is read by reflector.service, which runs ProtectHome=true
#     (+ ProtectSystem=strict) and gets EACCES following a symlink into /home —
#     it must be a real root-owned file at the destination;
#   - PAM stacks gate logging in, so a broken /home must not also break login.
#     They add pam_gnome_keyring to util-linux/shadow's files (Ubuntu's
#     pam-auth-update already does this), which pacman keeps as .pacnew on bumps.
SYSTEM_COPIES=()
if [ "$DISTRO_FAMILY" = arch ]; then
  SYSTEM_COPIES=(
    "grub/grub:/etc/default/grub"
    "mkinitcpio/mkinitcpio.conf:/etc/mkinitcpio.conf"
    "modprobe/nvidia.conf:/etc/modprobe.d/nvidia.conf"
    "reflector/reflector.conf:/etc/xdg/reflector/reflector.conf"
    "pam/login:/etc/pam.d/login"
    "pam/passwd:/etc/pam.d/passwd"
  )
fi

# --- helpers --------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

# Resolve a SYSTEM_LINKS/SYSTEM_INSTALLS/SYSTEM_COPIES src to an absolute path.
src_path() {
  case "$1" in
    /*) echo "$1" ;;
    *)  echo "$DOTFILES/system/$1" ;;
  esac
}

# True if any file of a stow package resolves to its counterpart under $HOME.
pkg_is_stowed() {
  local pkg="$1" file rel target real
  while IFS= read -r -d '' file; do
    rel="${file#"$STOW_DIR/$pkg/"}"
    target="$HOME/$rel"
    real="$(readlink -f "$target" 2>/dev/null || true)"
    [ "$real" = "$file" ] && return 0
  done < <(find "$STOW_DIR/$pkg" -type f -print0)
  return 1
}

# --- apply -----------------------------------------------------------------
# The system half runs as root, so "the user" is whoever owns the checkout,
# never $USER or $HOME.
OWNER="$(stat -c %U "$DOTFILES")"
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
SYSTEM_STATE=/var/lib/dotfiles   # boot backups, rejected hashes, keyd.sum

digest_of() { sha256sum | cut -c1-12; }
