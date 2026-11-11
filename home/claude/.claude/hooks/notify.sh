#!/usr/bin/env bash
# Claude Code notifications.
#
# Hook mode (stdin JSON): Stop and Notification -> notify-send, with source
# window/tmux pane carried as hints.
# Focus mode (`notify.sh focus`, run by swaync on action): focus that source.
# Watch mode (`notify.sh watch ...`, started detached by hook mode): close
# one notification once its source is seen or gone.
#
# Click path is swaync's action script, not notify-send --action. That keeps
# notify-send fire-and-forget: no FIFO and no action waiter.
#
# Lifetime: skip entirely if the source pane is already focused at send time.
# A turn that ends in another tmux window of the focused kitty window rings
# that pane's tmux bell instead (an orange window number, no toast, no beep).
# The beep plays only when nothing says to stay quiet (quiet_reason).
# Otherwise the toast stays in the panel until the user focuses the source
# pane, the pane closes, or the user dismisses it. The watcher has no time
# cap: a toast left for hours must still close when its session is opened.
# Sends, skips and closes are logged to $LOG.

set -euo pipefail

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/claude-notify.log"

log() {
  printf '%s %s\n' "$(date +%FT%T)" "$*" >>"$LOG" 2>/dev/null || true
}

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

active_window() {
  hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null \
    || true
}

window_alive() {
  hyprctl clients -j 2>/dev/null \
    | jq -e --arg a "$1" '.[] | select(.address == $a)' >/dev/null 2>&1
}

# Prints gone, shown or hidden for a tmux pane id (%N). display-message
# exits 0 even when its target is missing (a missing %N prints empty
# fields; a missing session:window.pane silently means the current pane),
# so the printed id is the only proof the pane still exists.
pane_state() {
  local pane="$1" socket="${2:-}" out
  # shown also needs a client on the session: tmux answers a session no
  # client shows with another session's client, so kitty having focus says
  # nothing about it.
  out=$(tmux ${socket:+-S "$socket"} display-message -t "$pane" \
    -p '#{pane_id} #{window_active}#{pane_active}#{?session_attached,1,0}' \
    2>/dev/null) || { echo gone; return 0; }
  case "$out" in
    "$pane 111") echo shown ;;
    "$pane "*) echo hidden ;;
    *) echo gone ;;
  esac
}

