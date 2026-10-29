# easel

Rust reference-board app: GTK4 window, CLI, and a live D-Bus API the CLI edits the open window through. How it works: `README.md`.

- **Every edit is an op.** The window, the CLI and the bus change a board only through `easel_core::ops::apply`, one batch per undo step. A new kind of edit is a new `Op` with a test in `ops.rs`, not code in the window.
- **Rects are absolute canvas coordinates.** Never store transforms or positions relative to a frame; moving a frame moves its contents explicitly.
- **Measure text only with `easel_render::text::Measurer`** (96 dpi, no hinting). A widget's Pango context gives other sizes, and the file, the CLI and the window would disagree.
- **Nothing in `easel-render` or `easel` may call `gtk::init`.** The CLI renders with no display; `make test` runs with no display and a dead bus, so a slip fails there.
- **Try window changes in `scripts/dev`, never on the session bus.** It runs `dev.jaeho.Easel.Devel` on a private bus with its own XDG folders, on a hidden Hyprland workspace. Check it with `scripts/dev snap`, `drive` and `dump`, and `make check-gui BOARD=<a copy>`; read the PNGs.
- **Images in a bundle are never rewritten.** They are named by their hash; `easel gc --delete` is the only thing that removes them, and it refuses while the window has the board open.
