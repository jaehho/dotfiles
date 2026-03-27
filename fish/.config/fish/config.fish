# ── Environment ──────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim

# ── PATH ─────────────────────────────────────────────────────────────────────
fish_add_path ~/.local/bin ~/.npm-global/bin ~/.cargo/bin

# OpenClaw Completion
if test -f "$HOME/.openclaw/completions/openclaw.fish"
    source "$HOME/.openclaw/completions/openclaw.fish"
end