# Unique bus name of the notification daemon. swaync restarts drop every
# toast and number new ones from 1 again, so a watcher must not close an
# id once the owner has changed.
notif_owner() {
  gdbus call --session --dest org.freedesktop.DBus \
    --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.GetNameOwner org.freedesktop.Notifications \
    2>/dev/null | tr -d "(),' " || true
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
  if [[ -n "$addr" ]] && window_alive "$addr"; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
  fi
  if [[ -n "$target" ]]; then
    # target is a pane id (%N), or session:window.pane on older toasts.
    # select-window resolves a pane id to the window holding it.
    tmux ${socket:+-S "$socket"} select-window -t "${target%.*}" 2>/dev/null || true
    tmux ${socket:+-S "$socket"} select-pane -t "$target" 2>/dev/null || true
  fi
  exit 0
fi

# ── Watch mode: close one notification once its source is seen or gone ──────
if [[ "${1:-}" == "watch" ]]; then
  id="$2" addr="$3" pane="$4" socket="$5" owner="$6"
  start=$SECONDS

  finish() {
    local reason="$1"
    if [[ "$(notif_owner)" == "$owner" ]]; then
      gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.CloseNotification \
        "$id" >/dev/null 2>&1 || true
      log "close id=$id pane=${pane:-none} reason=$reason after=$((SECONDS - start))s"
    else
      log "drop id=$id pane=${pane:-none} reason=daemon-restarted after=$((SECONDS - start))s"
    fi
    exit 0
  }

  checks=0
  while sleep 3; do
    if [[ -n "$pane" ]]; then
      state=$(pane_state "$pane" "$socket")
      [[ "$state" == gone ]] && finish pane-gone
      [[ "$state" == shown && "$(active_window)" == "$addr" ]] && finish focused
    else
      window_alive "$addr" || finish window-gone
      [[ "$(active_window)" == "$addr" ]] && finish focused
    fi
    (( ++checks % 20 )) || [[ "$(notif_owner)" == "$owner" ]] \
      || finish daemon-restarted
  done
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

# Why to stay quiet now, or nothing. swaync already hides the popup under Do
# Not Disturb or an inhibitor; the beep is ours, so it has to ask too. An open
# capture stream is a call or a steno recording: no beep into it, and no reply
# text on a screen that may be shared. Each check gives up after a second:
# swaync-client waits forever for a daemon that is not on the bus (-sw stops
# that) or for a bus that is not there (only timeout stops that).
quiet_reason() {
  if [[ -n "$(timeout 1 pactl list short source-outputs 2>/dev/null)" ]]; then
    echo mic
  elif [[ "$(timeout 1 swaync-client -sw -D 2>/dev/null)" == "true" ]]; then
    echo dnd
  elif [[ "$(timeout 1 swaync-client -sw -I 2>/dev/null)" == "true" ]]; then
    echo inhibited
  elif away; then
    echo away
  else
    return 1
  fi
}

# ActivityWatch's AFK watcher says afk, and said so in the last two minutes.
# A stopped watcher or server counts as present, so the beep fails on.
away() {
  curl -s -m 1 "http://127.0.0.1:5600/api/0/buckets/aw-watcher-afk_$(uname -n)/events?limit=1" 2>/dev/null \
    | jq -e --argjson now "$(date +%s)" '.[0]
        | .data.status == "afk"
          and (.timestamp | sub("\\.[0-9]+"; "") | fromdateiso8601) + .duration > $now - 120' \
      >/dev/null 2>&1
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
    # idle_prompt is intentionally not handled: Stop already notified with the
    # assistant message when the turn ended; "waiting for input" is just a
    # later nudge with no content.
    case "$TYPE" in
      permission_prompt)
        TITLE="Permission needed"
        BODY="${MSG:-Claude needs your approval.}"
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
  active_window
}

# True when the user is already looking at the source window and tmux pane.
# Skip the notification then: the TUI already shows the result. Anything
# that fires while they are elsewhere still lands and stays in the panel.
source_focused() {
  local addr="${1:-}" pane="${2:-}" socket="${3:-}"
  [[ -n "$addr" && "$(active_window)" == "$addr" ]] || return 1
  [[ -z "$pane" || "$(pane_state "$pane" "$socket")" == shown ]]
}

