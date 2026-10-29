# theme — Everforest Dark Medium files

Static vendor tree of Everforest Dark Medium theme files for terminal and CLI apps. Not a generator. Where a usable port exists it is copied from upstream; otherwise the file is a hand recolor of the previous Catppuccin Mocha port (see git history) with the [sainnhe/everforest palette](https://github.com/sainnhe/everforest/blob/master/palette.md). Refresh ports by copying from their repos; do not add a palette compiler.

## Where things land

| path | source |
|---|---|
| `.config/bat/themes/Everforest Dark.tmTheme` | [VasylRomanets/everforest-bat](https://github.com/VasylRomanets/everforest-bat) `themes/everforest-dark.tmTheme` at 1bed96f (MIT); its hard-contrast background, gutter, line highlight and selection are swapped for the medium values |
| `.config/btop/btop.conf` | `color_theme` names `everforest-dark-medium`, which btop ships in `/usr/share/btop/themes/`; nothing vendored |
| `.config/eza/theme.yml` | [neuromaancer/everforest_collection](https://github.com/neuromaancer/everforest_collection) `eza/theme.yml` at a052419 (MIT), unmodified |
| `.config/lazygit/config.yml` | hand recolor of catppuccin/lazygit (lavender) |
| `.config/cava/config` | hand recolor of catppuccin/cava |
| `.config/mpv/mpv.conf` | hand recolor of catppuccin/mpv (lavender) |
| `.config/imv/config` | hand recolor of catppuccin/imv |
| `.config/starship.toml` | hand recolor of catppuccin/starship; the prompt layout is this repo's |

`.config/qt5ct/colors/` and `.config/Kvantum/catppuccin-mocha-lavender/` are leftover Catppuccin Mocha ports; GUI apps run on stock colors and nothing selects them.

Apps with their own stow package carry their theme files there: kitty (`themes/everforest_dark_medium.conf`), fish (`themes/everforest-dark-medium.theme`, plus `BAT_THEME` and the fzf colors in `conf.d/theme.fish`), tmux (`@ef_*` tokens in `.tmux.conf`), nvim (the sainnhe/everforest plugin), zathura (`everforest-dark-medium`) and git (`color.diff` and delta's `syntax-theme` in `.gitconfig`). Desktop chrome (hypr, waybar, rofi, swaync) also keeps its colors in its own package.

## Palette

Everforest Dark with the medium background (`bg0` `#2d353b`). Hand recolors map each Catppuccin token to the Everforest color with the same role and use Everforest's names (`bg0`, `fg`, `green`, ...). The old lavender accent becomes `green`; `blue` stays focus, `purple` marks special, `orange` is worth a glance, `red` is critical.
