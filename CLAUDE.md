# Dotfiles

GNU Stow-based dotfiles. Primary target Arch + Hyprland; also supports Ubuntu/Debian — when editing configs, consider both. Package manifests live in `packages/` — `common.txt` (same name on both distros), `arch/*.txt` (by category), `ubuntu.txt`, plus `cargo`/`npm`/`uv`. Gate Arch-only pieces behind the distro checks in `scripts/`. Each top-level directory is a stow package mirroring `$HOME`, a system config installed by the `system` phase, or a non-stow helper (`packages/`, `scripts/`, `hosts/`).

`make sync` is the only setup command — idempotent, safe to re-run.

## Non-obvious gotchas

- **Boot-critical configs** (`grub`, `mkinitcpio`, `modprobe`) are **copied** by the `system` sync phase, not symlinked — they survive a broken `/home` mount.
- **Stow uses `--no-folding`** (individual symlinks, not directory symlinks).
- **Per-machine choices** live in `hosts/<hostname>.sh` (committed, sourced by `scripts/lib.sh`). Sync prompts on first run for any new host.
- **The Makefile is a dispatcher only** — logic lives in `scripts/`. Shared lists are in `scripts/lib.sh`; run one phase with `./scripts/sync.sh --list` / `./scripts/sync.sh <phase>`.
- **Only `packages/arch/99-inbox.txt` is machine-sorted.** Drift-detected packages land there; the other `arch/*.txt` keep their comments and grouping. File inbox entries by hand.
- **Package upgrades are gated to once per 24h** (read from `pacman.log`), so re-syncing after a config edit is cheap. `FORCE_UPGRADE=1` overrides.
- **Claude Code config** is declarative — see `claude/.claude/reconcile/README.md` for reconcile and MCP secrets.
- **`hypr-tools`** lives outside this repo (Rust, two AUR packages). AUR binaries run by default; `HOST_DEV_TOOLS=1` builds from `HOST_DEV_TOOLS_SRC` (default `~/projects/hypr-tools`) and shadows them. A missing checkout is not an error.
- **When `make sync` or the machine breaks, read `ISSUES.md` first** — recurring traps with copy-paste fixes up top, dated incident history below. Add to it rather than special-casing `scripts/`.
