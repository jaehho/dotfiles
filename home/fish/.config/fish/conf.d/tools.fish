status is-interactive; or return

# ── tmux env refresh ────────────────────────────────────────────────────────
# Inside tmux: pull Hyprland/Wayland env from tmux global before each command.
# Fixes existing panes after a Hyprland restart. A new session still inherits
# from the shell that starts it; publish updates with `tmux setenv -g`.
function __refresh_hyprland_env --on-event fish_preexec
    set -q TMUX; or return
    for var in HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY
        set -l line (tmux show-environment -g $var 2>/dev/null)
        or continue
        string match -q -- '-*' $line; and continue
        set -l val (string replace -r '^[^=]+=' '' -- $line)
        test -n "$val"; and set -gx $var $val
    end
end

# ── fd ───────────────────────────────────────────────────────────────────────
if command -q fd
    abbr --add fd 'fd -HI'
end

# ── fzf ──────────────────────────────────────────────────────────────────────
if command -q fzf; and fzf --fish &>/dev/null
    fzf --fish | source
end

# ── direnv ──────────────────────────────────────────────────────────────────
if command -q direnv
    direnv hook fish | source
end

# ── zoxide ───────────────────────────────────────────────────────────────────
if command -q zoxide
    zoxide init fish | source
end
