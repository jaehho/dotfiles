---
name: easel
description: Reads, renders, checks and edits Easel reference boards (folders ending in .easel) through the easel CLI, live in the open window when there is one. Use when a task touches a .easel board, such as laying out references, adding images or notes, framing columns, checking for overlaps, or moving a Drawy board into Easel.
---

# Easel boards

`easel --help` and `easel COMMAND --help` list the commands; the README in `~/projects/easel` has the op reference. This file holds what help does not say.

- **Look before and after.** `easel dump BOARD` gives every item's absolute rect; `easel check BOARD` lists overlaps and items outside their frame; `easel render BOARD -o FILE.png` draws it with no window. Read the PNG before saying a layout looks right. Text sizes come from the renderer, so take widths from `dump`, never estimate them.
- **Edits are live when the window has the board.** `dump` says `(live)` then, and each command lands in the window as one undo step the user can take back with Ctrl+Z (`easel undo BOARD` does the same). Without a window, edits go to the bundle. Either way, no copy is needed for the user to recover a change, but say what you changed.
- **Do a layout as one batch.** Write the ops to a JSON file and run `easel apply BOARD ops.json --label "..."`: it applies whole or not at all, and is one undo step. Name items by id prefix, `text:WORDS` or `title:WORDS`.
- **Frames hold columns.** `easel frame BOARD ITEMS... --title T` puts a frame around items; `stack ... --column --fit` lays its contents out and refits it; `stack` on the frames with `--row --gap 40` lines the columns up.
- **Don't edit `board.json` by hand while the window has the board.** The window takes outside changes as an undoable step, but the CLI keeps ids, sizes and frames consistent and a hand edit may not.
- **From Drawy:** `easel import-drawy FILE.drawy NAME` makes `NAME.easel`; groups become frames titled by their text. It reports what it could not carry over (shapes, arrows, freehand).
