# Product

<!-- impeccable:product-schema 1 -->

## Platform

Not applicable: a Linux machine-configuration repo (Arch + Hyprland primary,
Ubuntu/Debian supported), driven by shell scripts and GNU Stow. No web or
mobile surface.

## Users

One owner, across their own machines. They run setup commands themselves.

## Product Purpose

Keep each machine's configs matching the repo when the owner asks: stow
linked, `/etc` and boot configs installed. Success is a machine the owner
can reason about, with the wheel on upgrades and on when anything lands.

## Operating Context

- The repo often carries uncommitted work; stowed files are symlinks, so
  edits are live.
- Claude Code in `~/dotfiles` is the usual way changes get made.
- Notifications via swaync; terminal is kitty; shell is fish.
- GitHub issues labeled `gotcha` hold recurring traps.

## Capabilities and Constraints

- Arch and Ubuntu both stay first-class.
- Engine stays GNU Stow plus shell scripts. Ansible, Nix and chezmoi were
  considered and rejected (2026-09-13): speed and opaque output outweigh
  deleted code.
- No timers and no unattended upgrades. `packages/bootstrap.txt` is a
  shopping list for a new machine, not a drift police.
- Root filesystem is ext4 with no snapshots: a boot-config change rolls
  back through what `apply.sh` keeps under `/var/lib/dotfiles/backup`.

## Product Principles

- The owner runs it. Nothing applies itself.
- Stay close to distro defaults; remove layers before adding them.
- Less homemade machinery: each script earns its place.
- Quiet when fine, specific when not.
