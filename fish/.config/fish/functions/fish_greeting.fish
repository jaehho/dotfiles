function fish_greeting
    if test -z "$TMUX"; and test -n "$WAYLAND_DISPLAY"; and command -q tmux; and status is-interactive
        exec tmux
    end
end
