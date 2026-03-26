status is-interactive; or return

# ── tmux auto-launch ─────────────────────────────────────────────────────────
# Auto-launch tmux in graphical terminals and SSH sessions — skip bare TTYs
# (where arch.fish may exec Hyprland) and skip if already inside tmux.
if command -q tmux; and not set -q TMUX
    and begin; test -n "$DISPLAY" -o -n "$WAYLAND_DISPLAY"; or set -q SSH_CONNECTION; end
    exec tmux
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
