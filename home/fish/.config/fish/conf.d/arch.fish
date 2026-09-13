# Arch-specific config — skipped on other distros
test -f /etc/arch-release; or return

# ── Hyprland auto-start on TTY1 ─────────────────────────────────────────────
if command -q Hyprland; and test -z "$DISPLAY"; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    exec /usr/bin/start-hyprland
end
