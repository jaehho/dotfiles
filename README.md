# Dotfiles

Stow packages under `home/`. Nothing else. No timers, no package list,
no `/etc` installer, no wrapper commands.

## Layout

```
home/   stow packages (fish, hypr, nvim, kitty, …)
docs/   writing rules for CLAUDE.md, Catppuccin apply notes, history/
```

## Packages by machine

| Stowed | Packages |
|---|---|
| Laptop and wonlab | `bin` `claude` `fish` `git` `nvim` `theme` `tmux` |
| wonlab only | `server` |
| Laptop only | `audio` `codex` `hypr` `kitty` `laptop` `marimo` `mime` `restic` `rofi` `ssh` `sshfs` `sunshine` `swaync` `tailscale` `tridactyl` `visidata` `waybar` `zathura` |

`laptop` is desktop helpers; keep it off servers.

## Day to day

Linked files are already live. Edit under `home/` and the running tool
sees the change.

All commands run from `~/dotfiles`. `$P` below is a package name, or
`$(ls home)` for all of them.

| Task | Command |
|---|---|
| Preview (nothing changes; the "simulation mode" warning is normal) | `stow --no-folding -n -v -d home -t ~ $P` |
| Link a new file, or relink everything | `stow --no-folding -d home -t ~ $P` |
| Drop links whose source file was deleted | `stow --no-folding -R -d home -t ~ $P` |
| Move a live file into the repo | `mv ~/.config/x/y home/$P/.config/x/y`, then link the package |

Do not use `stow --adopt` for the last one: it overwrites the repo copy
with the live file.

## New machine

```sh
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --no-folding -d home -t ~ <pkgs>
```

Install tools with the distro package manager. They are not tracked
here (`pacman -Qqe` / `apt-mark showmanual` on the old machine is the
inventory).

One-offs inside packages:

- `mime` — `mimeapps.list` is an absolute symlink (GLib safe-write).
- `tmux` — TPM and catppuccin/tmux are git clones under `~/.tmux` and
  `~/.config/tmux/plugins`.
- `theme` — run `bat cache --build` after it lands.
- `hypr` — user units (wallhelper-fetch, swayosd, awatcher, …) are
  `systemctl --user enable --now` the first time.
- `ssh` — `~/.ssh/jump_pass` is a real file, not in the repo
  (`chmod 600`); the config comment says how to create it.

## Server (wonlab)

```sh
ssh wonlab
cd ~/dotfiles && git pull
stow --no-folding -d home -t ~ bin claude fish git nvim server theme tmux
```

Provider keys for `claude-open` (`~/.config/{zai,mimo,openrouter}.env`)
are never in the repo.

## Claude

`home/claude/` stows settings, hooks, and `CLAUDE.md`. The package's
ignore list leaves `~/.claude/skills` to the plugin system, so each
skill in `home/claude/.claude/skills/` is linked by hand:

```sh
ln -s ~/dotfiles/home/claude/.claude/skills/<name> ~/.claude/skills/<name>
```

Manage plugins and MCP servers in `~/.claude` with `/plugin` and `/mcp`.

## Machine /etc tweaks

Not in this repo. `etckeeper` versions `/etc` on the machine
(`sudo etckeeper vcs status`). Changes older than that live in git
history and the `gotcha` issues (keyd, DNS/resolved, nvidia, lid, udev
wake).

## Troubleshooting

Known traps are GitHub issues labeled [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha).
Design choices are [`decision`](https://github.com/jaehho/dotfiles/issues?q=label%3Adecision).
