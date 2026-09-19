#!/usr/bin/env bash
# converge.sh: make this machine match the repo, with nobody watching.
#
#   converge.sh system          as root: packages, /etc, boot configs, shell
#   converge.sh user            as the owner: stow, user units, tools, mounts, Claude
#   converge.sh now             start both units and follow them (`dotfiles sync`)
#   converge.sh system boot     one step in the foreground, for debugging
#   converge.sh --list          step names
#
# Both halves run from systemd timers, at boot and daily. Nothing here reads
# stdin: anything that used to stop and ask is a decision (see `decide` in
# lib.sh), recorded in <state>/decisions.json with every step's status, and
# `dotfiles notify` turns new ones into a notification. A failed step is itself
# a decision; the steps after it still run.

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
. "$(dirname "$SELF")/lib.sh"

SYSTEM_STEPS=(pkgs configs boot shell pacnew reboot)
USER_STEPS=(host stow tools sshfs restic claude)

say() { echo "==> $*"; }

# --- system: pkgs ---------------------------------------------------------

step_pkgs() {
  bash "$DOTFILES/scripts/packages.sh" system
}

# --- system: configs ------------------------------------------------------

step_configs() {
  local pair src dst
  mkdir -p "$SYSTEM_STATE"
  for pair in "${SYSTEM_LINKS[@]}" "${SYSTEM_INSTALLS[@]}"; do
    mkdir -p "$(dirname "${pair##*:}")"
  done

  for pair in "${SYSTEM_LINKS[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] || ln -sfn "$src" "$dst"
  done

  # Real files, not links -- the reader is sandboxed out of /home. `install`
  # writes *through* a symlink at the destination, so clear any stale link an
  # older sync left behind or we would just rewrite the repo file in place.
  local -A fresh=()
  for pair in "${SYSTEM_INSTALLS[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    [ -L "$dst" ] && rm -f "$dst"
    cmp -s "$src" "$dst" 2>/dev/null && continue
    install -D -m 0644 -o root -g root "$src" "$dst"
    fresh[${dst%/*}]=1
    echo "  $dst: installed"
  done

  # converge's own root units carry the checkout's path, so they are rendered
  # rather than copied.
  local unit changed=
  for unit in dotfiles-converge.service dotfiles-converge.timer; do
    sed "s|@DOTFILES@|$DOTFILES|g" "$DOTFILES/system/converge/$unit" > "/etc/systemd/system/$unit.new"
    if cmp -s "/etc/systemd/system/$unit.new" "/etc/systemd/system/$unit"; then
      rm -f "/etc/systemd/system/$unit.new"
    else
      mv "/etc/systemd/system/$unit.new" "/etc/systemd/system/$unit"; changed=1
    fi
  done
  systemctl daemon-reload
  systemctl enable dotfiles-converge.timer >/dev/null 2>&1
  [ -n "$changed" ] && echo "  converge units updated"

  # systemd-sleep(8) v260+ only scans /usr/lib/systemd/system-sleep/, so drop
  # the copies an older sync left in /etc. hyprlock-restart is gone from both:
  # it killed a healthy hyprlock and cycled the session lock on every resume.
  # The rest went in the 2026-09-12 sleep reset back to stock (ISSUES.md).
  rm -f /etc/systemd/system-sleep/fuse-mounts \
        /etc/systemd/system-sleep/hyprlock-restart \
        /usr/lib/systemd/system-sleep/hyprlock-restart \
        /etc/systemd/logind.conf.d/10-lid-hibernate.conf \
        /usr/lib/systemd/system-sleep/audio-health \
        /etc/tmpfiles.d/hibernate.conf \
        /etc/tmpfiles.d/pm-debug.conf
  sysctl --system >/dev/null
  # The rest act only on a change: this runs daily, and rebinding the touchpad
  # or reloading logind under a live session is not free.
  # Rules only fire on the next uevent, so replay bind for the devices they
  # match -- otherwise the no-wake rule does nothing until the next reboot.
  if [ -n "${fresh[/etc/udev/rules.d]:-}" ] && have udevadm; then
    udevadm control --reload
    udevadm trigger --action=bind --subsystem-match=i2c
  fi
  # Reload is enough for the lid drop-in, and is safe. Never *restart* logind
  # here: that kills the Hyprland session. See ISSUES.md "logind ignores its
  # drop-in".
  [ -z "${fresh[/etc/systemd/logind.conf.d]:-}" ] || systemctl reload systemd-logind.service
  # UPower reads its drop-ins only at startup; restarting it is harmless.
  if [ -n "${fresh[/etc/UPower/UPower.conf.d]:-}" ] && systemctl cat upower.service >/dev/null 2>&1; then
    systemctl try-restart upower.service
  fi

  # NetworkManager refuses symlinked or non-root dispatcher scripts.
  local nm="$DOTFILES/system/NetworkManager/dispatcher.d"
  install -D -m 0755 -o root -g root "$nm/50-restart-sshfs" /etc/NetworkManager/dispatcher.d/50-restart-sshfs
  install -D -m 0755 -o root -g root "$nm/60-tzupdate" /etc/NetworkManager/dispatcher.d/60-tzupdate
  if [ "$HOST_NO_AAAA" = 1 ]; then
    install -D -m 0755 -o root -g root "$nm/90-no-aaaa" /etc/NetworkManager/dispatcher.d/90-no-aaaa
  else
    rm -f /etc/NetworkManager/dispatcher.d/90-no-aaaa
  fi

  # systemd-resolved owns DNS, the distro-standard layout: NetworkManager hands
  # it each link's servers and Tailscale adds only its split-DNS domains on
  # tailscale0. With a plain resolv.conf, Tailscale rewrites the file into a
  # global override that resolved then races against the Wi-Fi's own servers.
  if systemctl cat systemd-resolved.service >/dev/null 2>&1; then
    systemctl enable --now systemd-resolved.service >/dev/null 2>&1
    local stub=/run/systemd/resolve/stub-resolv.conf ts=
    if [ "$(readlink /etc/resolv.conf 2>/dev/null)" != "$stub" ] ||
       [ -n "${fresh[/etc/NetworkManager/conf.d]:-}" ]; then
      # Both pick their DNS mode at startup and rewrite a plain file while
      # running, and tailscaled restores its own copy when it stops. So: stop
      # tailscaled, link, restart NetworkManager, start tailscaled.
      systemctl is-active --quiet tailscaled.service && ts=1
      [ -z "$ts" ] || systemctl stop tailscaled.service
      ln -sfn "$stub" /etc/resolv.conf
      rm -f /etc/resolv.pre-tailscale-backup.conf
      systemctl try-restart NetworkManager.service
      [ -z "$ts" ] || systemctl start tailscaled.service
      echo "  /etc/resolv.conf -> resolved stub"
    fi
  fi

  if have keyd; then
    # `enable --now` does nothing when keyd already runs, so an edit to the
    # (symlinked) config needs an explicit reload. Check first: a config keyd
    # rejects would leave the keyboard with no remaps at all.
    systemctl enable --now keyd >/dev/null 2>&1 || true
    local keyd_sum; keyd_sum=$(digest_of < "$DOTFILES/system/keyd/default.conf")
    if [ "$keyd_sum" = "$(cat "$SYSTEM_STATE/keyd.sum" 2>/dev/null)" ]; then
      :
    elif keyd check >/dev/null 2>&1; then
      keyd reload >/dev/null 2>&1 || true
      echo "$keyd_sum" > "$SYSTEM_STATE/keyd.sum"
    else
      decide keyd-rejected "keyd rejects system/keyd/default.conf; the old mapping is still running" \
        "$(keyd check 2>&1 | tail -20)"
    fi
  fi

  if [ "$DISTRO_FAMILY" = arch ]; then
    # pacman-contrib ships paccache.timer disabled. Weekly, keeps the 3 newest
    # versions; the drop-in adds a pass for removed packages.
    systemctl cat paccache.timer >/dev/null 2>&1 &&
      systemctl enable --now paccache.timer >/dev/null 2>&1
    # kernel-modules-hook ships this disabled, so module trees for uninstalled
    # kernels pile up, and DKMS rebuilds nvidia against every dead kernel.
    systemctl cat linux-modules-cleanup.service >/dev/null 2>&1 &&
      systemctl enable linux-modules-cleanup.service >/dev/null 2>&1
    # reflector keeps the mirrorlist ranked; its config is copied by the boot
    # step (reflector.service runs ProtectHome=true). First run generates one
    # now rather than waiting a week; its header is the idempotency check.
    if systemctl cat reflector.timer >/dev/null 2>&1; then
      systemctl enable --now reflector.timer >/dev/null 2>&1
      if ! grep -qi 'generated by reflector' /etc/pacman.d/mirrorlist 2>/dev/null; then
        systemctl start reflector.service || echo "  reflector: first ranking failed, mirrorlist untouched"
      fi
      # Once reflector owns the file, the packaged mirrorlist is obsolete.
      rm -f /etc/pacman.d/mirrorlist.pacnew
    fi
  fi
  return 0
}

# --- system: boot ---------------------------------------------------------

# The copied configs (see SYSTEM_COPIES): boot-critical, PAM, reflector. The
# repo wins; whatever it replaces is kept under $SYSTEM_STATE/backup. A change
# that feeds the initramfs or grub.cfg is regenerated right away. If that fails,
# the old file goes back and is regenerated again, and the repo version is
# remembered as rejected (by content hash) so it is not retried every day; it
# is applied again once the repo file changes. A bad edit costs a decision
# rather than a boot.
step_boot() {
  local pair src dst hash stamp regen_initramfs= regen_grub=
  local -A replaced=() hashes=()
  stamp=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$SYSTEM_STATE/rejected"
  for pair in "${SYSTEM_COPIES[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    # A link an older sync left would compare equal to the repo file forever.
    [ -L "$dst" ] && rm -f "$dst"
    cmp -s "$src" "$dst" 2>/dev/null && continue
    hash=$(digest_of < "$src")
    if [ -e "$SYSTEM_STATE/rejected/$hash" ]; then
      decide "rejected-$hash" "The repo's version of $dst failed to build before and stays unapplied" \
        "It is retried when system/${pair%%:*} changes. Log of the failure: $SYSTEM_STATE/rejected/$hash"
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

  # reject FILE...: put back what these replaced and remember the repo versions.
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
      if mkinitcpio -P; then
        decide "initramfs-failed-$stamp" \
          "The repo's initramfs config failed to build; the previous one is back and builds" \
          "Fix it in system/mkinitcpio or system/modprobe. Log: $SYSTEM_STATE/logs/boot.log"
      else
        decide "initramfs-broken" \
          "mkinitcpio fails even with the previous config restored. Do not reboot until it builds" \
          "Log: $SYSTEM_STATE/logs/boot.log. The fallback image may be stale too."
        return 1
      fi
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
      decide "grub-failed-$stamp" \
        "The repo's /etc/default/grub made a grub.cfg that does not parse; the old config is back and grub.cfg is untouched" \
        "Fix it in system/grub/grub. Log: $SYSTEM_STATE/logs/boot.log"
    fi
  fi
  return 0
}

# --- system: shell --------------------------------------------------------

step_shell() {
  local fish_path; fish_path="$(command -v fish || true)"
  [ -n "$fish_path" ] || { echo "  fish not installed"; return 0; }
  [ "$(getent passwd "$OWNER" | cut -d: -f7)" = "$fish_path" ] && return 0
  grep -qxF "$fish_path" /etc/shells || echo "$fish_path" >> /etc/shells
  usermod -s "$fish_path" "$OWNER"
  echo "  $OWNER's shell is now fish (next login)"
}

# --- system: pacnew -------------------------------------------------------

step_pacnew() {
  local found
  found=$(find /etc -xdev \( -name '*.pacnew' -o -name '*.dpkg-dist' \) 2>/dev/null | sort || true)
  [ -n "$found" ] || return 0
  echo "$found" | sed 's/^/  /'
  decide "pacnew-$(digest_of <<<"$found")" \
    "$(grep -c . <<<"$found") package-shipped config(s) waiting to be merged by hand" "$found"
}

# --- system: reboot -------------------------------------------------------

step_reboot() {
  local running img v found=
  running=$(uname -r)
  if [ -f /var/run/reboot-required ]; then
    decide "reboot-$running" "Reboot to finish an upgrade ($(cat /var/run/reboot-required.pkgs 2>/dev/null | xargs))"
    return 0
  fi
  # Ubuntu says so through reboot-required, above; its images are versioned.
  [ "$DISTRO_FAMILY" = arch ] && have file || return 0
  for img in /boot/vmlinuz-*; do
    [ -f "$img" ] || continue
    v=$(file -bL "$img" | sed -n 's/.*version \([^ ]*\).*/\1/p')
    [ "$v" = "$running" ] && found=1
  done
  if [ -z "$found" ]; then
    v=$(file -bL /boot/vmlinuz-linux 2>/dev/null | sed -n 's/.*version \([^ ]*\).*/\1/p')
    decide "reboot-${v:-kernel}" "Reboot into the upgraded kernel ${v:-} (running $running)" \
      "Until then, modules for the running kernel only load from kernel-modules-hook's copy; USB hotplug is the usual casualty (ISSUES.md)."
  fi
}

# --- user: host -----------------------------------------------------------

step_host() {
  [ -f "$HOST_FILE" ] && return 0
  decide "no-host-file-$HOST_NAME" "hosts/$HOST_NAME.sh does not exist; running on defaults" \
    "Run: sudo $DOTFILES/scripts/bootstrap.sh  (asks the per-host questions)"
}

# --- user: stow -----------------------------------------------------------

# Pre-stow cleanup handles three cases that would otherwise damage files or
# block stow:
#   1. Absolute symlinks into the repo: stow doesn't recognize these as "owned"
#      and refuses to re-stow. Remove so stow recreates them as relative.
#   2. Regular files reachable through a symlinked parent dir (realpath lands
#      inside the repo): a naive `mv` would follow the parent symlink and trash
#      the dotfiles copy. Skip — they're already linked in effect.
#   3. Regular files outside the repo: back up so stow can take over.
step_stow() {
  local pkg file rel target real link
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

  # mimeapps.list is owned here, not by stow (mime/.stow-local-ignore excludes
  # it). GLib's safe-write writes its tempfile next to the *resolved* target; a
  # relative symlink would resolve from CWD instead of the link's directory, so
  # Thunar et al. fail to update it unless CWD happens to be ~/.config.
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
    echo "  tpm: clone failed (offline?), next run retries"

  # Small user units whose files are stowed above. Enabled here rather than in
  # their own step: one unit apiece does not earn one.
  #   dotfiles-converge  this script's user half, at login and daily
  #   dotfiles-digest    runs `dotfiles notify` when either half records a new decision
  #   wallhelper-fetch   the day's photo (arch only -- ships with the hypr package)
  #   tip-daily          the day's nvim/tridactyl keybinding, via `tip`
  #   mail-digest        morning/evening inbox summary (linked by ~/projects/mail-digest)
  #   notification-log   the searchable notification history
  #   battery-logd       the battery sampler (packaged with the app, enabled here)
  #   swayosd-server     the volume/brightness OSD (WantedBy pipewire-pulse, so
  #                      enabling is what wires the restart-with-pulse behaviour)
  #   kokoro-tts         the socket for the speech-dispatcher Kokoro voice
  systemctl --user daemon-reload
  local unit
  for unit in dotfiles-converge.timer dotfiles-digest.path \
              wallhelper-fetch.timer tip-daily.timer mail-digest.timer \
              idle-dash-collect.timer idle-dash-llm.timer \
              notification-log.service battery-logd.service \
              swayosd-server.service kokoro-tts.socket; do
    systemctl --user cat "$unit" >/dev/null 2>&1 || continue
    systemctl --user is-enabled "$unit" >/dev/null 2>&1 && continue
    systemctl --user enable --now "$unit" >/dev/null 2>&1 && echo "  $unit: enabled"
  done

  # waypaper rewrites its whole config on exit, so it can't be stowed. Its
  # post_command is the one setting that matters: without it a wallpaper
  # picked in waypaper is lost at the next login. Set it in place, once
  # waypaper has created the file.
  local wp_cfg="$HOME/.config/waypaper/config.ini"
  local wp_cmd='wallhelper set "$wallpaper"'
  if [ -f "$wp_cfg" ] && ! grep -qxF "post_command = $wp_cmd" "$wp_cfg"; then
    sed -i "s|^post_command = .*|post_command = $wp_cmd|" "$wp_cfg"
  fi
  return 0
}

# --- user: tools ----------------------------------------------------------

step_tools() {
  bash "$DOTFILES/scripts/packages.sh" user
}

# --- user: sshfs ----------------------------------------------------------

step_sshfs() {
  local m
  for m in ${SSHFS_SKIPPED[@]+"${SSHFS_SKIPPED[@]}"}; do
    systemctl --user disable --now "sshfs-$m" "sshfs-$m-watchdog.timer" >/dev/null 2>&1 || true
    fusermount3 -uz "$HOME/mnt/$m" 2>/dev/null || true
  done
  [ ${#SSHFS_MOUNTS[@]} -gt 0 ] || return 0

  for m in "${SSHFS_MOUNTS[@]}"; do
    # A dead sshfs mount reports "Transport endpoint is not connected", and in
    # that state even `mkdir -p` fails. Detach it lazily and retry; reboots and
    # dropped links leave exactly this behind.
    if ! mkdir -p "$HOME/mnt/$m" 2>/dev/null; then
      fusermount3 -uz "$HOME/mnt/$m" 2>/dev/null || true
      mkdir -p "$HOME/mnt/$m"
    fi
  done

  for m in "${SSHFS_MOUNTS[@]}"; do
    case "$m" in
      # Always-on jump-host mount. Best-effort: conway is often off-network.
      # The watchdog remounts once it is reachable.
      conway)
        if [ ! -f "$HOME/.ssh/jump_pass" ]; then
          decide no-jump-pass "~/.ssh/jump_pass is missing, so the conway mount is off" \
            "echo PASSWORD > ~/.ssh/jump_pass && chmod 600 ~/.ssh/jump_pass"
          continue
        fi
        systemctl --user enable --now sshfs-conway-watchdog.timer >/dev/null 2>&1 || true
        systemctl --user enable --now sshfs-conway >/dev/null 2>&1 ||
          echo "  conway unreachable, the watchdog will retry"
        ;;
    esac
  done
}

# --- user: restic ---------------------------------------------------------

step_restic() {
  if [ "$HOST_RESTIC" != 1 ]; then
    systemctl --user disable --now restic-backup.timer >/dev/null 2>&1 || true
    return 0
  fi
  if [ ! -f "$HOME/.config/restic/password" ]; then
    decide restic-password "Backups are off: no restic password on this machine" \
      "Run: sudo $DOTFILES/scripts/bootstrap.sh  (asks for it), or write ~/.config/restic/password (mode 600)"
    return 0
  fi
  if [ ! -f "$HOME/.config/restic/rest.env" ]; then
    decide restic-no-rest-login "Backups are off: no rest-server login on this machine" \
      "Run: sudo $DOTFILES/scripts/bootstrap.sh  (asks for it), or write ~/.config/restic/rest.env (mode 600)"
    return 0
  fi

  # The timer is enabled only after the repo has been found or created once, so
  # its presence already answers "does the repo exist" without a round trip.
  if ! systemctl --user is-enabled restic-backup.timer >/dev/null 2>&1; then
    set -a; . "$HOME/.config/restic/rest.env"; set +a
    export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
    restic snapshots >/dev/null 2>&1 || restic init
    systemctl --user enable --now restic-backup.timer
  fi
}

# --- user: claude ---------------------------------------------------------

# Interactive mode with no terminal adds what is declared and leaves anything
# undeclared in place; the strict removal stays a deliberate, manual act.
step_claude() {
  local out rc=0
  out=$(bash "$DOTFILES/scripts/claude-reconcile.sh" --interactive </dev/null 2>&1) || rc=$?
  printf '%s\n' "$out"
  if grep -q 'defaulting to skip' <<<"$out"; then
    decide "claude-undeclared-$(grep -B3 'defaulting to skip' <<<"$out" | digest_of)" \
      "Claude Code has plugins, skills or MCP servers the repo does not declare" \
      "Declare them in home/claude/.claude/reconcile/, or remove them with: scripts/claude-reconcile.sh --interactive"
  fi
  return "$rc"
}

# --- now ------------------------------------------------------------------

# Start both halves and follow their output until both finish. The system unit
# starts without a password through system/polkit/50-dotfiles-converge.rules.
now() {
  if ! systemctl cat dotfiles-converge.service >/dev/null 2>&1; then
    echo "converge is not installed on this machine yet. Run: sudo $DOTFILES/scripts/bootstrap.sh" >&2
    return 1
  fi
  systemctl start --no-block dotfiles-converge.service
  systemctl --user start --no-block dotfiles-converge.service

  journalctl -f -n 0 -o cat -u dotfiles-converge.service & J1=$!
  journalctl --user -f -n 0 -o cat -u dotfiles-converge.service & J2=$!
  trap 'kill $J1 $J2 2>/dev/null' EXIT
  sleep 2
  while busy "" || busy --user; do sleep 2; done
  sleep 1
  kill $J1 $J2 2>/dev/null || true
  echo
  "$OWNER_HOME/.local/bin/dotfiles" --list
}

busy() {
  # shellcheck disable=SC2086
  case "$(systemctl $1 show -P ActiveState dotfiles-converge.service)" in
    active|activating|deactivating|reloading) return 0 ;;
    *) return 1 ;;
  esac
}

# --- run ------------------------------------------------------------------

# One step, in-process, so `set -e` stops it at the first failing command. This
# is both the debugging path and what a full run re-invokes per step: bash
# suppresses errexit inside any conditional, so only a fresh process gets it
# back. Run standalone, a step prints its decisions and records nothing.
run_step() {
  export CONVERGE_STEP="$1"
  "step_$1"
}

run_scope() {
  local scope="$1"; shift
  local -a all
  if [ "$scope" = system ]; then
    [ "$(id -u)" = 0 ] || { echo "converge.sh system runs as root (the dotfiles-converge unit)" >&2; return 1; }
    all=("${SYSTEM_STEPS[@]}"); STATE="$SYSTEM_STATE"
    export HOME=/root
  else
    [ "$(id -u)" != 0 ] || { echo "converge.sh user runs as $OWNER, not root" >&2; return 1; }
    all=("${USER_STEPS[@]}"); STATE="$DOTFILES_STATE"
  fi

  local s
  for s in "$@"; do
    [[ " ${all[*]} " == *" $s "* ]] || { echo "unknown $scope step: $s (see --list)" >&2; return 2; }
  done
  if [ $# -eq 1 ]; then run_step "$1"; return; fi
  local steps=("${all[@]}")

  mkdir -p "$STATE/logs"
  chmod 0755 "$STATE" "$STATE/logs"
  exec 9>"$STATE/converge.lock"
  flock -n 9 || { echo "converge.sh $scope is already running"; return 0; }

  CONVERGE_DECISIONS="$(mktemp)"
  export CONVERGE_DECISIONS
  trap 'rm -f "$CONVERGE_DECISIONS"' EXIT

  local started records=() rc t0 log
  started=$(date -Iseconds)
  for s in "${steps[@]}"; do
    log="$STATE/logs/$s.log"
    say "$scope: $s"
    t0=$(date +%s)
    set +e
    CONVERGE_STEP="$s" bash "$SELF" "$scope" "$s" </dev/null 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    set -e
    chmod 0644 "$log"
    if [ "$rc" != 0 ]; then
      CONVERGE_STEP="$s" decide "failed-$scope-$s" \
        "converge: the $scope step '$s' failed (exit $rc)" "Log: $log"
    fi
    records+=("$(jq -nc --arg name "$s" --argjson rc "$rc" --argjson seconds "$(( $(date +%s) - t0 ))" \
      --arg log "$log" '{$name, status: (if $rc == 0 then "ok" else "failed" end), $seconds, $log}')")
  done

  printf '%s\n' "${records[@]}" | jq -s \
    --arg scope "$scope" --arg host "$HOST_NAME" --arg started "$started" \
    --arg finished "$(date -Iseconds)" \
    --arg head "$(git -c safe.directory="$DOTFILES" -C "$DOTFILES" rev-parse HEAD 2>/dev/null || true)" \
    --slurpfile decisions "$CONVERGE_DECISIONS" \
    '{$scope, $host, $started, $finished, $head, steps: ., decisions: ($decisions | unique_by(.id))}' \
    > "$STATE/decisions.json.tmp"
  chmod 0644 "$STATE/decisions.json.tmp"
  mv "$STATE/decisions.json.tmp" "$STATE/decisions.json"
  say "$scope: done, $(jq '.decisions | length' "$STATE/decisions.json") decision(s)"
}

case "${1:-}" in
  system|user) scope="$1"; shift; run_scope "$scope" "$@" ;;
  now)         now ;;
  --list)      printf 'system: %s\nuser:   %s\n' "${SYSTEM_STEPS[*]}" "${USER_STEPS[*]}" ;;
  *)           sed -n '2,15p' "$SELF" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
