---
name: quickshell
description: Writes, reloads, restarts and captures Quickshell (QML) shells on this machine, the dotfiles bar and polkit prompt and the dash desktop. Use when editing a .qml file for Quickshell, restarting or debugging a quickshell instance, reading its log, or capturing one without taking the user's focus.
---

# Quickshell

Instances: `quickshell -c bar` and `quickshell -c polkit` (dotfiles `home/hypr/.config/quickshell/`, started from `hyprland.lua`) and dash (`~/projects/dash`, which has its own CLAUDE.md). The package is AUR `quickshell-git`: Quickshell 0.3.2 ignores Hyprland's `changeworkspaceid`, so after `workspaces.lua` renumbers with `change_id` the bar loses window icons and dash draws over windows. Upstream 4befab5 fixes it; the user chose to stay on `-git` (2026-11-12).

## Run and reload

- Run `qs list --all` before editing a config the user may be running. Read an instance's log with `qs log --pid <pid>` (add `-r "*.debug=true"` for debug lines).
- Hot reload stops without an error after a few saves (seen on stow-symlinked files; cause not proven). After each save, look for "Reloading configuration..." in the log. If it is missing, restart: `qs kill -i <id>`, then `hyprctl dispatch 'hl.dsp.exec_cmd("quickshell -c bar")'` (the Lua config rejects `hyprctl dispatch exec`). dash restarts with `dash show`.
- Start a config as `quickshell -c <name>`, never `qs -c`: `dash stop` runs `pkill -x qs`.
- A reload caught halfway through a multi-file edit logs errors, such as a ReferenceError for an id the next edit adds. Judge the log after the last edit.
- A new `.qml` in a stowed config is "not a type" until it is stowed (`stow --no-folding -d ~/dotfiles/home -t ~ hypr`); in dash, `make install`.
- After a Qt update, the AUR hook's `quickshell --private-check-compat` warning means `paru -S quickshell-git` must run again (the user, in a real terminal), then restart bar, polkit and dash.

## QML traps

- Never name an id `left`, `right`, `top`, `bottom`, `horizontalCenter`, `verticalCenter` or `baseline`: inside a child's binding the name resolves to the child's own anchor line ("Cannot read property 'x' of undefined"). `status` is risky too (Image and Loader have it).
- Never name a function after an Item property (`focus`, `visible`, `enabled`, `state`, `opacity`). The property wins, and the call throws "is not a function" only when it runs, so only the log shows it.
- A tray icon's `IconThemePath` is read as one flat folder holding a file named exactly as the icon. Apps that ship a hicolor theme there, or files with an extension, get the missing-icon square without an error; the bar's `TrayIcon.qml` looks those up file by file.
- Child processes outlive a crashed Quickshell. Start a long-running one under `setpriv --pdeathsig TERM`.
- A harness needs the current `HYPRLAND_INSTANCE_SIGNATURE`. A long-lived shell keeps the old one after a Hyprland restart, and Hyprland IPC then fails with ServerNotFoundError; take the newest directory in `$XDG_RUNTIME_DIR/hypr`.

## Capture without taking focus

- `QT_QPA_PLATFORM=offscreen` renders on Qt's software scene graph even with a display set (`QSG_INFO=1` prints "Loading backend software"), so shader items (`RectangularShadow`, `MultiEffect`) draw nothing. It is fine for layout, not for judging depth or shadows.
- For a capture with the real GPU renderer on the live session, run a harness whose `PanelWindow` is 1x1, `color: "transparent"`, `mask: Region {}`, `WlrLayershell.layer: WlrLayer.Background`, `keyboardFocus: WlrKeyboardFocus.None`, with a namespace no layer rule matches. Put the stage item outside the window (`x: 1`, full size) and call `grabToImage` on it. It shows nothing and takes no focus, and it avoids the hidden-workspace rule, which wakes `workspaces.lua` packing and dash.
