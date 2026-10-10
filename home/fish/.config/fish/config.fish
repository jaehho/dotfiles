# ── Environment ──────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim

# Python writes __pycache__ next to the script it runs. Scripts in ~/.local/bin
# are stow symlinks into the dotfiles repo, so that put build artifacts inside
# the repo, which stow then linked back into $HOME. Redirect the cache instead
# of disabling it, so bytecode caching still works.
set -gx PYTHONPYCACHEPREFIX ~/.cache/python

# ── GitHub ───────────────────────────────────────────────────────────────────
if test -f ~/dotfiles/.env
    set -l pat (string match -r 'GITHUB_PERSONAL_ACCESS_TOKEN="([^"]+)"' < ~/dotfiles/.env)[2]
    test -n "$pat"; and set -gx GITHUB_PERSONAL_ACCESS_TOKEN $pat
end

# ── Puppeteer (mermaid-cli / mermaid-filter) ─────────────────────────────────
# Use the system Chromium-based browser instead of puppeteer's bundled ~150MB
# Chrome download. First match wins.
for _c in /usr/bin/google-chrome-stable /usr/bin/chromium
    if test -x $_c
        set -gx PUPPETEER_SKIP_DOWNLOAD 1
        set -gx PUPPETEER_EXECUTABLE_PATH $_c
        break
    end
end
set -e _c

# ── PATH ─────────────────────────────────────────────────────────────────────
fish_add_path ~/.local/bin ~/.npm-global/bin ~/.cargo/bin
