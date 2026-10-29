---
name: drawy
description: Reads, renders, checks and edits Drawy (KDE whiteboard) .drawy boards through the drawyctl CLI. Use when a task touches a .drawy file, such as looking at a board, cleaning up or rearranging it, adding text or images, or checking a layout for overlaps.
---

# Drawy boards with drawyctl

`drawyctl --help` and `drawyctl COMMAND --help` list the commands; arguments are `FILE` first, then `SEL`. This file holds what help cannot tell you.

## Loop

- Start with `drawyctl dump FILE` and `drawyctl check FILE`. Rects are canvas coordinates as Drawy computes them. Text width comes from the Fuzzy Bubbles font, so read it from `dump`, never estimate it: an 18pt URL is about 630px wide.
- Plan with numbers from `dump`, edit, then run `check` (no overlaps unless intended) and `render`, and Read the PNG before telling the user the board looks right. `arrange` lays siblings out from measured rects.
- Write to a copy in the scratchpad with `-o` until the user approves; use `--in-place` only on their go-ahead.

## The user's open board

- Drawy never reloads a file, and its save overwrites the file. Before writing a board the user may have open, ask them to save in Drawy first. After writing, relay drawyctl's note: reopen by path (File > Open or `drawy FILE`), because a plain launch restores Drawy's older autosave under the board's name and saving that overwrites the edit.
- Every replaced file is backed up in `~/.cache/drawyctl/backups/`.
- Check results with `drawyctl render`, not by launching `/usr/bin/drawy`. If a real-app load is ever needed, run it with scratch XDG dirs, offscreen Qt and a dead D-Bus address, so it cannot touch drawyrc or the autosave.

## When the renderer will not build

- drawy-render compiles against `~/projects/upstream/drawy` at the installed Drawy version's tag, because the packaged DrawyCore headers are incomplete. After a Drawy upgrade drawyctl refuses and prints the fetch and checkout commands; run them, then `drawyctl build` and `drawyctl selftest`.
- Do not get past a build failure with `--no-verify` or `--no-render`: they skip the check that a write keeps every item.

## Raw edits

- For anything the commands do not cover, `unpack` to JSON, edit, and `pack`. Read [format.md](format.md) first: the schema, the coordinate model, and what Drawy's loader drops without a word.
