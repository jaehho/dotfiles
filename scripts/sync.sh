#!/usr/bin/env bash
# sync.sh: idempotent host setup. Safe to re-run.
#
# Usage:
#   sync.sh                  # every phase, in order
#   sync.sh system stow      # only the named phases (for debugging)
#   sync.sh --list           # show phase names
#
# Env:
#   FORCE_UPGRADE=1  upgrade packages even if one ran in the last 24h
#   FORCE=1          apply boot-config changes without prompting

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"

# shellcheck source=lib.sh
. "$(dirname "$SELF")/lib.sh"

PHASES=(host pkgs tools stow system sshfs restic claude shell)

say() { echo "==> $*"; }

# --- host -----------------------------------------------------------------

phase_host() {
  DOTFILES="$DOTFILES" bash "$DOTFILES/scripts/setup-host.sh"
}

# --- pkgs -----------------------------------------------------------------

# A full upgrade is slow, needs sudo, and usually wants a reboot afterwards.
# Relinking dotfiles is none of those things. Gate the upgrade on staleness so
# that re-running sync after a config edit stays cheap, while a sync on a
# machine that has sat idle still pulls everything forward.
#
# pacman.log is the source of truth rather than a stamp file because it also
# sees upgrades run by hand outside sync. Caveat: pacman logs the line when the
# upgrade *starts*, so aborting at the confirm prompt still counts as recent —
# use FORCE_UPGRADE=1 to override.
UPGRADE_MAX_AGE="${UPGRADE_MAX_AGE:-86400}"

upgrade_is_stale() {
  [ "${FORCE_UPGRADE:-0}" = 1 ] && return 0
  [ "$DISTRO_FAMILY" = arch ] || return 0

  local log=/var/log/pacman.log last epoch age
  [ -r "$log" ] || return 0
  last=$(grep -F 'starting full system upgrade' "$log" 2>/dev/null | tail -1 |
           sed -n 's/^\[\([^]]*\)\].*/\1/p')
  [ -n "$last" ] || return 0
  epoch=$(date -d "$last" +%s 2>/dev/null) || return 0

  age=$(( $(date +%s) - epoch ))
  [ "$age" -ge "$UPGRADE_MAX_AGE" ] && return 0

  say "packages: last upgrade $(( age / 3600 ))h ago, skipping (FORCE_UPGRADE=1 to override)"
  return 1
}

phase_pkgs() {
  local skip=1
  upgrade_is_stale && skip=0
  DOTFILES="$DOTFILES" HOST_DEV_TOOLS="$HOST_DEV_TOOLS" SKIP_UPGRADE="$skip" \
    bash "$DOTFILES/scripts/packages.sh"
}

# --- tools ----------------------------------------------------------------

# HOST_DEV_TOOLS=1 builds hypr-tools from the submodule into ~/.local/bin,
# shadowing the AUR copies in /usr/bin. packages.sh already skips the AUR
# packages on such hosts.
phase_tools() {
  if [ "$HOST_DEV_TOOLS" != 1 ] || [ "$DISTRO_FAMILY" != arch ]; then
    return 0
  fi
  say "hypr-tools (dev override active)..."
  git -C "$DOTFILES" submodule update --init --recursive hypr-tools 2>&1 | sed 's/^/  /'
  if make -C "$DOTFILES/hypr-tools" install >/dev/null 2>&1; then
    echo "  hypr-tools: installed to ~/.local/bin"
  else
    echo "  hypr-tools: build failed" >&2
  fi
}

# --- stow -----------------------------------------------------------------

