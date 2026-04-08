# ── Environment ──────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim

# ── GitHub ───────────────────────────────────────────────────────────────────
if test -f ~/dotfiles/.env
    set -l pat (string match -r 'GITHUB_PERSONAL_ACCESS_TOKEN="([^"]+)"' < ~/dotfiles/.env)[2]
    test -n "$pat"; and set -gx GITHUB_PERSONAL_ACCESS_TOKEN $pat
end

# ── PATH ─────────────────────────────────────────────────────────────────────
fish_add_path ~/.local/bin ~/.npm-global/bin ~/.cargo/bin

# OpenClaw Completion
if test -f "$HOME/.openclaw/completions/openclaw.fish"
    source "$HOME/.openclaw/completions/openclaw.fish"
end
