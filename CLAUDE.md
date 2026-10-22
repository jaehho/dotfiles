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
- Each project's `CLAUDE.md` under `~/projects/` is a symlink into `home/projects/projects/<name>/`; edit it here.
- Apps under `~/projects/` own their implementation. This repo owns their integration (hyprland.lua, Neovim lazy specs, stowed configs).
- swaync is the jaehho fork in `~/projects/upstream/swaync`. Native arrows and action digits pass through; `hypr-swaync-keys` handles Ctrl+n/p.
- Monitor rules are computed in `home/hypr/.config/hypr/monitors.lua`. No layout daemon.
- Corner radii: 12px windows/containers, 8px nested controls, pill when fully round. A new surface picks from that scale.
- Keybind sheet parses `hyprland.lua` comments and tmux `-N` notes. Label new binds. `hypr-settings-menu` IDs are also called by waybar.

## Docs

- Long investigations: `docs/history/`. Issues take precedence. The `gotcha`/`decision` search rules are in the global file.
