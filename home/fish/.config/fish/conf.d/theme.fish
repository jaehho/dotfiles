# Everforest Dark Medium (themes/everforest-dark-medium.theme). theme choose
# loads it as globals for this session; skipped when a universal
# fish_color_* pick exists.
if not set -q fish_color_normal
    fish_config theme choose everforest-dark-medium 2>/dev/null
end

# bat theme vendored under the theme stow package.
set -q BAT_THEME; or set -gx BAT_THEME "Everforest Dark"

# fzf: hand recolor of the catppuccin/fzf mocha snippet with
# sainnhe/everforest palette.md.
set -q FZF_DEFAULT_OPTS; or set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#343f44,bg:#2d353b,spinner:#e69875,hl:#e67e80 \
--color=fg:#d3c6aa,header:#e67e80,info:#d699b6,pointer:#e69875 \
--color=marker:#a7c080,fg+:#d3c6aa,prompt:#d699b6,hl+:#e67e80 \
--color=selected-bg:#3d484d \
--color=border:#7a8478,label:#d3c6aa"

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