# Pre-stow cleanup handles three cases that would otherwise damage files or
# block stow:
#   1. Absolute symlinks into the repo: stow doesn't recognize these as "owned"
#      and refuses to re-stow. Remove so stow recreates them as relative.
#   2. Regular files reachable through a symlinked parent dir (realpath lands
#      inside the repo): a naive `mv` would follow the parent symlink and trash
#      the dotfiles copy. Skip — they're already linked in effect.
#   3. Regular files outside the repo: back up so stow can take over.
phase_stow() {
  say "Stowing dotfiles..."
  local pkg file rel target real link
  for pkg in "${STOW_PACKAGES[@]}"; do
    while IFS= read -r -d '' file; do
      rel="${file#"$DOTFILES/$pkg/"}"
      target="$HOME/$rel"
      # Runtime-generated files are handled explicitly below, never by the
      # cleanup loop — see STOW_SKIP in lib.sh.
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
    done < <(find "$DOTFILES/$pkg" -type f -print0)
    stow -d "$DOTFILES" -t ~ --no-folding "$pkg"
  done

  # mimeapps.list is owned here, not by stow (mime/.stow-local-ignore excludes
  # it). GLib's safe-write writes its tempfile next to the *resolved* target; a
  # relative symlink would resolve from CWD instead of the link's directory, so
  # Thunar et al. fail to update it unless CWD happens to be ~/.config. An
  # absolute symlink puts the tempfile in the right place regardless of CWD.
  if have update-mime-database && [ -d "$HOME/.local/share/mime/packages" ]; then
    update-mime-database "$HOME/.local/share/mime"
  fi
  target="$DOTFILES/mime/.config/mimeapps.list"
  link="$HOME/.config/mimeapps.list"
  mkdir -p "$(dirname "$link")"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    mv "$link" "$link.bak"
    echo "  mimeapps.list: backed up regular file to $link.bak"
  fi
  if [ ! -L "$link" ] || [ "$(readlink "$link")" != "$target" ]; then
    ln -sfn "$target" "$link"
  fi

  # monitors.conf is machine state, not config: hypr-monitor rewrites it on
  # every hotplug. hyprland.conf sources it unconditionally, so seed it from the
  # repo template on a fresh machine and then leave it alone forever. Linking it
  # would make hypr-monitor write back into the repo; backing it up each run
  # would clobber the previous .bak.
  if [[ " ${STOW_PACKAGES[*]} " == *" hypr "* ]]; then
    local mon="$HOME/.config/hypr/monitors.conf"
    if [ ! -e "$mon" ]; then
      mkdir -p "$(dirname "$mon")"
      cp "$DOTFILES/hypr/.config/hypr/monitors.conf" "$mon"
      echo "  monitors.conf: seeded from repo (hypr-monitor owns it from here)"
    fi
  fi
}

# --- system ---------------------------------------------------------------

