# If not running interactively, don't do anything
status is-interactive; or return

# Default editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# PATH
fish_add_path ~/.local/bin ~/.npm-global/bin

# Aliases
alias ls='ls --color=auto'
alias la='ls -a --color=auto'
alias ll='ls -la --color=auto'
alias grep='grep --color=auto'
alias c='claude --dangerously-skip-permissions --model opus --effort max'

# ── Hyprland auto-start on TTY1 ────────────────────────────────────────────────
if command -q Hyprland; and test -z "$DISPLAY"; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    exec /usr/bin/start-hyprland
end

# ── tmux hint ─────────────────────────────────────────────────────────────────
if test -z "$TMUX"; and command -q tmux
    echo "tmux: attach (-a) | new (-s name) | list (ls)"
end

# ── direnv ────────────────────────────────────────────────────────────────────
if test -z "$VSCODE_INJECTION"; and command -q direnv
    direnv hook fish | source
end

# ── fzf ───────────────────────────────────────────────────────────────────────
if command -q fzf
    fzf --fish | source
end
