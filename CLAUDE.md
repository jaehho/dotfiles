# Dotfiles

GNU Stow-based dotfiles. Primary target is Arch Linux + Hyprland, but the repo also supports Ubuntu — package lists split into `COMMON_PACKAGES` (all systems) and `ARCH_PACKAGES` (Arch only), and some boot/system configs are Arch-gated. When adding or editing configs, consider both environments; gate Arch-only pieces behind the existing distro checks in the Makefile. Each top-level directory is a stow package that mirrors `$HOME`.

## Structure

Each top-level directory is either a stow package mirroring `$HOME` or a
non-stow helper (`packages/`, `scripts/`, `hypr-tools/` submodule). Run
`tree -L 1` or `make help` to see what's there.

## Key commands

`make sync` is the only setup command. It chains everything: packages,
stow, system configs, services, Claude Code reconcile (interactive on
removals), default shell. Idempotent — safe to re-run after a pull.
First run prompts for restic password, rclone OAuth, and any system-config
diffs. Later runs skip already-configured steps.

```bash
make sync                  # bring this machine up to date
make status                # show stow/system/service state
```

That's the whole public surface. Mounts, backups, snapshots, and the
hypr-tools dev override are toggled directly with `systemctl --user`,
`restic`, and `make -C hypr-tools install/uninstall` — no Makefile
wrappers. The `ssh-cdn` fish function starts the GCP instance and mounts
on demand.

### Per-machine intent

Sync auto-detects most variation (distro, capabilities, network reachability,
GCP-instance state). For *choices* that vary by machine, sync prompts once on
a new host and writes the answers to `hosts/<hostname>.mk` (committed to the
repo). Subsequent syncs include the file silently. Flags it sets:
`HOST_DEV_TOOLS`, `HOST_RESTIC`, `HOST_DROP_PKGS`. To change later, edit the
file or delete it (next sync re-prompts). In non-interactive contexts (CI / no
TTY), the script writes conservative defaults without prompting.

## Claude Code config

Tracked under `claude/.claude/`: `CLAUDE.md`, `settings.json` (including
`enabledPlugins`), custom hooks, and reconcile manifests at
`claude/.claude/reconcile/` (MCP servers, marketplaces, third-party skill
sources). Custom skills live at `claude/.claude/skills/<name>/`.

`scripts/claude-reconcile.sh` (called from `make sync`) enforces strict
parity: anything installed at user scope but not declared gets removed
(interactively prompted per category when run from sync). Secrets for
`${VAR}` placeholders in `mcp-servers.json` come from
`~/.config/claude-mcp-secrets.env` (gitignored, see
`claude/.claude/reconcile/secrets.env.example`).

## Submodule tools

`hypr-tools` is a Rust Cargo workspace published to AUR, included here as a git submodule. It ships two binaries (`hypr-wallpaper`, `hypr-monitor`) and produces two AUR packages from one repo.

### Maintainer workflow (Option C)

Day-to-day, the AUR packages at `/usr/bin/` are what run. The submodule is for development.

Set `HOST_DEV_TOOLS := 1` in `hosts/<hostname>.mk` to make `make sync` build
from the submodule into `~/.local/bin` (which shadows AUR on PATH). To
revert temporarily without touching the host config, run
`make -C hypr-tools uninstall`; the next `make sync` re-installs.

```bash
# Develop
cd hypr-tools/
# edit code...
make -C . install                    # rebuild & reinstall after edits
# test changes...
git add -A && git commit -m "..."
git push

# Release
make release-patch                   # 1.0.1 — bug fix
make release-minor                   # 1.1.0 — new feature
make release-major                   # 2.0.0 — breaking change
# Tags, pushes to GitHub, and updates both hypr-wallpaper-git AND
# hypr-monitor-git on AUR in one command.
```

### AUR packages

| Package | AUR name | Repo |
|---------|----------|------|
| Wallpaper manager        | `hypr-wallpaper-git` | github.com/jaehho/hypr-tools |
| Monitor/workspace daemon | `hypr-monitor-git`   | github.com/jaehho/hypr-tools |

The `make release-*` target clones each AUR repo to a temp dir, updates PKGBUILD + .SRCINFO, pushes, and cleans up. No persistent AUR checkout needed.

### PKGBUILD versioning

Uses `git describe --tags` — clean semver on tags (`1.0.0`), auto-suffix between tags (`1.0.0.r2.gabcdef`).

## Hyprland TUIs

| TUI | Keybind | Binary |
|-----|---------|--------|
| Wallpaper manager | `Super+Alt+W` | `hypr-wallpaper tui` (via `hypr-wallpaper-open` wrapper) |
| Monitor inspector | (CLI only)    | `hypr-monitor tui` |

Both are Rust + ratatui (crossterm). The wallpaper TUI reuses its window via a class-based rule (class `hypr-wallpaper-menu`).

## Stow conventions

- `--no-folding` is always used (creates individual symlinks, not directory symlinks)
- Distro-aware: `COMMON_PACKAGES` for all systems, `ARCH_PACKAGES` for Arch only
- Boot-critical configs (grub, mkinitcpio, modprobe) are **copied** not symlinked
  by `_sync-system` so they survive broken /home mounts

## Commands You Give Me to Run

**Default: run commands yourself with the Bash tool.** Don't hand me a command and ask me to run it just because it's convenient — that wastes a round trip. Only delegate to me when you genuinely cannot run the command yourself, e.g.:

- It requires `sudo` or other privileged access
- It needs an interactive TTY (login flows, REPLs, editors, password prompts)
- It needs to run in my shell session, not a subprocess (sourcing env, activating contexts)
- It would otherwise hang, prompt, or fail under your tool harness

**When you do need to delegate**, do not list the commands inline for me to copy-paste. Instead, write them to a temporary shell script at `/tmp/<descriptive-name>.sh`. The script should:

- Start with `set -euo pipefail` (for bash) or equivalent strict mode to fail fast
- Print progress messages so I can see what step is running
- Handle expected failure modes (check `command -v foo` before using it, guard against existing state, etc.)
- Be idempotent where possible — safe to re-run if part of it fails
- Exit cleanly with a meaningful status message

Then tell me the path and how to invoke it (e.g. `sudo bash /tmp/foo.sh`, or `sh`/`python`/etc). This is more robust than copy-pasting a block of commands, especially for anything touching system state.
