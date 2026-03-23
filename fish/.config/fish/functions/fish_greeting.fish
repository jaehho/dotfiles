function fish_greeting
    if test -z "$TMUX"; and command -q tmux
        set_color brblack
        echo "tmux: attach (-a) | new (-s name) | list (ls)"
        set_color normal
    end
end
