# Dotfiles

Stow packages under `home/`. Nothing else. No timers, no package list,
no `/etc` installer, no wrapper commands.

## Layout

```
home/   stow packages (fish, hypr, nvim, kitty, …)
docs/   color taste, config-drift guide, writing rules for CLAUDE.md
```

## Day to day

Linked files are already live. Edit under `home/` and the running tool
sees the change. After you **add** a file to a stow package:

```sh
stow --no-folding -d home -t ~ <pkg>
```

## New machine

```sh
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --no-folding -d home -t ~ <pkgs>
```

Install tools with the distro package manager. I do not track them here
(`pacman -Qqe` / `apt-mark showmanual` on the old machine is the inventory).

One-offs inside packages:

- `mime` — `mimeapps.list` is an absolute symlink (GLib safe-write).
- `tmux` — TPM and catppuccin/tmux are git clones under `~/.tmux` and
  `~/.config/tmux/plugins`.
- `theme` — run `bat cache --build` after it lands.
- `hypr` — user units (wallhelper-fetch, swayosd, awatcher, …) are
  `systemctl --user enable --now` the first time.
- `laptop` — desktop helpers; keep this package off servers.

## Server (wonlab)

```sh
ssh wonlab
cd ~/dotfiles && git pull
stow --no-folding -d home -t ~ fish git tmux nvim claude theme bin
```

`home/laptop` stays off the server. Provider keys for `claude-open`
(`~/.config/{zai,mimo,openrouter}.env`) are never in the repo.

## Claude

`home/claude/` stows settings, hooks, and skills. Manage plugins and MCP
servers in `~/.claude` by hand (or with `/plugin`, `/mcp`).

## Machine /etc tweaks

Not in this repo. They live in git history and the `gotcha` issues
(keyd, DNS/resolved, nvidia, lid, udev wake). Rebuild them on a new
machine from those.

## Troubleshooting

Known traps are GitHub issues labeled [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha).
Design choices are [`decision`](https://github.com/jaehho/dotfiles/issues?q=label%3Adecision).
