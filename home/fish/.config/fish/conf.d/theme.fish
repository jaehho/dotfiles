# Catppuccin Mocha (official catppuccin/fish). fish_config records the pick in
# fish_variables; re-apply when that file is missing (fresh machine).
if not set -q fish_color_normal
    fish_config theme choose catppuccin-mocha 2>/dev/null
end

# Official catppuccin ports vendored under the theme stow package.
set -q BAT_THEME; or set -gx BAT_THEME "Catppuccin Mocha"

# Official catppuccin/fzf mocha snippet (https://github.com/catppuccin/fzf).
set -q FZF_DEFAULT_OPTS; or set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"

# starship (package) reads ~/.config/starship.toml (theme package).
if status is-interactive; and command -q starship
    starship init fish | source
end
