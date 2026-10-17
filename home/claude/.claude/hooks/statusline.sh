#!/bin/sh
# Status line entry: the node usage bar only.
# Cursor shape is the terminal default (kitty beam) — see CLAUDE_CODE_NATIVE_CURSOR.

input=$(cat)
printf '%s' "$input" | node /home/jaeho/.claude/hooks/statusline.js
