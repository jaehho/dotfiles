# Debian/Ubuntu-specific config — skipped on other distros
test -f /etc/debian_version; or return

# ── Tool name shims ───────────────────────────────────────────────────────────
# Ubuntu ships bat as 'batcat' and fd as 'fdfind'; prefer ~/.local/bin symlinks
# if something created them, otherwise alias the distro names.

if not command -q bat; and command -q batcat
    alias bat batcat
end

if not command -q fd; and command -q fdfind
    alias fd fdfind
end
