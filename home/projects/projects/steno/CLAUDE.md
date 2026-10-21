# steno

README.md covers install, use and how it works; PRODUCT.md is the design brief for the GTK window (impeccable) and its promises (recording state always visible, guidance pulled, never pushed).

- GUI checks run on GTK Broadway with `WAYLAND_DISPLAY` and `DISPLAY` unset; never present a window on the real display, it steals focus. Recipe: `start_broadway` in `tests/test_sidebar_menu.py`.
