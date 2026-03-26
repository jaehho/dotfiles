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
    FULL_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Response complete."')
    BODY=$(truncate "$FULL_MSG" 300)
    NTFY_BODY=$(truncate "$FULL_MSG" 4000)
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
        URGENCY="normal"
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

# ── Resolve source window (for SUPER+. focus) ────────────────────────────────
save_window_address() {
  local pid
  pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null) || pid=$$
  while [ "$pid" -gt 1 ] 2>/dev/null; do
    if [[ "$(cat /proc/"$pid"/comm 2>/dev/null)" == "kitty" ]]; then
      local addr
      addr=$(hyprctl clients -j 2>/dev/null \
        | jq -r --argjson p "$pid" '.[] | select(.pid == $p) | .address' 2>/dev/null)
      if [[ -n "$addr" ]]; then
        echo "$addr" > "${XDG_RUNTIME_DIR:-/tmp}/claude-notify-window"
      fi
      return
    fi
    pid=$(awk '/^PPid:/{print $2}' /proc/"$pid"/status 2>/dev/null) || return
  done
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
# Desktop: notify-send (mako) on local Wayland; OSC 99 for SSH/remote
if [[ -z "${SSH_CONNECTION:-}" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  save_window_address
  NOTIFY_ARGS=(--app-name="Claude Code" -u "${URGENCY:-normal}")
  [[ -n "${CATEGORY:-}" ]] && NOTIFY_ARGS+=(-c "$CATEGORY")
  notify-send "${NOTIFY_ARGS[@]}" "$TITLE" "$BODY" &
else
  "$HOME/.local/bin/notify" "$TITLE" "$BODY" &
fi

# Mobile: ntfy.sh (always, so you get notified even away from desk)
NTFY_PRIORITY="default"
[[ "${URGENCY:-normal}" == "high" ]] && NTFY_PRIORITY="high"
curl -s -o /dev/null \
  -H "Title: $TITLE" \
  -H "Priority: $NTFY_PRIORITY" \
  -d "${NTFY_BODY:-$BODY}" \
  ntfy.sh/jaeho &

exit 0
