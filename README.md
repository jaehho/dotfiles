# Dotfiles

Configs and root files for Arch + Hyprland and Ubuntu/Debian. Stow for
`~`, a small apply script for `/etc`. You run upgrades and apply when you
want; nothing runs on a timer.

## Layout

```
home/       stow packages -> ~ (fish, hypr, nvim, kitty, …)
system/     root-owned files -> /etc (grub, PAM, udev, NM, keyd, …)
packages/   bootstrap.txt: portable tools for a new machine
scripts/    apply, bootstrap, claude-reconcile, server
hosts/      per-host choices (stow drops, no-aaaa)
```

## Day to day

```bash
stow -d home -t ~ <pkg>       # one package, after adding a file to it
scripts/apply.sh              # all stow packages + user units
sudo scripts/apply.sh system  # /etc + boot copies, after editing system/
```

Linked files are already live: edit `home/...` or `system/...` and the
running tool sees it. Stow and apply pick up new files and replace lost
links. Root copies cannot be symlinks into `/home`; apply installs those
and rebuilds grub/initramfs when they change. Guide: `docs/config-drift.html`.

## New machine

```bash
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
sudo ~/dotfiles/scripts/bootstrap.sh
```

Installs `packages/bootstrap.txt`, asks the per-host questions, applies
configs. Hyprland and the desktop stack are commented in that file; uncomment
them on a laptop.

## Claude

Plugin/skill/MCP state can be kept declarative under
`home/claude/.claude/reconcile/`; run `scripts/claude-reconcile.sh` (see
`--help`) when that set changes. It is not part of apply.

## Server (wonlab)

```bash
scripts/server.sh             # or from the laptop: ssh wonlab '~/dotfiles/scripts/server.sh'
```

Stows the server set (fish, git, tmux, nvim, claude, theme, bin). Nothing
runs on a timer there either. `home/laptop` stays off the server. Provider
keys for `claude-open` (`~/.config/{zai,mimo,openrouter}.env`) are never
synced; copy them by hand.

## Troubleshooting

Known traps are GitHub issues labeled [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha).
Design choices are `decision` issues. Search both before changing broken
behavior.
