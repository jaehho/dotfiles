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

    # fish 4.9 paints its OSC 133;A prompt mark before an erase-display
    # (CSI 0 J at column 0), and tmux (3.7c, see tmux#3856, closed as the
    # shell's fault) clears line flags on that erase, so every mark dies and
    # copy-mode previous-prompt finds nothing. Re-emit a mark inside the
    # prompt string: it is painted after the erase and lands on the blank
    # separator line, so the tmux prefix C-y binding steps down twice.
    # starship.toml sets add_newline = false; the separator comes from here.
    functions -c fish_prompt __starship_prompt
    function fish_prompt
        printf '\n\033]133;A\033\\'
        __starship_prompt
    end
end
