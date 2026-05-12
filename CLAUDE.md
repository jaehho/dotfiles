# Dotfiles

GNU Stow-based dotfiles. Primary target Arch + Hyprland; also supports Ubuntu/Debian — when editing configs, consider both. Package lists split into `COMMON_PACKAGES` (all) and `ARCH_PACKAGES` (Arch only); gate Arch-only pieces behind the distro checks in the Makefile. Each top-level directory is a stow package mirroring `$HOME`, or a non-stow helper (`packages/`, `scripts/`, `hypr-tools/`).

`make sync` is the only setup command — idempotent, safe to re-run.

## Non-obvious gotchas

- **Boot-critical configs** (`grub`, `mkinitcpio`, `modprobe`) are **copied** by `_sync-system`, not symlinked — they survive a broken `/home` mount.
- **Stow uses `--no-folding`** (individual symlinks, not directory symlinks).
- **Per-machine choices** live in `hosts/<hostname>.mk` (committed). Sync prompts on first run for any new host.
- **Claude Code config** is declarative — see `claude/.claude/reconcile/README.md` for reconcile and MCP secrets.
- **`hypr-tools`** is a submodule (Rust, two AUR packages). AUR binaries run by default; submodule is for development. See `hypr-tools/README.md`.
