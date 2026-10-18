# aw-watchers

Rust **sensors** for ActivityWatch. Buckets only; no reporting UI.

- **Claude watcher reads `~/.claude/projects/**/*.jsonl`.** Never store prompt or message bodies in AW events. Skip `subagents/` trees (parent session already has Agent tool use).
- **Terminal watcher does not change tmux titles.** User wants `#S:#W` short. cwd comes from kitty remote control + `tmux list-panes`, not from title strings.
- **No consumer CLI here.** Stock AW (`aw` / webui / `queries/*.awql`) does rollups. Project tags and blocks are `asst track` in ~/projects/asst.
- **Integration is in dotfiles** (`home/aw-watchers/`, `scripts/converge.sh`, kitty.conf). This repo owns implementation and `make install`.
- Tests cover JSONL parsing, segmentation, partial lines, and checkpointing; add a fixture when a new record type shows up in the wild.
