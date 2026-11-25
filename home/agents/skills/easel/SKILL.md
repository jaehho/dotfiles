---
name: easel
description: Reads, renders, checks and edits Easel reference boards (folders ending in .easel) through the easel CLI, live in the open window when there is one. Use when a task touches a .easel board, such as laying out references, adding images or notes, framing columns, or checking overlaps.
---

# Easel boards

Read the Use section of `~/projects/easel/README.md` first: item names, live edits and the `apply` ops are there, and `easel COMMAND --help` has the flags. Beyond them:

- Take sizes from `easel dump`: the renderer measures text, so never estimate a width. After a layout change, run `check`, then `render`, and Read the PNG before saying the layout looks right.
- Make a layout one `easel apply BOARD ops.json --label "..."`, so the user takes it back with one Ctrl+Z. Say what you changed.
- Change a board through the CLI, not by editing `board.json`: the CLI keeps ids, sizes and frames consistent.
