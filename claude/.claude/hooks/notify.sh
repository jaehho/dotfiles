#!/usr/bin/env bash
# Claude Code notification hook — sends detailed desktop notifications via notify-send (mako)
# Receives JSON on stdin with event-specific fields.

set -euo pipefail

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

# Truncate long strings for notification body
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

# Find the Hyprland window containing this terminal by walking up the process tree
find_terminal_window() {
  local clients pid addr
  clients=$(hyprctl clients -j 2>/dev/null) || return
  pid=$$
  while [[ $pid -gt 1 ]]; do
    addr=$(echo "$clients" | jq -r --argjson pid "$pid" \
      '.[] | select(.pid == $pid) | .address' 2>/dev/null)
    if [[ -n "$addr" && "$addr" != "null" ]]; then
      echo "$addr"
      return
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
}

WINDOW_ADDR=$(find_terminal_window || true)

case "$EVENT" in

  # ── Stop: Claude finished responding ──────────────────────────────
  Stop)
    LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
    STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
    SUMMARY=$(truncate "$LAST_MSG" 300)

    # stop_hook_active means Claude paused for a hook, not a real stop
    if [[ "$STOP_ACTIVE" == "true" ]]; then
      exit 0
    fi

    TITLE="Claude finished"
    BODY="${SUMMARY:-Response complete.}"
    URGENCY="normal"
    play_sound
    ;;

  # ── Notification: generic Claude Code notification ────────────────
  Notification)
    TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    MSG=$(echo "$INPUT" | jq -r '.message // empty')
    NOTIF_TITLE=$(echo "$INPUT" | jq -r '.title // empty')

    case "$TYPE" in
      permission_prompt)
        TITLE="Permission needed"
        BODY="${MSG:-Claude needs your approval.}"
        URGENCY="high"
        play_sound
        ;;
      idle_prompt)
        TITLE="Claude is waiting"
        BODY="${MSG:-Waiting for your input.}"
        URGENCY="normal"
        play_sound
        ;;
      *)
        TITLE="${NOTIF_TITLE:-Claude Code}"
        BODY="${MSG:-$TYPE}"
        URGENCY="normal"
        ;;
    esac
    ;;

  # ── PostToolUseFailure: a tool errored ────────────────────────────
  PostToolUseFailure)
    TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
    ERROR=$(echo "$INPUT" | jq -r '.error // empty')
    IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')

    if [[ "$IS_INTERRUPT" == "true" ]]; then
      exit 0  # user-initiated interrupt, don't notify
    fi

    TITLE="Tool failed: $TOOL"
    BODY=$(truncate "$ERROR" 300)
    URGENCY="high"
    ;;

  # ── SubagentStop: a subagent finished ─────────────────────────────
  SubagentStop)
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
    LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
    SUMMARY=$(truncate "$LAST_MSG" 200)

    TITLE="Agent finished: $AGENT_TYPE"
    BODY="${SUMMARY:-Done.}"
    URGENCY="low"
    ;;

  *)
    # Unknown event — skip silently
    exit 0
    ;;
esac

# Add click hint and send notification (backgrounded since --action implies --wait)
HINT_BODY="$BODY
<small><i>click or Super+N to focus</i></small>"

(
  ACTION=$(notify-send \
    --app-name "Claude Code" \
    --urgency "$URGENCY" \
    --category "$(if [[ $URGENCY == "high" ]]; then echo persistent; fi)" \
    --action="default=Focus" \
    "$TITLE" \
    "$HINT_BODY" 2>/dev/null) || true

  if [[ "$ACTION" == "default" && -n "${WINDOW_ADDR:-}" ]]; then
    hyprctl dispatch focuswindow "address:$WINDOW_ADDR" >/dev/null 2>&1
  fi
) &

exit 0
