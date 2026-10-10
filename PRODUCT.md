# Product

<!-- impeccable:product-schema 1 -->

## Platform

Not applicable: a Linux machine-configuration repo (Arch + Hyprland primary,
Ubuntu/Debian supported), GNU Stow plus copy commands in a README. No web or
mobile surface.

## Users

One owner, across their own machines. They run setup commands themselves.

## Product Purpose

Hold the config files that are expensive to recreate, in a form that is
obvious to apply. Success is a new machine that comes back with the same
behavior, and an old one where editing a file in the repo is editing the
live system.

## Operating Context

- The repo often carries uncommitted work; stowed files are symlinks, so
  edits are live.
- Claude Code in `~/dotfiles` is the usual way changes get made.
- Notifications via swaync; terminal is kitty; shell is fish.

## Capabilities and Constraints

- Arch and Ubuntu both stay first-class.
- Engine is GNU Stow plus documented `/etc` installs. Ansible, Nix, chezmoi,
  and a converge engine were considered and rejected; the last of those was
  removed 2026-10-09 (#53) because it treated a personal laptop as an
  unattended fleet.
- No timers, no package manifests, no unattended upgrades.

## Product Principles

- The owner runs it. Nothing applies itself.
- Stay close to distro defaults; remove layers before adding them.
- Less homemade machinery: each file earns its place.
