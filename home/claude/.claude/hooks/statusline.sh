#!/bin/sh
# Status line entry: write vim cursor shape first (fast), then the node bar.
# Claude Code spawns this with a pipe stdin and no controlling tty, so
# /dev/tty is ENXIO — walk parents for the session pts.
#   INSERT → bar (CSI 6 SP q), otherwise → block (CSI 2 SP q)

input=$(cat)

shape=
case $input in
  *'"mode":"INSERT"'*) shape='\033[6 q' ;;
  *'"vim":'*) shape='\033[2 q' ;;
esac

if [ -n "$shape" ]; then
  tty=
  # Subshell: `:` is a special builtin — a failed redirect on it can
  # kill the main shell.
  if ( : >/dev/tty ) 2>/dev/null; then
    tty=/dev/tty
  else
    p=$PPID
    i=0
    while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$i" -lt 12 ]; do
      for fd in 1 0 2; do
        t=$(readlink "/proc/$p/fd/$fd" 2>/dev/null) || continue
        case $t in
          /dev/pts/*|/dev/tty) tty=$t; break 2 ;;
        esac
      done
      p=$(sed -n 's/^.*) \([0-9]\{1,\}\) .*/\1/p' "/proc/$p/stat" 2>/dev/null)
      i=$((i + 1))
    done
  fi
  [ -n "$tty" ] && printf "$shape" >"$tty" 2>/dev/null
fi

printf '%s' "$input" | node /home/jaeho/.claude/hooks/statusline.js
