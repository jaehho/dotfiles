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
        ;;
      idle_prompt)
        TITLE="Claude is waiting"
        BODY="${MSG:-Waiting for your input.}"
        URGENCY="normal"
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

# Send the notification
notify-send \
  --app-name "Claude Code" \
  --urgency "$URGENCY" \
  --category "$(if [[ $URGENCY == "high" ]]; then echo persistent; fi)" \
  "$TITLE" \
  "$BODY"

exit 0
