# Dotfiles

Stow packages under `home/` only. No timers, no package manifests, no
apply scripts, no `/etc` installer. Current work is GitHub issues.

## Working here

- Repo files are the live configs through stow. Never discard uncommitted
  work (`git checkout`/`restore` on a file reverts the running system).
- Stow uses `--no-folding`. After adding a file to a package:
  `stow --no-folding -d home -t ~ <pkg>`.
- Do not add a machine-setup or `/etc` layer back. Those tweaks live in
  git history and `gotcha` issues, not as a live source of truth here.
- For privileged repairs, write a reviewed script in `/tmp/` for the owner;
  never run sudo.

## Ownership

- `home/bin` is server tools; `home/laptop` is desktop-only. New scripts go
  in one or the other.
- Apps under `~/projects/` own their implementation. This repo owns their
  integration (hyprland.lua, Neovim lazy specs, stowed configs).
- swaync is the jaehho fork in `~/projects/forks/swaync`. Native arrows and
  action digits pass through; `hypr-swaync-keys` handles Ctrl+n/p.
- Monitor rules are computed in `home/hypr/.config/hypr/monitors.lua`. No
  layout daemon.
- Corner radii: 12px windows/containers, 8px nested controls, pill when
  fully round. A new surface picks from that scale.
- Keybind sheet parses `hyprland.lua` comments and tmux `-N` notes. Label
  new binds. `hypr-settings-menu` IDs are also called by waybar.

## Docs

- Writing `CLAUDE.md`, rules, skills, or READMEs: read
  `docs/writing-claude-files.md`.
- Known traps: issues labeled `gotcha` (open = not believed fixed). Search
  open and closed before changing broken behavior.
- Design choices: issues labeled `decision` (closed once decided).
- Long investigations: `docs/history/`. Issues take precedence.
