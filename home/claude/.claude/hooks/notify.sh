#!/usr/bin/env bash
# Claude Code notifications.
#
# Hook mode (stdin JSON): Stop and Notification -> notify-send, with source
# window/tmux pane carried as hints.
# Focus mode (`notify.sh focus`, run by swaync on action): focus that source.
#
# Click path is swaync's action script, not notify-send --action. That keeps
# notify-send fire-and-forget: no FIFO, no waiter, no CloseNotification
# watcher wiping panel history. Expired popups stay in the control center.

set -euo pipefail

# ── Live Hyprland instance ────────────────────────────────────────────────────
# tmux only refreshes env on client attach, so a pane created before the
# graphical session (or restored by tmux-resurrect) can carry an empty or
# stale HYPRLAND_INSTANCE_SIGNATURE. A stale value points at a dead
# .socket.sock from a previous compositor run; hyprctl then fails and focus
# goes nowhere. Pick a live instance from XDG_RUNTIME_DIR instead.
hypr_ok() {
  hyprctl monitors -j >/dev/null 2>&1
}

recover_hypr() {
  hypr_ok && return 0
  local _runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" _d
  [[ -d "$_runtime/hypr" ]] || return 1
  for _d in "$_runtime"/hypr/*/; do
    [[ -d "$_d" ]] || continue
    export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$_d")"
    hypr_ok && return 0
  done
  return 1
}

# swaync exports hints via GLib Variant.print, so strings arrive single-quoted.
unquote() {
  local v="${1:-}"
  v="${v#\'}"
  v="${v%\'}"
  v="${v#\"}"
  v="${v%\"}"
  printf '%s' "$v"
}

# ── Focus mode: swaync script on notification action ──────────────────────────
if [[ "${1:-}" == "focus" ]]; then
  addr=$(unquote "${SWAYNC_HINT_CLAUDE_WINDOW:-}")
  socket=$(unquote "${SWAYNC_HINT_CLAUDE_TMUX_SOCKET:-}")
  target=$(unquote "${SWAYNC_HINT_CLAUDE_TMUX:-}")

  recover_hypr || true
  if [[ -n "$addr" ]] && hyprctl clients -j 2>/dev/null \
       | jq -e --arg a "$addr" ".[] | select(.address == \$a)" >/dev/null 2>&1; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
  fi
  if [[ -n "$target" ]]; then
    tmux ${socket:+-S "$socket"} select-window -t "${target%.*}" 2>/dev/null || true
    tmux ${socket:+-S "$socket"} select-pane -t "$target" 2>/dev/null || true
  fi
  exit 0
fi

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
    HOOK_TITLE=$(echo "$INPUT" | jq -r '.title // empty')

    # Actionable types only. Quota, computer-use, and plugin chatter stay out.
    case "$TYPE" in
      permission_prompt)
        TITLE="Permission needed"
        BODY="${MSG:-Claude needs your approval.}"
        URGENCY="normal"
        ;;
      idle_prompt)
        TITLE="${HOOK_TITLE:-Claude}"
        BODY="${MSG:-Claude is waiting for your input.}"
        URGENCY="normal"
        ;;
      worker_permission_prompt|agent_needs_input|elicitation_dialog|elicitation_url_dialog)
        TITLE="${HOOK_TITLE:-Claude}"
        BODY="${MSG:-$TYPE}"
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

# True when the user is already looking at the source window and tmux pane.
# Skip the notification then: the TUI already shows the result. Anything
# that fires while they are elsewhere still lands and stays in the panel.
source_focused() {
  local addr="${1:-}" target="${2:-}" socket="${3:-}"
  [[ -n "$addr" ]] || return 1

  local active
  active=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null) || return 1
  [[ "$active" == "$addr" ]] || return 1

  if [[ -n "$target" ]]; then
    # #{pane_active} alone is per-window; require the pane to be the one shown.
    [[ "$(tmux ${socket:+-S "$socket"} display-message -t "$target" \
      -p '#{window_active}:#{pane_active}' 2>/dev/null)" == "1:1" ]] || return 1
  fi
  return 0
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
# Desktop: notify-send on local Wayland; OSC 99 for SSH/remote.
if [[ -z "${SSH_CONNECTION:-}" ]]; then
  _runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    for _sock in "$_runtime"/wayland-*; do
      [[ -S "$_sock" ]] && { export WAYLAND_DISPLAY="${_sock##*/}"; break; }
    done
  fi
  recover_hypr || true
fi

if [[ -z "${SSH_CONNECTION:-}" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  WINDOW_ADDR=$(resolve_window_address) || true
  TMUX_SOCKET="${TMUX:-}"
  TMUX_SOCKET="${TMUX_SOCKET%%,*}"
  TMUX_TARGET=""
  if [[ -n "${TMUX_PANE:-}" ]]; then
    TMUX_TARGET=$(tmux display-message -t "$TMUX_PANE" \
      -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null) || true
  fi

  # Already on the source pane: no toast, no sound, no panel entry.
  source_focused "${WINDOW_ADDR:-}" "${TMUX_TARGET:-}" "${TMUX_SOCKET:-}" && exit 0

  play_sound

  # -t 0 is NOT "never expire" in swaync: expire_timeout 0 falls back to the
  # daemon's `timeout` (5s). That only hides the popup; the control center
  # keeps the entry. 12s gives the toast time to be clicked.
  notify-send \
    --app-name="Claude Code" \
    -u "${URGENCY:-normal}" \
    -t 12000 \
    ${WINDOW_ADDR:+-h "string:claude-window:$WINDOW_ADDR"} \
    ${TMUX_SOCKET:+-h "string:claude-tmux-socket:$TMUX_SOCKET"} \
    ${TMUX_TARGET:+-h "string:claude-tmux:$TMUX_TARGET"} \
    "$TITLE" "$BODY" </dev/null &>/dev/null &
else
  # SSH/remote: kitty OSC 99 desktop notification. Clicking focuses the kitty
  # window; we deliberately do NOT auto-switch tmux. The only available trigger
  # would be a global client-focus-in hook, but that fires on any unrelated
  # refocus (not just the notification click) and can yank a different session.
  "$HOME/.local/bin/notify" "$TITLE" "$BODY" &
fi

exit 0
