status is-interactive; or return

# ── Navigation ───────────────────────────────────────────────────────────────
abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'

# ── Files ────────────────────────────────────────────────────────────────────
if command -q eza
    abbr -a la 'eza -a'
    abbr -a ll 'eza -la --git --icons'
    abbr -a lt 'eza --tree --level=2'
    abbr -a lm 'eza -la --sort=modified'
else
    abbr -a la 'ls -a --color=auto'
    abbr -a ll 'ls -la --color=auto'
    abbr -a lm 'ls -latr --color=auto'
end

# ── Git ──────────────────────────────────────────────────────────────────────
abbr -a g git
abbr -a ga 'git add'
abbr -a gc 'git commit'
abbr -a gd 'git diff'
abbr -a gs 'git status'
abbr -a gp 'git push'
abbr -a gl 'git log --oneline'

# ── Tools ────────────────────────────────────────────────────────────────────
abbr -a grep 'grep --color=auto'
abbr -a print lp

# ── Claude ───────────────────────────────────────────────────────────────────
abbr -a c 'claude --permission-mode auto --model "opus[1M]" --effort high'
abbr -a co 'claude-open --dangerously-skip-permissions'
