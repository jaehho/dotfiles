# Dotfiles

Configs and root files for Arch + Hyprland and Ubuntu/Debian. Stow for
`~`, a small apply script for `/etc`. You run upgrades and apply when you
want; nothing runs on a timer.

## Layout

```
home/       stow packages -> ~ (fish, hypr, nvim, kitty, …)
system/     root-owned files -> /etc (grub, PAM, udev, NM, keyd, …)
packages/   bootstrap.txt is the bare necessities; the rest is inventory
scripts/    apply, status, bootstrap, claude-reconcile, server
hosts/      per-host choices (stow drops, no-aaaa)
```

## Day to day

```bash
dotfiles              # status: what would apply change?
dotfiles apply        # stow + user units (after adding a file under home/)
sudo scripts/apply.sh system   # /etc + boot copies (after editing system/)
paru -Syu             # packages are yours
```

Linked files are already live: edit `home/...` or `system/...` and the
running tool sees it. `apply` picks up new files, replaces lost links, and
installs the root-owned copies that cannot be symlinks into `/home`
(boot, PAM, udev, sandboxed readers). Guide: `docs/config-drift.html`.

## New machine

```bash
git clone https://github.com/jaehho/dotfiles.git ~/dotfiles
sudo ~/dotfiles/scripts/bootstrap.sh
```

Installs `packages/bootstrap.txt`, asks the per-host questions, applies
configs. After that, install the rest with `paru` as you need it.

## Claude

Plugin/skill/MCP state is declarative under `home/claude/.claude/reconcile/`.
Run `scripts/claude-reconcile.sh` (see `--help`) when that set changes.
It is not part of `apply`.

## Server (wonlab)

```bash
dotfiles server          # from the laptop; or: dotfiles server HOST
```

SSHes in, clones or fast-forwards `~/dotfiles` from GitHub, and runs
`scripts/server.sh`: stow for the server set (fish, git, tmux, nvim, claude,
theme, bin). Nothing runs on a timer and nothing runs as root there either.
`home/laptop` stays off the server. Provider keys for `claude-open`
(`~/.config/{zai,mimo,openrouter}.env`) are never synced; copy them by hand.

## Troubleshooting

Known traps are GitHub issues labeled [`gotcha`](https://github.com/jaehho/dotfiles/issues?q=label%3Agotcha).
Design choices are `decision` issues. Search both before changing broken
behavior.
