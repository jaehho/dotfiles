# Product

<!-- impeccable:product-schema 1 -->

## Platform

Not applicable: a Linux machine-configuration repo (Arch + Hyprland primary, Ubuntu/Debian supported), driven by shell scripts and systemd. No web or mobile surface.

## Users

One owner, across their own machines. They rarely run setup commands themselves; historically `make sync` ran only when Claude told them to.

## Product Purpose

Keep each machine matching the repo: dotfiles linked, `/etc` and boot configs installed, manifest packages present, services enabled. Success is a machine that converges with nobody watching, and an owner who hears about it only when a decision is theirs.

## Operating Context

- The repo always carries uncommitted work; stowed files are symlinks, so edits are live.
- Claude Code in `~/dotfiles` is the usual way changes get made.
- Notifications via swaync; terminal is kitty; shell is fish.
- `ISSUES.md` holds recurring traps (nvidia upgrade deadlock, stale daemons after upgrades).

## Capabilities and Constraints

- Arch and Ubuntu both stay first-class.
- Engine stays GNU Stow plus shell scripts. Ansible, Nix and chezmoi were considered and rejected (2026-09-13): speed and opaque output outweigh deleted code.
- Allowed unattended: config links and copies, manifest installs (never removals), full system upgrades, boot-critical configs.
- Runs at boot and daily.
- Anything needing the owner goes out as a notification that opens Claude in `~/dotfiles`, already briefed. No custom decision window.
- Root filesystem is ext4 with no snapshots: an unattended upgrade or boot-config change has no rollback beyond what the scripts keep.

## Product Principles

- Never stop to ask. A question becomes a queued decision, and the run carries on with everything else.
- Stay close to distro defaults; remove layers before adding them.
- Less homemade machinery: each script earns its place.
- Quiet when fine, specific when not.
