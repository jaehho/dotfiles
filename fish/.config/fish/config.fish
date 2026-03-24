# ── Environment ──────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim

# ── PATH ─────────────────────────────────────────────────────────────────────
fish_add_path ~/.local/bin ~/.npm-global/bin

# OpenClaw Completion
source "/home/jaeho/.openclaw/completions/openclaw.fish"
