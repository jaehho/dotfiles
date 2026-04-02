status is-interactive; or return

# ── tmux auto-launch ─────────────────────────────────────────────────────────
# Auto-launch tmux in graphical terminals and SSH sessions — skip bare TTYs
# (where arch.fish may exec Hyprland) and skip if already inside tmux.
if command -q tmux; and not set -q TMUX
    and begin; test -n "$DISPLAY" -o -n "$WAYLAND_DISPLAY"; or set -q SSH_CONNECTION; end
    set -l unattached (tmux list-sessions -f '#{?session_attached,0,1}' -F '#S' 2>/dev/null)
    # Push current Hyprland/Wayland env into tmux global env so existing
    # sessions (including continuum-restored ones) pick up fresh values.
    # No-op if tmux server isn't running yet (new-session inherits directly).
    for var in HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY
        set -q $var; and tmux setenv -g $var $$var 2>/dev/null
    end
    if test (count $unattached) -ge 1
        exec tmux attach-session -t "$unattached[1]" \; choose-tree -Zs -f '#{?session_attached,0,1}'
    else
        exec tmux new-session
    end
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
