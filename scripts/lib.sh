#!/usr/bin/env bash
# lib.sh: shared configuration for sync.sh and status.sh.
#
# Sourced, never executed. Owns every list that both syncing and reporting
# need, so adding a stow package or a system config is a one-line edit in
# exactly one place. Previously these lists lived twice (once in the sync
# recipe, once in the status recipe) and silently drifted apart.

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
# use site. This file holds *choices* only, persisted by scripts/setup-host.sh.
#
# HOST_DEV_TOOLS  : 1 = build hypr-tools from a local checkout into ~/.local/bin,
#                   shadowing the AUR copies in /usr/bin
# HOST_DEV_TOOLS_SRC : where that checkout lives (default below)
# HOST_RESTIC     : 1 = enable the restic backup timer
# HOST_DROP_PKGS  : stow packages to skip on this host
# HOST_SSHFS_SKIP : sshfs mounts to skip (any of: conway cdn msi)
# HOST_NO_AAAA    : 1 = install the NM dispatcher forcing 'options no-aaaa'
HOST_NAME="$(uname -n)"
HOST_FILE="$DOTFILES/hosts/$HOST_NAME.sh"
# shellcheck source=/dev/null
[ -f "$HOST_FILE" ] && . "$HOST_FILE"

HOST_DEV_TOOLS="${HOST_DEV_TOOLS:-0}"
HOST_DEV_TOOLS_SRC="${HOST_DEV_TOOLS_SRC:-$HOME/projects/hypr-tools}"
HOST_RESTIC="${HOST_RESTIC:-1}"
HOST_DROP_PKGS="${HOST_DROP_PKGS:-}"
HOST_SSHFS_SKIP="${HOST_SSHFS_SKIP:-}"
HOST_NO_AAAA="${HOST_NO_AAAA:-0}"

# --- stow packages --------------------------------------------------------
COMMON_STOW=(fish git tmux nvim claude sshfs bin kitty ssh mime restic zathura
             visidata tridactyl tailscale theme audio)
ARCH_STOW=(hypr swaync rofi waybar)

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

# --- sshfs mounts ---------------------------------------------------------
SSHFS_MOUNTS=()
SSHFS_SKIPPED=()
for _m in conway cdn msi; do
  if [[ " $HOST_SSHFS_SKIP " == *" $_m "* ]]; then
    SSHFS_SKIPPED+=("$_m")
  else
    SSHFS_MOUNTS+=("$_m")
  fi
done
unset _m

# --- system configs -------------------------------------------------------
# Symlinked: read at runtime, so a link into the repo is fine.
# Format "src:dst"; src is relative to system/ unless it starts with '/'.
SYSTEM_LINKS=(
  "keyd/default.conf:/etc/keyd/default.conf"
  "libinput/local-overrides.quirks:/etc/libinput/local-overrides.quirks"
  "sysctl/99-sysrq.conf:/etc/sysctl.d/99-sysrq.conf"
  "systemd/sleep.conf:/etc/systemd/sleep.conf"
  "systemd/system-sleep/fuse-mounts:/usr/lib/systemd/system-sleep/fuse-mounts"
  "systemd/system-sleep/hyprlock-restart:/usr/lib/systemd/system-sleep/hyprlock-restart"
  "/usr/share/alsa/alsa.conf.d/99-pipewire-default.conf:/etc/alsa/conf.d/99-pipewire-default.conf"
)

# Arch-only drop-ins. See each conf for what it changes and why.
if [ "$DISTRO_FAMILY" = arch ]; then
  SYSTEM_LINKS+=(
    "systemd/paccache.service.d/10-uninstalled.conf:/etc/systemd/system/paccache.service.d/10-uninstalled.conf"
    "systemd/linux-modules-cleanup.service.d/10-prune-old.conf:/etc/systemd/system/linux-modules-cleanup.service.d/10-prune-old.conf"
  )
fi

# Installed as real root-owned files (not symlinks, not prompted): ours alone,
# no upstream version to diff against, but the reader is sandboxed away from
# /home so a link into the repo silently does nothing.
#   - systemd-logind runs ProtectHome=yes + ProtectSystem=strict, so /home is an
#     empty tmpfs in its namespace and a drop-in symlinked there just dangles.
#   - udev rules are read by systemd-udevd, which runs PrivateMounts=yes and can
#     be invoked from the initramfs, where /home does not exist at all. A real
#     root-owned file is the only form that is guaranteed readable in both.
#     logind skips it without a word -- `systemd-analyze cat-config` still shows
#     it, which is what made this look like a precedence bug in April 2026.
  "udev/rules.d/90-no-wake-i2c-hid.rules:/etc/udev/rules.d/90-no-wake-i2c-hid.rules"
#     Verify with: busctl get-property org.freedesktop.login1 \
#       /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch
SYSTEM_INSTALLS=(
  "systemd/logind.conf.d/10-lid.conf:/etc/systemd/logind.conf.d/10-lid.conf"
)

# Copied, not symlinked, for two different "the reader can't see /home" reasons:
#   - boot configs (grub/mkinitcpio/modprobe) are read before /home is mounted,
#     so they must survive a broken /home and work from a rescue/chroot env;
#   - reflector.conf is read by reflector.service, which runs ProtectHome=true
#     (+ ProtectSystem=strict) and gets EACCES following a symlink into /home —
#     it must be a real root-owned file at the destination.
SYSTEM_COPIES=()
if [ "$DISTRO_FAMILY" = arch ]; then
  SYSTEM_COPIES=(
    "grub/grub:/etc/default/grub"
    "mkinitcpio/mkinitcpio.conf:/etc/mkinitcpio.conf"
    "modprobe/nvidia.conf:/etc/modprobe.d/nvidia.conf"
    "reflector/reflector.conf:/etc/xdg/reflector/reflector.conf"
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
