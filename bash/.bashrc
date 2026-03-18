#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Bash completions
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
fi

# Default editor
export EDITOR="nvim"
export VISUAL="nvim"

# PATH
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# ── Hyprland auto-start on TTY1 ────────────────────────────────────────────────
if command -v Hyprland &>/dev/null && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec /usr/bin/start-hyprland
fi

# ── tmux hint ─────────────────────────────────────────────────────────────────
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
    echo "tmux: attach (-a) | new (-s name) | list (ls)"
fi

[[ -z "$VSCODE_INJECTION" ]] && eval "$(direnv hook bash)"

# ── fzf ───────────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    eval "$(fzf --bash)"
fi

# ── starship prompt ───────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
else
    show_virtual_env() {
      if [[ -n "$VIRTUAL_ENV" && -n "$DIRENV_DIR" ]]; then
        echo "($(basename $(dirname $VIRTUAL_ENV))) "
      fi
    }
    PS1='[\u@\h \W]\$ '
    PS1='$(show_virtual_env)'"$PS1"
fi

alias c='claude --dangerously-skip-permissions --model opus --effort max'
