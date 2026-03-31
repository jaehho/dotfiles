# Dotfiles

GNU Stow-based dotfiles for Arch Linux + Hyprland. Each top-level directory is a stow package that mirrors `$HOME`.

## Structure

```
dotfiles/
├── Makefile              # stow-all, install-tools, system-install, pkg-dump, etc.
├── hypr-desktop/         # git submodule → github.com/jaehho/hypr-desktop
├── hypr-wallpaper/       # git submodule → github.com/jaehho/hypr-wallpaper
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
make stow-all          # Stow all packages to ~
make install-tools     # Dev-install submodule tools to ~/.local/bin (overrides AUR)
make uninstall-tools   # Remove dev overrides, revert to AUR /usr/bin versions
make stow-hypr         # Stow a single package
make system-install    # Copy boot configs, symlink runtime configs (uses sudo)
make pkg-dump          # Save installed package lists
make status            # Show stow/system/service state
```

## Submodule tools

`hypr-desktop` and `hypr-wallpaper` are standalone projects published to AUR and included here as git submodules.

### Maintainer workflow (Option C)

Day-to-day, the AUR package at `/usr/bin/` is what runs. The submodules are for development.

```bash
# Develop
cd hypr-desktop/                     # or hypr-wallpaper/
# edit code in bin/...
make install-tools                   # (from dotfiles root) override AUR with dev copy
# test changes...
git add -A && git commit -m "..."
git push
make uninstall-tools                 # revert to AUR version

# Release
cd hypr-desktop/
make release-patch                   # 1.0.1 — bug fix
make release-minor                   # 1.1.0 — new feature
make release-major                   # 2.0.0 — breaking change
# Tags, pushes to GitHub, updates AUR in one command.
# Reads latest git tag, auto-bumps the correct semver component.
```

### AUR packages

| Package | AUR name | Repo |
|---------|----------|------|
| Virtual desktop manager | `hypr-desktop-git` | github.com/jaehho/hypr-desktop |
| Wallpaper manager | `hypr-wallpaper-git` | github.com/jaehho/hypr-wallpaper |

The `make release-*` targets clone the AUR repo to a temp dir, update PKGBUILD + .SRCINFO, push, and clean up. No persistent AUR checkout needed.

### PKGBUILD versioning

Uses `git describe --tags` — clean semver on tags (`1.0.0`), auto-suffix between tags (`1.0.0.r2.gabcdef`).

## Hyprland TUIs

Both TUIs are Python 3 + curses. Key performance detail: `ESCDELAY` is set to 25ms (default is 1000ms). Kitty `input_delay` is set to 0.

| TUI | Keybind | Script |
|-----|---------|--------|
| Desktop manager | `Super+D` | `hypr-desktop-menu` |
| Wallpaper manager | `Super+Alt+W` | `hypr-wallpaper-menu` |

Both run inside kitty popups with class-based window rules for focus reuse (if already open, focuses instead of launching a new instance).

## Stow conventions

- `--no-folding` is always used (creates individual symlinks, not directory symlinks)
- Distro-aware: `COMMON_PACKAGES` for all systems, `ARCH_PACKAGES` for Arch only
- Boot-critical configs (grub, mkinitcpio) are **copied** not symlinked via `system-install`

## Do not use sudo

The user's environment blocks failed sudo attempts. Never run sudo in Bash tool calls.
