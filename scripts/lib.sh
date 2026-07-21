#!/usr/bin/env bash
# lib.sh: shared configuration for sync.sh and status.sh.
#
# Sourced, never executed. Owns every list that both syncing and reporting
# need, so adding a stow package or a system config is a one-line edit in
# exactly one place. Previously these lists lived twice (once in the sync
# recipe, once in the status recipe) and silently drifted apart.

DOTFILES="${DOTFILES:-$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)}"
PKGDIR="$DOTFILES/packages"

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
# HOST_DEV_TOOLS  : 1 = build hypr-tools from the submodule into ~/.local/bin,
#                   shadowing the AUR copies in /usr/bin
# HOST_RESTIC     : 1 = enable the restic backup timer
# HOST_DROP_PKGS  : stow packages to skip on this host
# HOST_SSHFS_SKIP : sshfs mounts to skip (any of: ice cdn msi)
# HOST_NO_AAAA    : 1 = install the NM dispatcher forcing 'options no-aaaa'
HOST_NAME="$(uname -n)"
HOST_FILE="$DOTFILES/hosts/$HOST_NAME.sh"
# shellcheck source=/dev/null
[ -f "$HOST_FILE" ] && . "$HOST_FILE"

HOST_DEV_TOOLS="${HOST_DEV_TOOLS:-0}"
HOST_RESTIC="${HOST_RESTIC:-1}"
HOST_DROP_PKGS="${HOST_DROP_PKGS:-}"
HOST_SSHFS_SKIP="${HOST_SSHFS_SKIP:-}"
HOST_NO_AAAA="${HOST_NO_AAAA:-0}"

# --- stow packages --------------------------------------------------------
COMMON_STOW=(fish git tmux nvim claude sshfs bin kitty ssh mime restic zathura
             visidata tridactyl tailscale)
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
  "hypr/.config/hypr/monitors.conf"  # rewritten by hypr-monitor on every hotplug
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
for _m in ice cdn msi; do
  if [[ " $HOST_SSHFS_SKIP " == *" $_m "* ]]; then
    SSHFS_SKIPPED+=("$_m")
  else
    SSHFS_MOUNTS+=("$_m")
  fi
done
unset _m

# --- system configs -------------------------------------------------------
# Symlinked: read at runtime, so a link into the repo is fine.
# Format "src:dst"; src is repo-relative unless it starts with '/'.
SYSTEM_LINKS=(
  "keyd/default.conf:/etc/keyd/default.conf"
  "libinput/local-overrides.quirks:/etc/libinput/local-overrides.quirks"
  "sysctl/99-sysrq.conf:/etc/sysctl.d/99-sysrq.conf"
  "systemd/sleep.conf:/etc/systemd/sleep.conf"
  "systemd/logind.conf.d/10-lid.conf:/etc/systemd/logind.conf.d/10-lid.conf"
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

# Copied, not symlinked: these are read before /home is mounted, so they must
# survive a broken /home and work from a rescue/chroot environment.
SYSTEM_COPIES=()
if [ "$DISTRO_FAMILY" = arch ]; then
  SYSTEM_COPIES=(
    "grub/grub:/etc/default/grub"
    "mkinitcpio/mkinitcpio.conf:/etc/mkinitcpio.conf"
    "modprobe/nvidia.conf:/etc/modprobe.d/nvidia.conf"
  )
fi

# --- helpers --------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

# Resolve a SYSTEM_LINKS/SYSTEM_COPIES src to an absolute path.
src_path() {
  case "$1" in
    /*) echo "$1" ;;
    *)  echo "$DOTFILES/$1" ;;
  esac
}

# True if any file of a stow package resolves to its counterpart under $HOME.
pkg_is_stowed() {
  local pkg="$1" file rel target real
  while IFS= read -r -d '' file; do
    rel="${file#"$DOTFILES/$pkg/"}"
    target="$HOME/$rel"
    real="$(readlink -f "$target" 2>/dev/null || true)"
    [ "$real" = "$file" ] && return 0
  done < <(find "$DOTFILES/$pkg" -type f -print0)
  return 1
}
