#!/usr/bin/env bash
# Claude Code notification hook — desktop notifications via notify-send.
# Handles: Stop (response complete), Notification (permission prompts).
# Daemon-agnostic: uses libnotify + freedesktop CloseNotification D-Bus method.

set -euo pipefail

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')


truncate() {
  local text="$1" max="${2:-200}"
  if (( ${#text} > max )); then
    echo "${text:0:$max}…"
  else
    echo "$text"
  fi
}

play_sound() {
  setsid ffplay -nodisp -autoexit -loglevel quiet -f lavfi "sine=f=800:d=0.15" </dev/null &>/dev/null &
}

case "$EVENT" in

  Stop)
    [[ $(echo "$INPUT" | jq -r '.stop_hook_active // false') == "true" ]] && exit 0

    TITLE="Claude finished"
    FULL_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Response complete."')
    BODY=$(truncate "$FULL_MSG" 300)
    URGENCY="normal"
    ;;

  Notification)
    TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    MSG=$(echo "$INPUT" | jq -r '.message // empty')

    case "$TYPE" in
      permission_prompt)
        TITLE="Permission needed"
        BODY="${MSG:-Claude needs your approval.}"
        URGENCY="normal"
        ;;
      *)
        exit 0
        ;;
    esac
    ;;

  *) exit 0 ;;
esac

# ── Resolve source window + tmux pane (for notification focus) ────────────────
resolve_window_address() {
  local clients pid addr

  clients=$(hyprctl clients -j 2>/dev/null) || return 1

  # tmux client PID bridges the client/server split; fall back to own PID
  pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null) || pid=$$

  # Walk ancestors, matching against hyprland window PIDs (terminal-agnostic)
  while [ "$pid" -gt 1 ] 2>/dev/null; do
    addr=$(printf '%s' "$clients" | jq -r --argjson p "$pid" \
      '.[] | select(.pid == $p) | .address' 2>/dev/null)
    if [[ -n "$addr" ]]; then
      printf '%s' "$addr"
      return 0
    fi
    pid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null) || break
  done

  # Last resort: focused window (likely correct right after a response)
  hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
