#!/bin/sh
# Status line entry: write vim cursor shape first (fast), then the node bar.
#   INSERT → bar (CSI 6 SP q), otherwise → block (CSI 2 SP q)
# Inside tmux write DECSCUSR to the client tty (kitty). The pane pts makes
# tmux treat the shape as application-owned and ignore cursor-style.

input=$(cat)

shape=
style=
case $input in
  *'"mode":"INSERT"'*) shape='\033[6 q' ; style=bar ;;
  *'"vim":'*) shape='\033[2 q' ; style=block ;;
esac

if [ -n "$style" ]; then
  if [ -n "$TMUX" ]; then
    tmux set -p -t "${TMUX_PANE:-}" cursor-style "$style" 2>/dev/null
    ct=$(tmux display -p -t "${TMUX_PANE:-}" '#{client_tty}' 2>/dev/null)
    [ -n "$ct" ] && printf "$shape" >"$ct" 2>/dev/null
  else
    printf "$shape" >/dev/tty 2>/dev/null
  fi
fi

printf '%s' "$input" | node /home/jaeho/.claude/hooks/statusline.js
