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
  setsid ffplay -nodisp -autoexit -loglevel quiet -f lavfi "sine=f=800:d=0.15" </dev/null &>/dev/null &
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

# ── ntfy.sh priority ────────────────────────────────────────────────────────
NTFY_PRIORITY="default"
[[ "${URGENCY:-normal}" == "high" ]] && NTFY_PRIORITY="high"

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

  # setsid detaches so Claude doesn't wait. Single FIFO carries notify-send
  # stdout: line 1 = notification ID (--print-id), line 2 = action on click.
  # Each setsid captures its own window address + tmux target in the closure,
  # so concurrent notifications independently focus the correct terminal + pane.
  # A background watcher auto-dismisses if the source dies or user is looking.
  setsid bash -c '
    WINDOW_ADDR="$1"; TMUX_SOCKET="$2"; TMUX_TARGET="$3"; shift 3

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
          "$alive" || { makoctl dismiss -n "$NOTIF_ID" 2>/dev/null; break; }

          # Focus check: dismiss after ~10s of the user looking at the source pane
          pane_focused=false
          active_addr=$(hyprctl activewindow -j 2>/dev/null | jq -r ".address // empty" 2>/dev/null)
          if [[ -n "$TMUX_TARGET" && "$active_addr" == "$WINDOW_ADDR" ]]; then
            [[ "$(tmux -S "$TMUX_SOCKET" display-message -t "$TMUX_TARGET" \
              -p "#{pane_active}" 2>/dev/null)" == "1" ]] && pane_focused=true
          elif [[ -z "$TMUX_TARGET" && "$active_addr" == "$WINDOW_ADDR" ]]; then
            pane_focused=true
          fi
          if "$pane_focused"; then
            (( ++focused_count ))
            (( focused_count >= 1 )) && { makoctl dismiss -n "$NOTIF_ID" 2>/dev/null; break; }
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

  # Mobile: ntfy.sh delayed — only send if user hasn't seen the desktop notification
  # setsid detaches from hook's process group so Claude doesn't wait 90s
  setsid bash -c '
    sleep 90
    if makoctl list 2>/dev/null | grep -q "App name: Claude Code"; then
      curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
        -H "Title: $1" \
        -H "Priority: $2" \
        -d "$3" \
        ntfy.sh/jaeho
    fi
  ' _ "$TITLE" "$NTFY_PRIORITY" "${NTFY_BODY:-$BODY}" </dev/null &>/dev/null &
else
  "$HOME/.local/bin/notify" "$TITLE" "$BODY" &

  # Mobile: always send ntfy as fallback (OSC 99 passthrough may fail silently)
  setsid curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
    -H "Title: $TITLE" \
    -H "Priority: $NTFY_PRIORITY" \
    -d "${NTFY_BODY:-$BODY}" \
    ntfy.sh/jaeho </dev/null &>/dev/null &
fi

exit 0