# Desktop: notify-send on local Wayland; OSC 99 for SSH/remote.
# tmux only refreshes env on client attach, so a pane created before the
# graphical session (or restored by tmux-resurrect) can carry an empty
# WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE. That misroutes a *local* pane
# into the SSH/remote branch below, which arms a global client-focus-in hook
# that yanks the session on the next unrelated focus. Recover the env from
# XDG_RUNTIME_DIR so local panes always take the desktop-notify path.
if [[ -z "${SSH_CONNECTION:-}" ]]; then
  _runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    for _sock in "$_runtime"/wayland-*; do
      [[ -S "$_sock" ]] && { export WAYLAND_DISPLAY="${_sock##*/}"; break; }
    done
  fi
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d "$_runtime/hypr" ]]; then
    for _d in "$_runtime"/hypr/*/; do
      [[ -d "$_d" ]] && { export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$_d")"; break; }
    done
  fi
fi

if [[ -z "${SSH_CONNECTION:-}" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  play_sound
  WINDOW_ADDR=$(resolve_window_address) || true
  TMUX_SOCKET="${TMUX:-}"
  TMUX_SOCKET="${TMUX_SOCKET%%,*}"
  TMUX_TARGET=""
  if [[ -n "${TMUX_PANE:-}" ]]; then
    TMUX_TARGET=$(tmux display-message -t "$TMUX_PANE" \
      -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null) || true
  fi

  # -t 0 = never auto-expire; the watcher below dismisses on focus / source death
  NOTIFY_ARGS=(--app-name="Claude Code" -u "${URGENCY:-normal}" -t 0 --action=default=Focus)

  # setsid detaches so Claude doesn't wait. Single FIFO carries notify-send
  # stdout: line 1 = notification ID (--print-id), line 2 = action on click.
  # Each setsid captures its own window address + tmux target in the closure,
  # so concurrent notifications independently focus the correct terminal + pane.
  # A background watcher auto-dismisses if the source dies or user is looking.
  setsid bash -c '
    WINDOW_ADDR="$1"; TMUX_SOCKET="$2"; TMUX_TARGET="$3"; shift 3

    # Daemon-agnostic dismiss: standard freedesktop CloseNotification D-Bus method.
    dismiss_notif() {
      gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.CloseNotification \
        "$1" >/dev/null 2>&1
    }

    tmpdir=$(mktemp -d) || exit 1
    mkfifo "$tmpdir/out"
    trap "rm -rf \"$tmpdir\"" EXIT

    notify-send --print-id "$@" > "$tmpdir/out" &
    NS_PID=$!

    exec 3< "$tmpdir/out"
    read -r NOTIF_ID <&3 2>/dev/null

    # Watcher: dismiss when source dies OR user is already looking at the pane
    if [[ -n "$NOTIF_ID" ]]; then
      (
        focused_count=0
        while kill -0 "$NS_PID" 2>/dev/null; do
          sleep 5
          # Source liveness check
          alive=false
          if [[ -n "$TMUX_TARGET" ]]; then
            tmux -S "$TMUX_SOCKET" display-message -t "$TMUX_TARGET" -p "" 2>/dev/null && alive=true
          elif [[ -n "$WINDOW_ADDR" ]]; then
            hyprctl clients -j 2>/dev/null \
              | jq -e --arg a "$WINDOW_ADDR" ".[] | select(.address == \$a)" >/dev/null 2>&1 && alive=true
          else
            alive=true
          fi
          "$alive" || { dismiss_notif "$NOTIF_ID"; break; }

          # Focus check: dismiss after sustained focus on the source pane.
          # Skip if a default action was just invoked (panel click) — the focus
          # shift below is intentional and would otherwise cascade-dismiss
          # sibling notifications that share the same source pane.
          _inv_ts=$(cat /tmp/hypr-notification-invoke 2>/dev/null || echo 0)
          if (( $(date +%s) - _inv_ts < 15 )); then focused_count=0; continue; fi
          pane_focused=false
          active_addr=$(hyprctl activewindow -j 2>/dev/null | jq -r ".address // empty" 2>/dev/null)
          if [[ -n "$TMUX_TARGET" && "$active_addr" == "$WINDOW_ADDR" ]]; then
            # Require both the source window AND the source pane to be currently
            # displayed. #{pane_active} alone is per-window, so switching to a
            # different tmux window in the same terminal would still read 1.
            [[ "$(tmux -S "$TMUX_SOCKET" display-message -t "$TMUX_TARGET" \
              -p "#{window_active}:#{pane_active}" 2>/dev/null)" == "1:1" ]] && pane_focused=true
          elif [[ -z "$TMUX_TARGET" && "$active_addr" == "$WINDOW_ADDR" ]]; then
            pane_focused=true
          fi
          if "$pane_focused"; then
            (( ++focused_count ))
            (( focused_count >= 1 )) && { dismiss_notif "$NOTIF_ID"; break; }
          else
            focused_count=0
          fi
        done
      ) &
      WATCHER=$!
    fi

    read -r action <&3 2>/dev/null
    exec 3<&-
    wait "$NS_PID" 2>/dev/null
    [[ -n "${WATCHER:-}" ]] && kill "$WATCHER" 2>/dev/null && wait "$WATCHER" 2>/dev/null

    if [[ "$action" == "default" ]]; then
      # Tell sibling watchers to skip focus-based dismiss for 15s — see watcher above.
      date +%s > /tmp/hypr-notification-invoke
      if [[ -n "$WINDOW_ADDR" ]] && hyprctl clients -j 2>/dev/null \
           | jq -e --arg a "$WINDOW_ADDR" ".[] | select(.address == \$a)" >/dev/null 2>&1; then
        hyprctl dispatch focuswindow "address:$WINDOW_ADDR" >/dev/null 2>&1
      fi
      if [[ -n "$TMUX_TARGET" ]]; then
        tmux -S "$TMUX_SOCKET" select-window -t "${TMUX_TARGET%.*}" 2>/dev/null
        tmux -S "$TMUX_SOCKET" select-pane -t "$TMUX_TARGET" 2>/dev/null
      fi
    fi
  ' _ "${WINDOW_ADDR:-}" "${TMUX_SOCKET:-}" "${TMUX_TARGET:-}" \
    "${NOTIFY_ARGS[@]}" "$TITLE" "$BODY" </dev/null &>/dev/null &
else
  # SSH/remote: kitty OSC 99 desktop notification. Clicking focuses the kitty
  # window; we deliberately do NOT auto-switch tmux. The only available trigger
  # would be a global client-focus-in hook, but that fires on any unrelated
  # refocus (not just the notification click) and can yank a different session.
  "$HOME/.local/bin/notify" "$TITLE" "$BODY" &
fi

exit 0
