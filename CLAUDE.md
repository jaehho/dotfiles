# Dotfiles

GNU Stow-based dotfiles. Primary target is Arch Linux + Hyprland, but the repo also supports Ubuntu — package lists split into `COMMON_PACKAGES` (all systems) and `ARCH_PACKAGES` (Arch only), and some boot/system configs are Arch-gated. When adding or editing configs, consider both environments; gate Arch-only pieces behind the existing distro checks in the Makefile. Each top-level directory is a stow package that mirrors `$HOME`.

## Structure

```
dotfiles/
├── Makefile              # stow-all, install-tools, system-install, pkg-dump, etc.
├── hypr-tools/           # git submodule → github.com/jaehho/hypr-tools
├── hypr/                 # Hyprland config, scripts, window rules
├── fish/                 # Fish shell config
├── kitty/                # Kitty terminal config
├── nvim/                 # Neovim config
├── waybar/               # Waybar config
├── rofi/                 # Rofi launcher config
├── mako/                 # Mako notification daemon
└── ...                   # Other stow packages (git, tmux, ssh, etc.)
```

## Key commands

```bash
make stow-all              # Stow all packages to ~
make install-tools         # Dev-install submodule tools to ~/.local/bin (overrides AUR)
make uninstall-tools       # Remove dev overrides, revert to AUR /usr/bin versions
make stow-hypr             # Stow a single package
make system-install        # Copy boot configs, symlink runtime configs (uses sudo)
make pkg-dump              # Save installed package lists
make status                # Show stow/system/service state
```

## Submodule tools

`hypr-tools` is a Rust Cargo workspace published to AUR, included here as a git submodule. It ships two binaries (`hypr-wallpaper`, `hypr-monitor`) and produces two AUR packages from one repo.

### Maintainer workflow (Option C)

Day-to-day, the AUR packages at `/usr/bin/` are what run. The submodule is for development.

```bash
# Develop
cd hypr-tools/
# edit code...
make install-tools                   # (from dotfiles root) override AUR with dev copy
# test changes...
git add -A && git commit -m "..."
git push
make uninstall-tools                 # revert to AUR version

# Release
cd hypr-tools/
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
- Boot-critical configs (grub, mkinitcpio) are **copied** not symlinked via `system-install`
