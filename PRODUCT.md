# Product

<!-- impeccable:product-schema 1 -->

## Platform

linux

## Users

One owner on one laptop (omnibook: Arch Linux, Hyprland), working mostly from the keyboard, in English and Korean (fcitx5 Hangul).

## Product Purpose

These dotfiles are the live desktop: the stow packages under `home/` are the running configs for Hyprland, the bar, notifications, launcher, overlays, terminal and editor. Success is a desktop that stays out of the way: consistent, quick to drive from the keyboard, and recoverable from git.

## Positioning

A personal, single-machine configuration. The owner's apps under `~/projects/` own their implementation; this repo owns how they join the desktop (hyprland.lua, waybar, units, stowed configs). There are no per-host branches and no machine-setup or `/etc` layer.

## Operating Context

The laptop panel, sometimes with external monitors whose rules `monitors.lua` computes. Workspaces 1–9. Hyprland's Lua config starts the session's helpers and overlays. System changes (packages, `/etc`) go through reviewed scripts the owner runs. Tasks, gotchas and decisions live in GitHub issues. Agents test GUIs without taking the owner's focus or keyboard (the `gui-testing` skill).

## Capabilities and Constraints

- Stay close to distro and upstream defaults; change behavior only where it fixes something the owner hits.
- Keyboard first: new shortcuts start from vim (`/`, `n`/`N`, `Esc`), and every Hyprland bind carries a label for the keybind sheet.
- Nothing takes focus the owner did not ask for.
- Polkit prompts accept the owner's face (Howdy on the IR camera, top center of the panel), with the password as fallback.
- GUI apps that are not the owner's keep their stock colors (`docs/gui-app-colors.md`).

## Brand Commitments

- Everforest Dark Medium for all desktop chrome (decision #71), under Everforest's own token names. The `hypr-*` panels and the polkit prompt read `home/hypr/.config/hypr/themes/foliage.conf` at runtime (one `$name = rgb(rrggbb)` per line); hyprland.lua, waybar, swaync and rofi keep same-named copies in their own packages, with no palette compiler (`home/theme/.config/theme/README.md`).
- Corner radii: 12px for windows and containers, 8px for nested controls, a pill when fully round.

## Product Principles

- Upstream first: a stock default beats a clever override unless the override fixes something real.
- The keyboard drives everything; the pointer is optional.
- Nothing steals focus unasked, and anything that must (an authentication prompt) says exactly why.
- Approvals stay visible: a face match shows what it approved before it goes.
- One owner per piece of state: integrations go through the owner's interface.