phase_system() {
  say "System configs..."

  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi

  # One sudo call for every parent directory, so the password prompt lands once
  # up front rather than N times through the phase.
  local pair src dst dirs=()
  for pair in "${SYSTEM_LINKS[@]}" "${SYSTEM_COPIES[@]}"; do
    dirs+=("$(dirname "${pair##*:}")")
  done
  sudo mkdir -p "${dirs[@]}"

  for pair in "${SYSTEM_LINKS[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    sudo ln -sf "$src" "$dst"
  done

  # systemd-sleep(8) v260+ only scans /usr/lib/systemd/system-sleep/, so drop
  # the copies an older sync left in /etc.
  sudo rm -f /etc/systemd/system-sleep/fuse-mounts \
             /etc/systemd/system-sleep/hyprlock-restart \
             /etc/systemd/logind.conf.d/10-lid-hibernate.conf
  sudo sysctl --system >/dev/null
  sudo systemctl reload systemd-logind.service

  # NetworkManager refuses symlinked or non-root dispatcher scripts, so these
  # are install-copied rather than linked.
  sudo install -D -m 0755 -o root -g root \
    "$DOTFILES/NetworkManager/dispatcher.d/50-restart-sshfs" \
    /etc/NetworkManager/dispatcher.d/50-restart-sshfs
  sudo install -D -m 0755 -o root -g root \
    "$DOTFILES/NetworkManager/dispatcher.d/60-tzupdate" \
    /etc/NetworkManager/dispatcher.d/60-tzupdate
  if [ "$HOST_NO_AAAA" = 1 ]; then
    sudo install -D -m 0755 -o root -g root \
      "$DOTFILES/NetworkManager/dispatcher.d/90-no-aaaa" \
      /etc/NetworkManager/dispatcher.d/90-no-aaaa
  else
    sudo rm -f /etc/NetworkManager/dispatcher.d/90-no-aaaa
  fi

  # Boot-critical copies. Diverging from the repo is expected (a pacman upgrade
  # may ship a new default), so show the diff and ask rather than clobbering.
  local changed="" apply
  for pair in "${SYSTEM_COPIES[@]}"; do
    src="$(src_path "${pair%%:*}")"; dst="${pair##*:}"
    if [ ! -f "$dst" ]; then
      sudo cp "$src" "$dst"
      echo "  $dst: installed (new)"
    elif cmp -s "$src" "$dst"; then
      continue
    else
      echo
      echo "  $dst differs from repo:"
      git diff --no-index --color=always "$dst" "$src" || true
      echo
      if [ "${FORCE:-0}" = 1 ]; then
        apply=y
      else
        printf '  Apply this change? [y/N/q] '
        read -r apply < /dev/tty
      fi
      case "$apply" in
        y|Y) sudo cp "$dst" "$dst.bak"
             sudo cp "$src" "$dst"
             echo "  $dst: applied (backup at $dst.bak)"
             changed="$changed $dst" ;;
        q|Q) echo "  aborted."; return 1 ;;
        *)   echo "  $dst: skipped" ;;
      esac
    fi
  done

  if have keyd; then
    sudo systemctl enable --now keyd >/dev/null 2>&1 || sudo systemctl restart keyd
  fi

  # pacman-contrib ships paccache.timer disabled. Weekly, keeps the 3 newest
  # versions; the drop-in above adds a pass for removed packages. daemon-reload
  # first so the drop-in is picked up on the run that installs it.
  if [ "$DISTRO_FAMILY" = arch ] && systemctl cat paccache.timer >/dev/null 2>&1; then
    sudo systemctl daemon-reload
    if sudo systemctl enable --now paccache.timer >/dev/null 2>&1; then
      echo "  paccache.timer: enabled (weekly cache prune)"
    fi
  fi

  # kernel-modules-hook ships this disabled, so module trees for uninstalled
  # kernels pile up in /usr/lib/modules. That is not just disk: DKMS iterates
  # those directories, so every nvidia upgrade rebuilds against every dead
  # kernel. Runs at boot; the drop-in above prunes the archive it leaves.
  if [ "$DISTRO_FAMILY" = arch ] && systemctl cat linux-modules-cleanup.service >/dev/null 2>&1; then
    if sudo systemctl enable linux-modules-cleanup.service >/dev/null 2>&1; then
      echo "  linux-modules-cleanup: enabled (prunes old kernel modules at boot)"
    fi
  fi

  # reflector keeps the mirrorlist ranked by measured speed; config is linked
  # above. Generate one immediately the first time, otherwise the machine waits
  # up to a week for the timer. reflector stamps a header into the file it
  # writes, which doubles as the idempotency check.
  if [ "$DISTRO_FAMILY" = arch ] && systemctl cat reflector.timer >/dev/null 2>&1; then
    sudo systemctl enable --now reflector.timer >/dev/null 2>&1 &&
      echo "  reflector.timer: enabled (weekly mirror ranking)"
    if ! grep -qi 'generated by reflector' /etc/pacman.d/mirrorlist 2>/dev/null; then
      echo "  reflector: ranking mirrors for the first time (measures speed, ~1 min)..."
      if sudo systemctl start reflector.service; then
        echo "  reflector: mirrorlist now has $(grep -c '^Server' /etc/pacman.d/mirrorlist) ranked mirrors"
      else
        echo "  reflector: run failed — the existing mirrorlist is untouched" >&2
      fi
    fi
    # Once reflector owns this file, the packaged mirrorlist is by definition
    # obsolete, so a .pacnew for it carries nothing worth merging.
    sudo rm -f /etc/pacman.d/mirrorlist.pacnew
  fi

  case "$changed" in *grub*)       echo "  -> Run: sudo grub-mkconfig -o /boot/grub/grub.cfg" ;; esac
  case "$changed" in *mkinitcpio*) echo "  -> Run: sudo mkinitcpio -P" ;; esac
}

# --- sshfs ----------------------------------------------------------------

