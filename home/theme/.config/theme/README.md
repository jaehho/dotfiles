# theme — Catppuccin Mocha port files

Static vendor tree of official [Catppuccin](https://github.com/catppuccin) Mocha theme files. Not a generator. Refresh by copying files from the upstream repos; do not add a palette compiler.

## Where things land

| path | upstream |
|---|---|
| `.config/bat/themes/` | catppuccin/bat |
| `.config/btop/themes/` + `btop.conf` | catppuccin/btop |
| `.config/eza/theme.yml` | catppuccin/eza (lavender accent) |
| `.config/lazygit/config.yml` | catppuccin/lazygit (lavender) |
| `.config/cava/config` | catppuccin/cava |
| `.config/mpv/mpv.conf` | catppuccin/mpv (lavender) |
| `.config/imv/config` | catppuccin/imv |
| `.config/starship.toml` | catppuccin/starship |
| `.config/qt5ct/colors/` | catppuccin/qt5ct (lavender) |
| `.config/Kvantum/catppuccin-mocha-lavender/` | catppuccin/Kvantum |
| `apply-notes/` | click-to-apply GUI files (see `docs/catppuccin-mocha-apply.md`) |

Apps with their own stow package (kitty, fish, hypr, waybar, rofi, swaync, tmux, nvim, zathura) carry their theme files there instead.

## Palette

Official Mocha. Accent choice is **lavender** (`#b4befe`) where a port ships per-accent variants.
