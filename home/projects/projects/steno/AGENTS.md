# steno

README.md covers install, use and how it works; PRODUCT.md is the design brief for the GTK window (impeccable) and its promises (recording state always visible, guidance pulled, never pushed).

- GUI checks run on GTK Broadway with `WAYLAND_DISPLAY` and `DISPLAY` unset; never present a window on the real display, it steals focus. Recipe: `start_broadway` in `tests/test_sidebar_menu.py`. Keep `~/.local/bin/asst` off `PATH`, use a private D-Bus `--config-file` with an empty `<servicedir>` and isolated XDG dirs, and kill test processes by PID (never `pkill -f`, which kills the live `steno gui --background` listener).
- **Archive privacy (`~/.local/share/steno/sessions/`):** open only the session and lines a task actually needs; prefer counts, offsets, dB, or line numbers over verbatim quotes (use the shortest quote when needed as evidence), and never screenshot the archive window.
