# Dotfiles

GNU Stow dotfiles for Arch + Hyprland and Ubuntu/Debian. `home/` mirrors `$HOME`; `system/` holds system configs; `packages/` holds manifests. Gate distro-specific work through `scripts/lib.sh`. Current work is in GitHub issues (`gh issue list`).

## Operating model

- `dotfiles` reports status; `dotfiles sync` converges now; `dotfiles decide` opens the recorded decisions. The dispatcher stays thin; implementation belongs in `scripts/`.
- `scripts/converge.sh` runs unattended as system and user timer jobs. List steps with `./scripts/converge.sh --list`; run a user step with `./scripts/converge.sh user <step>`. Bootstrap is the interactive new-machine entry point.
- Read `decisions.json` and the referenced logs under `/var/lib/dotfiles/` and `~/.local/state/dotfiles/`. Resolve causes; the next run updates decisions. Never edit the decision files or package manifests automatically to hide drift.
- Host choices belong in `hosts/<hostname>.sh`; shared lists and install destinations belong in `scripts/lib.sh`. Put Arch packages in their category manifest or `99-inbox.txt`.
- Arch upgrade gates live in `scripts/packages.sh`; Debian/Ubuntu upgrades belong to unattended-upgrades. Read the decision before bypassing a hold.

## Change boundaries

- Stow uses `--no-folding`. Boot-critical and sandbox-consumed configs must be real files, not symlinks into `/home`; follow `SYSTEM_LINKS`, `SYSTEM_INSTALLS`, and `SYSTEM_COPIES` in `scripts/lib.sh`. The boot step rebuilds and rolls back failed changes.
- DNS belongs to systemd-resolved, including its stub link and NetworkManager integration. Preserve Tailscale split DNS.
- Claude configuration is declarative: see `home/claude/.claude/reconcile/README.md` and `scripts/claude-reconcile.sh`. Do not put secrets in manifests.
- Monitor rules are computed directly by `home/hypr/.config/hypr/monitors.lua`. Do not add a layout daemon or generated config.
- The keybind sheet parses `hyprland.lua` comments and tmux `-N` notes. Label new binds. Quick-settings IDs in `hypr-settings-menu` are also called by waybar; preserve those callers when renaming.
- Apps under `~/projects/` own their implementation and install flow. This repo owns their integration; inspect `hyprland.lua`, the converge enable list, and Neovim's lazy specs before moving functionality here.
- `home/bin` is the server tools (`scripts/server.sh`); `home/laptop` is desktop/laptop-only (timers, notify, tip, FreeCAD helpers). Put new scripts in one or the other, not both.
- swaync is the jaehho fork in `~/projects/forks/swaync`, packaged by `packaging/PKGBUILD`. Native arrows/action digits pass through; `hypr-swaync-keys` handles Ctrl+n/p and visibility. Exclusive submaps need media/screenshot bindings too.

## Troubleshooting and documentation

Read [ISSUES.md](ISSUES.md) before changing a broken converge step or system behavior. It holds symptom checks, recovery, and links to historical evidence. Add recurring fixes there instead of adding speculative layers to `scripts/`.

Keep this file to ownership rules and non-obvious constraints. Put detailed recipes in ISSUES.md and dated investigation history in `docs/history/`; correct disproved conclusions in memory as well as documentation.
