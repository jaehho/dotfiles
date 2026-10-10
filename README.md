# Dotfiles

Config files for my machines. Stow for `~`, a short recipe for `/etc`. No
timers, no package list, no wrapper commands.

## Layout

```
home/     stow packages (fish, hypr, nvim, kitty, …)
system/   root files and the commands to install them (see system/README.md)
docs/     color taste, config-drift guide, writing rules for CLAUDE.md
```

## Day to day

Linked files are already live. Edit under `home/` or `system/` and the
running tool sees the change. After you **add** a file to a stow package:

```sh
stow --no-folding -d home -t ~ <pkg>
```

After you edit something under `system/`, run the matching commands in
`system/README.md` (links or copies; grub/initramfs rebuild when those
change). Guide to what drifts and why: `docs/config-drift.html`.

## New machine

```sh
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --no-folding -d home -t ~ <pkgs>
sudo sh system/README.md   # read it first; it is a list of commands, not a script
```

Install tools with the distro package manager. I do not track them here.
On a Hyprland laptop that means the usual stack (hyprland, waybar, rofi,
kitty, …) plus whatever I installed on the old machine
(`pacman -Qqe` / `apt-mark showmanual` is the inventory).

A few stow packages have one-off notes:

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
servers in `~/.claude` by hand (or with `/plugin`, `/mcp`); this repo does
not reconcile them.

## Troubleshooting

Known traps are GitHub issues labeled [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha).
Design choices are [`decision`](https://github.com/jaehho/dotfiles/issues?q=label%3Adecision).
