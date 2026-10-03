status is-interactive; or return

# ── tmux auto-start ──────────────────────────────────────────────────────────
# Every interactive shell outside tmux gets a new session. No picker; switch
# with prefix+s. Skip if tmux is missing, already inside tmux, or NO_TMUX is
# set (Super+Shift+Return). arch.fish execs Hyprland on TTY1 before this file
# is sourced.
if command -q tmux; and not set -q TMUX; and not set -q NO_TMUX
    # Push current Hyprland/Wayland env into tmux global env so existing
    # sessions (including continuum-restored ones) pick up fresh values.
    # No-op if tmux server isn't running yet (new-session inherits directly).
    for var in HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY
        set -q $var; and tmux setenv -g $var $$var 2>/dev/null
    end
    exec tmux new-session
end

# ── tmux env refresh ────────────────────────────────────────────────────────
# Inside tmux: pull fresh Hyprland/Wayland env from tmux global before each
# command. Fixes existing panes after a Hyprland restart without needing to
# open a new pane. Layer 2 (above) keeps the global env current.
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

# ── direnv (skip in vscode to avoid conflicts) ──────────────────────────────
if test -z "$VSCODE_INJECTION"; and command -q direnv
    direnv hook fish | source
end

# ── zoxide ───────────────────────────────────────────────────────────────────
if command -q zoxide
    zoxide init fish | source
end
