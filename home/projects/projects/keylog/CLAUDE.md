# keylog

README covers install and use. This file is agent rules only.

- **Text never leaves this machine.** Do not paste `keylog text` output,
  key names from a session, or any excerpt of `keys.db` into issues, PRs,
  chats, or other projects. Counts without text are fine to discuss.
- Capture source of truth for text is `virtual` (`keyd virtual keyboard`).
  Physical keyboards are best-effort under keyd's `EVIOCGRAB`; do not
  "fix" missing physical rows as a bug without `keylog doctor` evidence.
- Left-ctrl habit hits come from `caps-instead` → `leftctrl.jsonl`, not from
  the evdev stream (keyd `command()` swallows the key).
- State is `~/.local/state/keylog/`. Restic must keep excluding it
  (`home/restic/.config/restic/excludes` in dotfiles).
- Tasks and gotchas: GitHub issues (`gotcha`, `decision`), not TODO files.