phase_sshfs() {
  say "sshfs..."

  # Tear down any mount a previous sync enabled that this host now skips.
  if [ ${#SSHFS_SKIPPED[@]} -gt 0 ]; then
    echo "  skipping (HOST_SSHFS_SKIP): ${SSHFS_SKIPPED[*]}"
    local m
    for m in "${SSHFS_SKIPPED[@]}"; do
      case "$m" in
        ice) systemctl --user disable --now sshfs-ice >/dev/null 2>&1 || true
             systemctl --user disable --now sshfs-ice-watchdog.timer >/dev/null 2>&1 || true ;;
        *)   systemctl --user stop "sshfs-$m" >/dev/null 2>&1 || true ;;
      esac
      fusermount3 -uz "$HOME/mnt/$m" 2>/dev/null || true
    done
  fi

  if [ ${#SSHFS_MOUNTS[@]} -eq 0 ]; then
    echo "  all mounts in HOST_SSHFS_SKIP — nothing to set up."
    return 0
  fi

  mkdir -p "$HOME/mnt"
  local m
  for m in "${SSHFS_MOUNTS[@]}"; do
    # A dead sshfs mount leaves its mountpoint reporting "Transport endpoint is
    # not connected", and in that state even `mkdir -p` fails — which is enough
    # to abort the whole phase. Detach it lazily and retry. Reboots and dropped
    # links leave exactly this behind, so it is the normal case, not an edge one.
    if ! mkdir -p "$HOME/mnt/$m" 2>/dev/null; then
      echo "  $m: stale mountpoint, detaching"
      fusermount3 -uz "$HOME/mnt/$m" 2>/dev/null || true
      mkdir -p "$HOME/mnt/$m"
    fi
  done
  systemctl --user daemon-reload

  for m in "${SSHFS_MOUNTS[@]}"; do
    case "$m" in
      # Always-on jump-host mount. Best-effort: ice is often off-network, so a
      # failed mount must not abort sync. Enable the watchdog either way — it
      # remounts once ice becomes reachable.
      ice)
        if [ ! -f "$HOME/.ssh/jump_pass" ]; then
          echo "  ~/.ssh/jump_pass missing — skipping ice mount"
          echo "    Create with: echo PASSWORD > ~/.ssh/jump_pass && chmod 600 ~/.ssh/jump_pass"
          continue
        fi
        systemctl --user enable --now sshfs-ice-watchdog.timer >/dev/null 2>&1 || true
        if systemctl --user enable --now sshfs-ice >/dev/null 2>&1; then
          echo "  ice mounted at ~/mnt/ice"
        else
          echo "  ice unreachable — watchdog timer will retry"
        fi
        ;;
      # Opt-in: only attach if the GCE instance is already running.
      cdn)
        have gcloud || continue
        local state
        state=$(gcloud compute instances describe cdn-project --zone=us-east4-b \
                  --format='value(status)' 2>/dev/null || true)
        if [ "$state" = RUNNING ]; then
          systemctl --user start sshfs-cdn >/dev/null 2>&1 &&
            echo "  cdn mounted at ~/mnt/cdn (instance running)" || true
        fi
        ;;
      # Opt-in: only attach if the host answers.
      msi)
        if ssh -o ConnectTimeout=2 -o BatchMode=yes msi true 2>/dev/null; then
          systemctl --user start sshfs-msi >/dev/null 2>&1 &&
            echo "  msi mounted at ~/mnt/msi (host reachable)" || true
        fi
        ;;
    esac
  done
}

# --- restic ---------------------------------------------------------------

