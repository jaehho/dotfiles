#!/usr/bin/env bash
# apply.sh: make the live machine match this repo's configs. Run when you want.
#
#   apply.sh            user half: stow + user units that ship with packages
#   apply.sh system     system half: /etc links and copies (root)
#   apply.sh all        system then user as the repo owner (bootstrap)
#
# Nothing here upgrades packages or prompts. `dotfiles status` is the dry run.
# Edits under home/ and system/ are already the source of truth for linked
# files; this step picks up new files, replaces lost links, and installs the
# root-owned copies that cannot be symlinks.

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
. "$(dirname "$SELF")/lib.sh"

say() { echo "==> $*"; }

# --- system ----------------------------------------------------------------

system_configs() {
  local pair src dst
  mkdir -p "$SYSTEM_STATE"
  for pair in "${SYSTEM_LINKS[@]}" "${SYSTEM_INSTALLS[@]}"; do
    mkdir -p "$(dirname "${pair##*:}")"
  done

  for pair in "${SYSTEM_LINKS[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    # An absolute src outside system/ is shipped by another package. Skip
    # until that package lands rather than leave a dangling symlink.
    [ -e "$src" ] || continue
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] || ln -sfn "$src" "$dst"
  done

  # Real files, not links -- the reader is sandboxed out of /home. `install`
  # writes *through* a symlink at the destination, so clear any stale link.
  local -A fresh=()
  for pair in "${SYSTEM_INSTALLS[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    [ -L "$dst" ] && rm -f "$dst"
    cmp -s "$src" "$dst" 2>/dev/null && continue
    install -D -m 0644 -o root -g root "$src" "$dst"
    fresh[${dst%/*}]=1
    echo "  $dst: installed"
  done

  # NetworkManager refuses symlinked or non-root dispatcher scripts.
  local nm="$DOTFILES/system/NetworkManager/dispatcher.d"
  install -D -m 0755 -o root -g root "$nm/50-restart-sshfs" /etc/NetworkManager/dispatcher.d/50-restart-sshfs
  install -D -m 0755 -o root -g root "$nm/60-tzupdate" /etc/NetworkManager/dispatcher.d/60-tzupdate
  if [ "$HOST_NO_AAAA" = 1 ]; then
    install -D -m 0755 -o root -g root "$nm/90-no-aaaa" /etc/NetworkManager/dispatcher.d/90-no-aaaa
  else
    rm -f /etc/NetworkManager/dispatcher.d/90-no-aaaa
  fi

  # systemd-resolved owns DNS: NM hands it each link's servers and Tailscale
  # adds only its split-DNS domains. A plain resolv.conf lets Tailscale
  # rewrite the file into a global override that races Wi-Fi's servers.
  if systemctl cat systemd-resolved.service >/dev/null 2>&1; then
    systemctl enable --now systemd-resolved.service >/dev/null 2>&1
    local stub=/run/systemd/resolve/stub-resolv.conf ts= nm_present=
    systemctl cat NetworkManager.service >/dev/null 2>&1 && nm_present=1
    if [ "$(readlink /etc/resolv.conf 2>/dev/null)" != "$stub" ] ||
       { [ -n "$nm_present" ] && [ -n "${fresh[/etc/NetworkManager/conf.d]:-}" ]; }; then
      # Both pick their DNS mode at startup and rewrite a plain file while
      # running, and tailscaled restores its own copy when it stops. Stop
      # tailscaled, link, restart NM, start tailscaled. Restore tailscaled
      # before anything that can fail (`try-restart` on a missing unit is not
      # a no-op; under set -e that used to skip the start line and cut a
      # tailnet SSH session).
      local nm_rc=0
      systemctl is-active --quiet tailscaled.service && ts=1
      [ -z "$ts" ] || systemctl stop tailscaled.service
      ln -sfn "$stub" /etc/resolv.conf
      rm -f /etc/resolv.pre-tailscale-backup.conf
      [ -z "$nm_present" ] || systemctl try-restart NetworkManager.service || nm_rc=$?
      [ -z "$ts" ] || systemctl start tailscaled.service
      [ "$nm_rc" = 0 ] || return "$nm_rc"
      echo "  /etc/resolv.conf -> resolved stub"
    fi
  fi

  if have keyd; then
    systemctl enable --now keyd >/dev/null 2>&1 || true
    local keyd_sum; keyd_sum=$(digest_of < "$DOTFILES/system/keyd/default.conf")
    if [ "$keyd_sum" = "$(cat "$SYSTEM_STATE/keyd.sum" 2>/dev/null)" ]; then
      :
    elif keyd check >/dev/null 2>&1; then
      keyd reload >/dev/null 2>&1 || true
      echo "$keyd_sum" > "$SYSTEM_STATE/keyd.sum"
    else
      echo "  keyd rejects system/keyd/default.conf; the old mapping is still running" >&2
      keyd check 2>&1 | tail -20 | sed 's/^/    /' >&2 || true
    fi
  fi

  # logind reads drop-ins at start; restart would kill the session, reload
  # is enough (issue #30). UPower only at start.
  [ -z "${fresh[/etc/systemd/logind.conf.d]:-}" ] || systemctl reload systemd-logind.service
  if [ -n "${fresh[/etc/UPower/UPower.conf.d]:-}" ] && systemctl cat upower.service >/dev/null 2>&1; then
    systemctl try-restart upower.service
  fi

  # Distro hygiene that ships disabled. Only if the unit is present.
  if [ "$DISTRO_FAMILY" = arch ]; then
    systemctl cat paccache.timer >/dev/null 2>&1 &&
      systemctl enable --now paccache.timer >/dev/null 2>&1
    systemctl cat linux-modules-cleanup.service >/dev/null 2>&1 &&
      systemctl enable linux-modules-cleanup.service >/dev/null 2>&1
    if systemctl cat reflector.timer >/dev/null 2>&1; then
      systemctl enable --now reflector.timer >/dev/null 2>&1
      if ! grep -qi 'generated by reflector' /etc/pacman.d/mirrorlist 2>/dev/null; then
        systemctl start reflector.service || echo "  reflector: first ranking failed, mirrorlist untouched"
      fi
      rm -f /etc/pacman.d/mirrorlist.pacnew
    fi
  fi
}

# Repo wins for SYSTEM_COPIES; replaced files land under $SYSTEM_STATE/backup.
# A grub/mkinitcpio change is rebuilt right away; on failure the previous file
# returns and the repo version is remembered as rejected until it changes.
system_boot() {
  local pair src dst hash stamp regen_initramfs= regen_grub=
  local -A replaced=() hashes=()
  stamp=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$SYSTEM_STATE/rejected"
  for pair in "${SYSTEM_COPIES[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    [ -L "$dst" ] && rm -f "$dst"
    cmp -s "$src" "$dst" 2>/dev/null && continue
    hash=$(digest_of < "$src")
    if [ -e "$SYSTEM_STATE/rejected/$hash" ]; then
      echo "  $dst: skipped (this repo version failed to build before; see $SYSTEM_STATE/rejected/$hash)" >&2
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ]; then
      replaced[$dst]="$SYSTEM_STATE/backup$dst.$stamp"
      install -D -m 0644 "$dst" "${replaced[$dst]}"
      echo "  $dst: replaced (previous at ${replaced[$dst]})"
      diff -u "${replaced[$dst]}" "$src" | sed 's/^/    /' || true
    else
      echo "  $dst: installed"
    fi
    install -m 0644 -o root -g root "$src" "$dst"
    hashes[$dst]=$hash
    case "$dst" in
      /etc/mkinitcpio.conf|/etc/modprobe.d/*) regen_initramfs=1 ;;
      /etc/default/grub)                      regen_grub=1 ;;
    esac
  done

  reject() {
    local f
    for f in "$@"; do
      [ -n "${hashes[$f]:-}" ] || continue
      if [ -n "${replaced[$f]:-}" ]; then install -m 0644 "${replaced[$f]}" "$f"; else rm -f "$f"; fi
      echo "$f failed to build on $stamp" > "$SYSTEM_STATE/rejected/${hashes[$f]}"
      echo "  $f: restored"
    done
  }

  if [ -n "$regen_initramfs" ] && have mkinitcpio; then
    say "mkinitcpio -P"
    if ! mkinitcpio -P; then
      reject /etc/mkinitcpio.conf /etc/modprobe.d/*
      mkinitcpio -P
      echo "  initramfs: repo config failed to build; previous is back" >&2
      return 1
    fi
  fi

  if [ -n "$regen_grub" ] && have grub-mkconfig; then
    say "grub-mkconfig"
    local cfg=/boot/grub/grub.cfg
    if grub-mkconfig -o "$cfg.new" && grub-script-check "$cfg.new"; then
      install -D -m 0644 "$cfg" "$SYSTEM_STATE/backup$cfg.$stamp"
      mv "$cfg.new" "$cfg"
    else
      rm -f "$cfg.new"
      reject /etc/default/grub
      echo "  grub: repo config made an unparseable grub.cfg; previous is back" >&2
      return 1
    fi
  fi
}

system_shell() {
  local fish_path; fish_path="$(command -v fish || true)"
  [ -n "$fish_path" ] || { echo "  fish not installed"; return 0; }
  [ "$(getent passwd "$OWNER" | cut -d: -f7)" = "$fish_path" ] && return 0
  grep -qxF "$fish_path" /etc/shells || echo "$fish_path" >> /etc/shells
  usermod -s "$fish_path" "$OWNER"
  echo "  $OWNER's shell is now fish (next login)"
}

run_system() {
  [ "$(id -u)" = 0 ] || { echo "apply.sh system needs root: sudo $0 system" >&2; exit 1; }
  say "system configs"
  system_configs
  say "system boot copies"
  system_boot
  system_shell
}

# --- user ------------------------------------------------------------------

# Pre-stow cleanup:
#   1. Absolute symlinks into the repo: stow doesn't own these; remove so it
#      recreates relative ones.
#   2. Regular files through a symlinked parent already resolve into the repo.
#   3. Regular files outside the repo: back up so stow can take over.
run_user() {
  local pkg file rel target real link
  say "stow"
  for pkg in "${STOW_PACKAGES[@]}"; do
    while IFS= read -r -d '' file; do
      rel="${file#"$STOW_DIR/$pkg/"}"
      target="$HOME/$rel"
      stow_skipped "$pkg/$rel" && continue
      if [ -L "$target" ]; then
        case "$(readlink "$target")" in
          "$DOTFILES"/*) rm -f "$target" ;;
        esac
        continue
      fi
      if [ -e "$target" ]; then
        real="$(readlink -f "$target" 2>/dev/null || true)"
        case "$real" in
          "$DOTFILES"/*) : ;;
          *) mv "$target" "$target.bak"
             echo "  backed up $target -> $target.bak" ;;
        esac
      fi
    done < <(find "$STOW_DIR/$pkg" -type f -print0)
    stow -d "$STOW_DIR" -t "$HOME" --no-folding "$pkg"
  done

  # mimeapps.list is owned here, not by stow. GLib's safe-write resolves the
  # target from CWD, so the link must be absolute.
  if have update-mime-database && [ -d "$HOME/.local/share/mime/packages" ]; then
    update-mime-database "$HOME/.local/share/mime"
  fi
  target="$STOW_DIR/mime/.config/mimeapps.list"
  link="$HOME/.config/mimeapps.list"
  mkdir -p "$(dirname "$link")"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    mv "$link" "$link.bak"
    echo "  mimeapps.list: backed up regular file to $link.bak"
  fi
  [ "$(readlink "$link" 2>/dev/null)" = "$target" ] || ln -sfn "$target" "$link"

  [ -d "$HOME/.tmux/plugins/tpm" ] ||
    git clone -q https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" ||
    echo "  tpm: clone failed (offline?); run apply again"
  # catppuccin/tmux is a manual clone (TPM name conflicts); pin the release tag.
  [ -d "$HOME/.config/tmux/plugins/catppuccin/tmux" ] ||
    git clone -q -b v2.3.1 --depth 1 https://github.com/catppuccin/tmux.git \
      "$HOME/.config/tmux/plugins/catppuccin/tmux" ||
    echo "  catppuccin/tmux: clone failed (offline?); run apply again"

  # bat needs its theme cache rebuilt after theme/ is stowed.
  have bat && bat cache --build >/dev/null 2>&1 || true

  # User units that ship with packages stowed above.
  if systemctl --user daemon-reload 2>/dev/null; then
    local unit
    for unit in wallhelper-fetch.timer \
                notification-log.service battery-logd.service \
                swayosd-server.service kokoro-tts.socket awatcher.service \
                aw-watcher-claude.service aw-watcher-terminal.service; do
      systemctl --user cat "$unit" >/dev/null 2>&1 || continue
      systemctl --user is-enabled "$unit" >/dev/null 2>&1 && continue
      systemctl --user enable --now "$unit" >/dev/null 2>&1 && echo "  $unit: enabled"
    done
  else
    echo "  user systemd unavailable; units enabled on the next logged-in run"
  fi

  # waypaper rewrites its whole config on exit. Keep post_command in place.
  local wp_cfg="$HOME/.config/waypaper/config.ini"
  local wp_cmd='wallhelper set "$wallpaper"'
  if [ -f "$wp_cfg" ] && ! grep -qxF "post_command = $wp_cmd" "$wp_cfg"; then
    sed -i "s|^post_command = .*|post_command = $wp_cmd|" "$wp_cfg"
  fi
}

as_owner() {
  if [ "$(id -u)" = 0 ]; then
    runuser -u "$OWNER" -- env HOME="$OWNER_HOME" USER="$OWNER" \
      XDG_RUNTIME_DIR="/run/user/$(id -u "$OWNER")" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$OWNER")/bus" "$@"
  else
    "$@"
  fi
}

# --- main ------------------------------------------------------------------

case "${1:-user}" in
  user)   run_user ;;
  system) run_system ;;
  all)    run_system; as_owner bash "$SELF" user ;;
  *) echo "usage: apply.sh [user|system|all]" >&2; exit 2 ;;
esac
