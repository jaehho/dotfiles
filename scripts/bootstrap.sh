#!/usr/bin/env bash
# bootstrap.sh: the one interactive step, once per machine.
#
#   sudo ~/dotfiles/scripts/bootstrap.sh
#
# Installs what converge itself needs, asks the per-host questions and the
# restic password, installs the converge units, then starts the first run.
# From then on the machine converges on its own (converge.sh); re-running this
# is safe and only asks what is still unanswered.

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

# --- what converge needs ----------------------------------------------------

case "$DISTRO_FAMILY" in
  arch)
    pacman -S --needed --noconfirm git stow jq curl python base-devel file
    if ! have paru; then
      echo "==> building paru"
      tmp=$(as_owner mktemp -d)
      as_owner git clone -q https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
      (cd "$tmp/paru-bin" && as_owner makepkg --noconfirm)
      pacman -U --noconfirm "$tmp"/paru-bin/paru-bin-*.pkg.tar.zst
      rm -rf "$tmp"
    fi
    ;;
  debian)
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y git stow jq curl python3 file unattended-upgrades
    ;;
  *) echo "unsupported distro" >&2; exit 1 ;;
esac

# --- per-host answers ---------------------------------------------------------

case "$HOST_NAME" in
  archlinux|ubuntu|debian|localhost|localhost.localdomain|"")
    echo "WARNING: hostname '$HOST_NAME' looks like an installer default." >&2
    echo "  Set one first: hostnamectl set-hostname <name>, then re-run." >&2
    exit 1 ;;
esac

if [ ! -f "$HOST_FILE" ]; then
  echo
  echo "==> First run on $HOST_NAME. Answers go to hosts/$HOST_NAME.sh (commit it)."
  read -r -p "    Enable restic backups to the homelab rest-server? [Y/n] " ans
  case "$ans" in n|N|no|NO) restic=0 ;; *) restic=1 ;; esac
  read -r -p "    sshfs mounts to skip (any of: conway; blank for none): " sshfs_skip
  read -r -p "    Stow packages to skip (space-separated, blank for none): " drop
  read -r -p "    Force 'options no-aaaa' in resolv.conf (no IPv6 here)? [y/N] " ans
  case "$ans" in y|Y|yes|YES) no_aaaa=1 ;; *) no_aaaa=0 ;; esac
  as_owner tee "$HOST_FILE" >/dev/null <<EOF
# Per-host config for $HOST_NAME, written by scripts/bootstrap.sh. Safe to
# hand-edit. Sourced by scripts/lib.sh -- plain shell assignments only.
HOST_RESTIC=$restic
HOST_SSHFS_SKIP="$sshfs_skip"
HOST_DROP_PKGS="$drop"
HOST_NO_AAAA=$no_aaaa
EOF
  . "$HOST_FILE"
fi

pw="$OWNER_HOME/.config/restic/password"
if [ "${HOST_RESTIC:-1}" = 1 ] && [ ! -f "$pw" ]; then
  read -rsp "    restic repository password: " p1; echo
  read -rsp "    again: " p2; echo
  if [ "$p1" = "$p2" ] && [ -n "$p1" ]; then
    as_owner mkdir -p "$(dirname "$pw")"
    as_owner install -m 600 /dev/null "$pw"
    printf '%s' "$p1" | as_owner tee "$pw" >/dev/null
  else
    echo "    passwords differ; skipped (converge will ask again as a decision)"
  fi
fi

# One rest-server user per person (`docker exec -it rest-server create_user`
# on the homelab); the repo is the path named after that user.
rest="$OWNER_HOME/.config/restic/rest.env"
if [ "${HOST_RESTIC:-1}" = 1 ] && [ ! -f "$rest" ]; then
  read -r -p "    rest-server user [$OWNER]: " ru; ru=${ru:-$OWNER}
  read -rsp "    rest-server password: " rp; echo
  if [ -n "$rp" ]; then
    as_owner mkdir -p "$(dirname "$rest")"
    as_owner install -m 600 /dev/null "$rest"
    printf 'RESTIC_REPOSITORY=rest:https://restic.wonhomelab.net/%s/\nRESTIC_REST_USERNAME=%s\nRESTIC_REST_PASSWORD=%s\n' \
      "$ru" "$ru" "$rp" | as_owner tee "$rest" >/dev/null
  fi
fi

# --- install and start ------------------------------------------------------

echo "==> installing the converge units"
bash "$DOTFILES/scripts/converge.sh" system configs

# The user half needs what the system half installs (npm, rustup, fish), so
# it starts only once the first system run is done.
echo "==> first system run"
journalctl -f -n0 -o cat -u dotfiles-converge.service &
journal=$!
systemctl start dotfiles-converge.service || true
# A libc upgrade re-executes systemd and drops the wait above; poll instead.
while [ "$(systemctl show -p ActiveState --value dotfiles-converge.service)" = activating ]; do sleep 2; done
kill "$journal" 2>/dev/null || true

if [ -S "/run/user/$(id -u "$OWNER")/bus" ]; then
  as_owner bash "$DOTFILES/scripts/converge.sh" user stow
  as_owner systemctl --user start --no-block dotfiles-converge.service
  echo "==> user half running. Follow it with: journalctl --user -fu dotfiles-converge"
else
  echo "==> the user half runs 3 minutes after $OWNER logs in"
fi
