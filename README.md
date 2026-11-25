# Dotfiles

Git tracking for the dotfiles of one machine (Arch, Hyprland), part of
which wonlab, the home server, uses too. Stow packages under `home/`;
nothing else. No timers, no package list, no `/etc` installer, no
wrapper commands besides `dotfiles-pull`.

## Layout

```
home/   stow packages (fish, hypr, nvim, kitty, …)
docs/   writing rules for CLAUDE.md, GUI app colors, history/
```

## Day to day

Linked files are already live. Edit under `home/` and the running tool
sees the change.

All commands run from `~/dotfiles`. `$P` below is a package name, or
`$(ls home | grep -vx wonlab)` for all of them.

| Task | Command |
|---|---|
| Preview (nothing changes; the "simulation mode" warning is normal) | `stow --no-folding -n -v -d home -t ~ $P` |
| Link a new file, or relink everything | `stow --no-folding -d home -t ~ $P` |
| Drop links whose source file was deleted | `stow --no-folding -R -d home -t ~ $P` |
| Move a live file into the repo | `mv ~/.config/x/y home/$P/.config/x/y`, then link the package |

Do not use `stow --adopt` for the last one: it overwrites the repo copy
with the live file.

## Restore after a reinstall

```sh
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --no-folding -d home -t ~ $(ls home | grep -vx wonlab)
```

Install tools with `pacman`. They are not tracked here (`pacman -Qqe` is
the inventory).

One-offs inside packages:

- `mime` — `mimeapps.list` is an absolute symlink (GLib safe-write).
- `bash` — the login shell: `chsh -s /usr/bin/bash`. Its
  `.bash_profile` starts Hyprland on tty1; fish runs inside tmux.
- `tmux` — TPM is a git clone under `~/.tmux`.
- `theme` — run `bat cache --build` after it lands.
- `hypr` — user units (wallhelper-fetch, awatcher, …) are
  `systemctl --user enable --now` the first time.
- `ssh` — `~/.ssh/jump_pass` is a real file, not in the repo
  (`chmod 600`); the config comment says how to create it.

## wonlab

wonlab, the home server, stows part of this repo so tmux, nvim, fish and Claude Code work the same over ssh (#95). Edit on either machine, commit and push. The `wonlab` package is its alone: never stow it on the laptop. To set it up:

```sh
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --no-folding --ignore='btop\.conf' -d home -t ~ tmux nvim fish git theme agents claude wonlab
```

On both machines, the first interactive fish of each day runs `dotfiles-pull` in the background: it fast-forwards, restows the machine's packages (wonlab's list and ignores are in `home/wonlab/.config/fish/conf.d/wonlab.fish`; the laptop's default is every package but `wonlab`), and runs `Lazy! restore` when the lockfile changed. If both machines committed since the last pull, the pull fails and every shell says so until `git pull --rebase` fixes it. Ubuntu has no `delta` or `bat` without sudo, so their release binaries are in `~/.local/bin`, with `fd` linking `fdfind`.

## Agents (Claude Code, Codex, Antigravity)

`home/agents/` stows the shared global instructions (`~/.agents/AGENTS.md`) and skills (`~/.agents/skills/`). `home/claude/`, `home/codex/`, and `home/antigravity/` link each tool's global instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/config/AGENTS.md`) and each skill (`~/.claude/skills/<name>`, `~/.gemini/config/skills/<name>`) back to `home/agents/skills/<name>`, as directory symlinks (Codex ignores a symlinked `SKILL.md`, so the real folders are stow-ignored), keeping per-tool settings, hooks, and MCP configs in their own packages. Machine-local/private notes stay untracked in `~/.agents/AGENTS.local.md`.

Manage plugins and MCP servers in `~/.claude` with `/plugin` and `/mcp`.

## Machine /etc tweaks

Not in this repo. `etckeeper` versions `/etc` on the machine
(`sudo etckeeper vcs status`). Changes older than that live in git
history and the `gotcha` issues (keyd, DNS/resolved, nvidia, lid, udev
wake).

## Troubleshooting

Known traps are GitHub issues labeled [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha).
Design choices are [`decision`](https://github.com/jaehho/dotfiles/issues?q=label%3Adecision).