phase_restic() {
  if [ "$HOST_RESTIC" != 1 ]; then
    say "restic: disabled for $HOST_NAME"
    systemctl --user disable --now restic-backup.timer >/dev/null 2>&1 || true
    return 0
  fi
  say "restic..."

  mkdir -p "$HOME/.config/restic"
  if [ ! -f "$HOME/.config/restic/password" ]; then
    echo "  Set a restic repository password:"
    local pw pw2
    read -rsp "  Password: " pw < /dev/tty; echo
    read -rsp "  Confirm:  " pw2 < /dev/tty; echo
    if [ "$pw" != "$pw2" ]; then
      echo "  passwords do not match — skipping"
      return 0
    fi
    install -m 600 /dev/null "$HOME/.config/restic/password"
    printf '%s' "$pw" > "$HOME/.config/restic/password"
    echo "  Password saved to ~/.config/restic/password"
  fi

  # Captured, not piped: `grep -q` exits on its first match and SIGPIPEs the
  # producer, which `set -o pipefail` then reports as a failed pipeline — so
  # the piped form would claim the remote is missing exactly when it exists.
  local remotes
  remotes="$(rclone listremotes 2>/dev/null || true)"
  if ! grep -q '^nextcloud:' <<<"$remotes"; then
    echo "  'nextcloud' remote not configured — skipping repo init."
    return 0
  fi

  export RESTIC_REPOSITORY=rclone:nextcloud:Backups/restic
  export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
  if ! restic snapshots >/dev/null 2>&1; then
    echo "  Initializing restic repo at nextcloud:Backups/restic..."
    restic init
  fi
  systemctl --user daemon-reload
  if systemctl --user enable --now restic-backup.timer >/dev/null 2>&1; then
    echo "  backup timer enabled — next run: $(systemctl --user list-timers \
      restic-backup.timer --no-legend | awk '{print $1, $2}')"
  fi
}

# --- claude ---------------------------------------------------------------

phase_claude() {
  say "Claude Code reconcile..."
  DOTFILES="$DOTFILES" bash "$DOTFILES/scripts/claude-reconcile.sh" --interactive
}

# --- shell ----------------------------------------------------------------

phase_shell() {
  local fish_path
  fish_path="$(command -v fish || true)"
  if [ -z "$fish_path" ]; then
    say "Default shell: fish not installed, skipping"
    return 0
  fi
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$fish_path" ] && return 0

  say "Setting fish as default shell..."
  grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
  chsh -s "$fish_path"
  echo "  log out and back in for fish to take effect."
}

# --- dispatch -------------------------------------------------------------

epilogue() {
  echo
  echo "==> Sync complete."
  echo "    Reload running tools to pick up dotfile changes:"
  echo "      fish     exec fish"
  echo "      tmux     tmux source-file ~/.tmux.conf"
  echo "      nvim     :source \$MYVIMRC"
  if [[ " ${STOW_PACKAGES[*]} " == *" hypr "* ]]; then
    echo "      hypr     hyprctl reload"
    echo "      swaync   swaync-client -rs"
    echo "      waybar   killall -SIGUSR2 waybar"
  fi
}

main() {
  if [ "${1:-}" = "--list" ]; then
    printf '%s\n' "${PHASES[@]}"
    return 0
  fi

  local requested=("$@") p
  if [ ${#requested[@]} -eq 0 ]; then
    requested=("${PHASES[@]}")
  else
    for p in "${requested[@]}"; do
      [[ " ${PHASES[*]} " == *" $p "* ]] || {
        echo "unknown phase: $p (see --list)" >&2
        return 2
      }
    done
  fi

  # A single named phase runs in-process so `set -e` aborts it on the first
  # failing command — the behaviour you want when debugging one phase.
  if [ ${#requested[@]} -eq 1 ]; then
    "phase_${requested[0]}"
    return 0
  fi

  # Several phases: run each as its own process.
  #
  # One broken AUR package should never be the reason your dotfiles went
  # unstowed, but a failure *inside* a phase must still stop that phase. Bash
  # cannot do both in a single process: it suppresses errexit for the entire
  # dynamic extent of anything in a conditional or ||-list, and re-running
  # `set -e` inside does not restore it. A fresh shell per phase gets it back.
  local failed=()
  for p in "${requested[@]}"; do
    bash "$SELF" "$p" || {
      failed+=("$p")
      echo "!! phase '$p' failed — continuing with the rest" >&2
    }
  done

  if [ ${#failed[@]} -gt 0 ]; then
    echo
    echo "==> Sync finished, but ${#failed[@]} phase(s) failed: ${failed[*]}"
    echo "    Retry just those:  ./scripts/sync.sh ${failed[*]}"
    return 1
  fi

  # Only a clean full run earns the "everything is done" banner.
  [ ${#requested[@]} -eq ${#PHASES[@]} ] && epilogue
  return 0
}

main "$@"
