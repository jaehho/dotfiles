#!/usr/bin/env bash
# Claude Code notification hook — desktop notifications via notify-send (mako)
# Handles: Stop (response complete), Notification (permission prompts)

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
  ffplay -nodisp -autoexit -loglevel quiet -f lavfi "sine=f=800:d=0.15" &>/dev/null &
}

case "$EVENT" in

  Stop)
    [[ $(echo "$INPUT" | jq -r '.stop_hook_active // false') == "true" ]] && exit 0

    TITLE="Claude finished"
    FULL_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Response complete."')
    BODY=$(truncate "$FULL_MSG" 300)
    NTFY_BODY=$(truncate "$FULL_MSG" 4000)
    URGENCY="normal"
    CATEGORY="persistent"
    play_sound
    ;;

  Notification)
    TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    MSG=$(echo "$INPUT" | jq -r '.message // empty')

    case "$TYPE" in
      permission_prompt)
        TITLE="Permission needed"
        BODY="${MSG:-Claude needs your approval.}"
        URGENCY="normal"
        CATEGORY="persistent"
        play_sound
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
  local pid
  pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null) || pid=$$
  while [ "$pid" -gt 1 ] 2>/dev/null; do
    if [[ "$(cat /proc/"$pid"/comm 2>/dev/null)" == "kitty" ]]; then
      hyprctl clients -j 2>/dev/null \
        | jq -r --argjson p "$pid" '.[] | select(.pid == $p) | .address' 2>/dev/null
      return
    fi
    pid=$(awk '/^PPid:/{print $2}' /proc/"$pid"/status 2>/dev/null) || return
  done
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
# Desktop: notify-send (mako) on local Wayland; OSC 99 for SSH/remote
if [[ -z "${SSH_CONNECTION:-}" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  WINDOW_ADDR=$(resolve_window_address)
  TMUX_SOCKET="${TMUX%%,*}"
  TMUX_TARGET=""
  if [[ -n "${TMUX_PANE:-}" ]]; then
    TMUX_TARGET=$(tmux display-message -t "$TMUX_PANE" \
      -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null) || true
  fi

  NOTIFY_ARGS=(--app-name="Claude Code" -u "${URGENCY:-normal}")
  [[ -n "${CATEGORY:-}" ]] && NOTIFY_ARGS+=(-c "$CATEGORY")
  NOTIFY_ARGS+=(--action=default=Focus)

  # setsid detaches from hook process group so Claude doesn't wait for dismiss.
  # Each process captures its own window address + tmux target in the closure,
  # so multiple concurrent notifications each focus the correct terminal + pane.
  setsid bash -c '
    WINDOW_ADDR="$1"; TMUX_SOCKET="$2"; TMUX_TARGET="$3"; shift 3
    action=$(notify-send "$@")
    if [[ "$action" == "default" ]]; then
      # Focus the kitty window
      if [[ -n "$WINDOW_ADDR" ]] && hyprctl clients -j 2>/dev/null \
           | jq -e --arg a "$WINDOW_ADDR" ".[] | select(.address == \$a)" >/dev/null 2>&1; then
        hyprctl dispatch focuswindow "address:$WINDOW_ADDR" >/dev/null 2>&1
      else
        hyprctl dispatch focuswindow "class:kitty" >/dev/null 2>&1
      fi
      # Switch to the exact tmux pane
      if [[ -n "$TMUX_TARGET" ]]; then
        tmux -S "$TMUX_SOCKET" select-window -t "${TMUX_TARGET%.*}" 2>/dev/null
        tmux -S "$TMUX_SOCKET" select-pane -t "$TMUX_TARGET" 2>/dev/null
      fi
    fi
  ' _ "${WINDOW_ADDR:-}" "${TMUX_SOCKET:-}" "${TMUX_TARGET:-}" \
    "${NOTIFY_ARGS[@]}" "$TITLE" "$BODY" </dev/null &>/dev/null &
else
  "$HOME/.local/bin/notify" "$TITLE" "$BODY" &
fi

# Mobile: ntfy.sh (always, so you get notified even away from desk)
NTFY_PRIORITY="default"
[[ "${URGENCY:-normal}" == "high" ]] && NTFY_PRIORITY="high"
curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -H "Title: $TITLE" \
  -H "Priority: $NTFY_PRIORITY" \
  -d "${NTFY_BODY:-$BODY}" \
  ntfy.sh/jaeho &

exit 0
