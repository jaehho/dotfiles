# Dotfiles

Stow packages under `home/` only. No timers, no package manifests, no apply scripts, no `/etc` installer. Current work is GitHub issues.

## Working here

- Repo files are the live configs through stow. Never discard uncommitted work (`git checkout`/`restore` on a file reverts the running system).
- Commit straight to `main`; no topic branches or worktrees here. The global branch rule is off: a branch swaps the running configs.
- Stow uses `--no-folding`. After adding a file to a package: `stow --no-folding -d home -t ~ <pkg>`.
- Do not add a machine-setup or `/etc` layer back. Those tweaks live in git history and `gotcha` issues, not as a live source of truth here.
- For privileged repairs, write a reviewed script in `/tmp/` for the owner; never run sudo.

## Ownership

- One machine (omnibook, Arch). No per-host or per-distro branches.
- Scripts: `home/bin` for terminal tools, `home/laptop` for desktop helpers, `home/hypr` for compositor glue.
- Each project's `CLAUDE.md` under `~/projects/` is a symlink into `home/projects/projects/<name>/`; edit it here. A session launched here never loads it: read it before the first command or edit in that project or its worktrees.
- Apps under `~/projects/` own their implementation. This repo owns their integration (hyprland.lua, Neovim lazy specs, stowed configs).
- Notifications are the bar's own daemon (`quickshell/bar/Notifs.qml`, #90). There is no swaync; scripts go through `qs -c bar ipc call notifs`.
- Hyprland's defaults place monitors (the catch-all rule in `hyprland.lua`). nwg-displays saves per-monitor rules to `~/.config/hypr/monitors.lua`, generated and untracked, keyed `desc:` (its use-desc setting). `screens.lua` only splits workspaces 1–9 into one block per monitor, left to right as placed; quick settings' Workspaces start here saves which display takes the first block per setup in `~/.config/hypr/screens_primary.lua` (generated, untracked). The scripts read the blocks back from `hyprctl workspacerules`, never recompute them. F1 opens nwg-displays for arrangement, resolution, scale, on/off and mirror. No layout daemon (#87).
- Corner radii: 12px windows/containers, 8px nested controls, pill when fully round. A new surface picks from that scale.
- Keybind sheet parses `hyprland.lua` comments and tmux `-N` notes. Label new binds. `hypr-settings-menu`'s table feeds the bar's quick settings (`--json`), and its IDs are also called by the bar's glyphs (`home/hypr/.config/quickshell/bar/`).

## Docs

- Long investigations: `docs/history/`. Issues take precedence. The `gotcha`/`decision` search rules are in the global file.
