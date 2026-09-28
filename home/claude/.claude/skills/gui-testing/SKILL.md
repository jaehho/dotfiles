---
name: gui-testing
description: Test or screenshot a GUI app (GTK, Qt, Electron, web page, Wayland/layer-shell) without taking the user's screen or keyboard. Use when verifying a UI change, capturing a window, or driving an app headlessly on Hyprland.
---

# GUI testing without taking the screen

- **Hidden Hyprland workspace:** add a rule through `hyprctl eval`: `workspace = "name:x silent"`, `no_initial_focus`, `render_unfocused`. Capture inside the app; grim cannot see hidden workspaces. Remove the rule and kill only the test instance afterward.
- **Isolate data:** a private D-Bus can still activate installed user services with real data. Set isolated `XDG_DATA_HOME`, `XDG_DATA_DIRS`, and config paths before `dbus-run-session`. Track child processes as well as launchers. For notifications, keep the IDs `Notify` returns; never clean up by count or position. Restarting swaync clears its history.
- **GTK4 Broadway:** `gtk4-broadwayd :N`, then `GDK_BACKEND=broadway BROADWAY_DISPLAY=:N`; the HTTP port is `8080 + N`. Wayland/layer-shell apps need an isolated test adaptation. Set an explicit browser viewport; leave a short gap between pointer motion and a press.
- **Headless Chrome:** `google-chrome-stable --headless=new --remote-debugging-pipe` speaks CDP on fds 3/4, NUL-framed. Move pipe ends above 4 before mapping them. An open `confirm()` blocks input until answered.
- **Headless Firefox:** `firefox-developer-edition --headless --marionette`; top-level page `let`s need an injected `<script>`. A plain `--screenshot` may fire before async rendering.
- **Layout bugs:** measure rendered bounds through the ancestor chain and inspect the installed theme's cascade (generic classes, toolkit defaults). Check rest, hover, and focus separately. Look at the captured image before reporting.