# The source's kitty window has focus but tmux shows another window: ring the
# pane's bell instead of a toast. tmux flags that window, .tmux.conf's
# window-status-format draws the flag as an orange index, and tmux clears it
# when you go there; kitty has enable_audio_bell no, so it makes no sound. A
# pane in the window you are on is already on screen, and tmux flags nothing
# for it. A session no client shows gets a toast instead: nobody would see it.
ring_source_window() {
  local addr="${1:-}" target="${2:-}" socket="${3:-}" tty
  [[ -n "$addr" && -n "$target" ]] || return 1
  [[ "$(active_window)" == "$addr" ]] || return 1
  tty=$(tmux ${socket:+-S "$socket"} display-message -t "$target" \
    -p '#{?session_attached,#{pane_tty},}' 2>/dev/null) || return 1
  [[ -c "$tty" && -w "$tty" ]] || return 1
  printf '\a' >"$tty"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
# Desktop: notify-send when a live Hyprland is reachable; OSC 99 otherwise
# (a remote host such as wonlab has none). SSH_CONNECTION is not a signal:
# a pane or claude started while tmux was attached over ssh keeps it for
# life, and every notification from it then went out as a kitty OSC 99 toast
# with no source hint and no focus action.
_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  for _sock in "$_runtime"/wayland-*; do
    [[ -S "$_sock" ]] && { export WAYLAND_DISPLAY="${_sock##*/}"; break; }
  done
fi

if recover_hypr; then
  WINDOW_ADDR=$(resolve_window_address) || true
  TMUX_SOCKET="${TMUX:-}"
  TMUX_SOCKET="${TMUX_SOCKET%%,*}"
  # The pane id (%N), never session:window.pane: renumber-windows shifts
  # indexes when a window closes, so an index target ends up naming
  # another window or, once missing, the current pane.
  TMUX_TARGET=""
  if [[ "${TMUX_PANE:-}" == %* \
        && "$(pane_state "$TMUX_PANE" "$TMUX_SOCKET")" != gone ]]; then
    TMUX_TARGET="$TMUX_PANE"
  fi

  # Already on the source pane: no toast, no sound, no panel entry.
  if source_focused "${WINDOW_ADDR:-}" "$TMUX_TARGET" "$TMUX_SOCKET"; then
    log "skip event=$EVENT pane=${TMUX_TARGET:-none} reason=focused"
    exit 0
  fi
  # A finished turn in another tmux window of this kitty: the status line says
  # it. A permission prompt or question stops Claude until answered: it toasts.
  if [[ "$EVENT" == Stop ]] \
      && ring_source_window "${WINDOW_ADDR:-}" "$TMUX_TARGET" "$TMUX_SOCKET"; then
    log "bell event=$EVENT pane=$TMUX_TARGET"
    exit 0
  fi

  QUIET=$(quiet_reason) || QUIET=""
  case "$QUIET" in
    "") play_sound ;;
    mic) BODY="Open the session to read it." ;;
  esac
  [[ -n "$QUIET" ]] && log "quiet event=$EVENT reason=$QUIET"

  # -t 0 is NOT "never expire" in swaync: expire_timeout 0 falls back to the
  # daemon's `timeout` (5s). That only hides the popup; the control center
  # keeps the entry. 12s gives the toast time to be clicked.
  NOTIF_ID=$(notify-send --print-id \
    --app-name="Claude Code" \
    -u "${URGENCY:-normal}" \
    -t 12000 \
    ${WINDOW_ADDR:+-h "string:claude-window:$WINDOW_ADDR"} \
    ${TMUX_SOCKET:+-h "string:claude-tmux-socket:$TMUX_SOCKET"} \
    ${TMUX_TARGET:+-h "string:claude-tmux:$TMUX_TARGET"} \
    "$TITLE" "$BODY" 2>/dev/null) || true
  OWNER=$(notif_owner)

  # Close it from the panel once the user goes to the source, or it dies.
  # Without a window address there is nothing to watch for.
  if [[ -n "${NOTIF_ID:-}" && -n "${WINDOW_ADDR:-}" && -n "$OWNER" ]]; then
    setsid "${BASH_SOURCE[0]}" watch "$NOTIF_ID" "$WINDOW_ADDR" \
      "$TMUX_TARGET" "$TMUX_SOCKET" "$OWNER" </dev/null &>/dev/null &
    log "send id=$NOTIF_ID event=$EVENT pane=${TMUX_TARGET:-none} addr=$WINDOW_ADDR"
  else
    log "send id=${NOTIF_ID:-none} event=$EVENT pane=${TMUX_TARGET:-none} unwatched addr=${WINDOW_ADDR:-none} owner=${OWNER:-none}"
  fi
else
  # SSH/remote: kitty OSC 99 desktop notification. Clicking focuses the kitty
  # window; we deliberately do NOT auto-switch tmux. The only available trigger
  # would be a global client-focus-in hook, but that fires on any unrelated
  # refocus (not just the notification click) and can yank a different session.
  "$HOME/.local/bin/notify" "$TITLE" "$BODY" &
fi

exit 0
