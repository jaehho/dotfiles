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
# Desktop: OSC 99 via Kitty (works locally, through tmux, and over SSH)
"$HOME/.local/bin/notify" "$TITLE" "$BODY" &

# Mobile: ntfy.sh (always, so you get notified even away from desk)
NTFY_PRIORITY="default"
[[ "${URGENCY:-normal}" == "high" ]] && NTFY_PRIORITY="high"
curl -s -o /dev/null \
  -H "Title: $TITLE" \
  -H "Priority: $NTFY_PRIORITY" \
  -d "$BODY" \
  ntfy.sh/jaeho &

exit 0
