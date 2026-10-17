#!/bin/sh
# Status line entry: the node usage bar only.
# Cursor shape is set exclusively by the tmux root-table binds on i/Esc
# (see ~/.tmux.conf). Writing DECSCUSR here raced those binds — a stale
# vim.mode after the key flipped the shape back and flickered.

input=$(cat)
printf '%s' "$input" | node /home/jaeho/.claude/hooks/statusline.js
