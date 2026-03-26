#!/usr/bin/env bash
# Claude Code notification hook — desktop notifications via notify-send (mako)
# Handles: Stop (response complete), Notification (permission/idle prompts)

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
    BODY=$(truncate "$(echo "$INPUT" | jq -r '.last_assistant_message // "Response complete."')" 300)
    URGENCY="normal"
    play_sound
    ;;

  Notification)
    TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    MSG=$(echo "$INPUT" | jq -r '.message // empty')

    case "$TYPE" in
      permission_prompt)
        TITLE="Permission needed"
        BODY="${MSG:-Claude needs your approval.}"
        URGENCY="high"
        CATEGORY="persistent"
        play_sound
        ;;
      idle_prompt)
        TITLE="Claude is waiting"
        BODY="${MSG:-Waiting for your input.}"
        URGENCY="normal"
        play_sound
        ;;
      *)
        TITLE=$(echo "$INPUT" | jq -r '.title // "Claude Code"')
        BODY="${MSG:-$TYPE}"
        URGENCY="normal"
        ;;
    esac
    ;;

  *) exit 0 ;;
esac

# ── Dispatch ──────────────────────────────────────────────────────────────────
if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
  # Find terminal window in Hyprland for focus-on-click
  find_terminal_window() {
    local pid="${KITTY_PID:-}"
    [[ -z "$pid" ]] && return
    hyprctl clients -j 2>/dev/null | jq -r --argjson pid "$pid" \
      '.[] | select(.pid == $pid) | .address' 2>/dev/null
  }

  WINDOW_ADDR=$(find_terminal_window || true)

  (
    ACTION=$(notify-send \
      --app-name "Claude Code" \
      --urgency "$URGENCY" \
      ${CATEGORY:+--category "$CATEGORY"} \
      --action="default=Focus" \
      "$TITLE" \
      "$BODY" 2>/dev/null) || true

    if [[ "$ACTION" == "default" && -n "${WINDOW_ADDR:-}" ]]; then
      hyprctl dispatch focuswindow "address:$WINDOW_ADDR" &>/dev/null
    fi
  ) &
else
  # Fallback: ntfy.sh for remote/SSH sessions
  NTFY_PRIORITY="default"
  [[ "$URGENCY" == "high" ]] && NTFY_PRIORITY="high"
  curl -s -o /dev/null \
    -H "Title: $TITLE" \
    -H "Priority: $NTFY_PRIORITY" \
    -d "$BODY" \
    ntfy.sh/jaeho &
fi

exit 0
