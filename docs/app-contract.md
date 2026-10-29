# Desktop app contract

What the apps in `~/projects` share at their edges, so they work together and a new one starts from known answers. It applies in full to steno, asst, wallhelper, battery-log and reel, and to keylog, aw-watchers and dash where a section fits. It covers behavior at the boundaries: names, how apps call each other, running in the background, install, and dev safety. Each app picks its own language and toolkit.

An app that departs from a rule here has a gap. Track it as an issue in that app and close the gaps one app at a time. When a rule changes, change it here and open an issue in each app it leaves behind.

Owned elsewhere: live `make install`, `packaging/PKGBUILD`, root docs and issues are in `~/.claude/CLAUDE.md`. Desktop integration (hyprland.lua, waybar, units) lives in dotfiles (`~/dotfiles/CLAUDE.md`). How to test a GUI without taking the screen is the `gui-testing` skill.

## Names

- App ID: `dev.jaeho.<Name>` (`dev.jaeho.Steno`, `dev.jaeho.Asst`, `dev.jaeho.Wallhelper`). The desktop entry, the D-Bus name and the window class key on it, so an existing ID is never renamed, the lowercase Tauri ones (`dev.jaeho.battery-log`, `dev.jaeho.reel`) included.
- Commands: the repo name, lowercase. A daemon is `<name>d` (`asstd`, `battery-logd`, `keylogd`). A GTK client beside a Rust CLI is `<name>-gtk`.
- Environment variables start with `<NAME>_` (`STENO_`, `ASST_`, `BATTERY_LOG_`).
- Paths follow XDG, one folder per app named for the command: settings in `$XDG_CONFIG_HOME/<name>/`, the app's own databases and logs in `$XDG_STATE_HOME/<name>/`, the user's content in `$XDG_DATA_HOME/<name>/` (steno's sessions), per-login files in `$XDG_RUNTIME_DIR/<name>/` (asst's tray icons). Secrets go in the Secret Service (asst) or a `.env` in the config folder (steno).

## Between apps

- **One owner per piece of state.** Another app goes through the owner's interface, never its files or database. steno does not touch asst's cache, and asst does not watch steno's `todos.json`.
- **Calls go through the owner's CLI with `--json`.** The CLI works with no window open, can be faked in a test and switched off, and leaves the owner free to change its D-Bus API.
- **The `--json` output is a public API.** A field a consumer reads is only ever added, never renamed, removed or retyped. To change one, add the new field, move every consumer, then drop the old one.
- **The owner pins what consumers read.** The owner keeps a sample output for each command a consumer calls and a test that checks its fields. The consumer's fake is built from that sample, not from a shape the consumer wrote itself.
- **Filing is idempotent.** A record one app files in another carries a source key `<app>:<id>` (`asst add --source steno:<session>/<key>`), and filing again with the same key returns the same record. The filer keeps the owner's ID; when the two disagree, the owner is right.
- **Changes are announced.** An owner with a daemon emits a `Changed` D-Bus signal, with no arguments, after its state changes (asstd: `Changed` on interface `dev.jaeho.Asst1`, bus name `dev.jaeho.Asst.Daemon`). A consumer re-reads through the CLI when it fires, folding a burst into one read, and polls only as a fallback while its view is on screen.
- **A missing or slow owner degrades the consumer, never breaks it.** With the owner's command not on `PATH`, the consumer goes on with its own copy. Every call has a timeout. A partial answer (one of two reads failed) is no answer, and never clears local state.
- **A kill switch guards real data.** A consumer that writes into another app's data honours `<NAME>_NO_<OWNER>` (`STENO_NO_ASST`). Any non-empty value, `0` included, turns those writes off, so a scratch run cannot reach real lists.
- **Opening another app's object** calls a GApplication action on its app ID through `org.freedesktop.Application.ActivateAction` (asst's `open-task` with a task href, steno's `open-session` with a session name), passing the activation token so the window may take focus. A D-Bus service file lets the bus start the app when it is not running. The CLI wraps it (`asst open ID`, `steno show`).

Links today:

| Consumer | Owner | What it calls | Consumer code |
|---|---|---|---|
| steno | asst | `add --literal --source --list`, `ls`, `completed -n`, `show`, `done`, `reopen`, `edit --list`, `edit --title`, `rm`, `lists`, `open`; the `Changed` signal | `steno/src/steno/asstlink.py` |
| dash | asst | `today`, `ls LIST`, `lists` | `dash/bin/dash-data` |
| asst | ActivityWatch | `/api/0/buckets`, `/api/0/query` on port 5600, buckets that aw-watchers fills | `asst/crates/asst-core/src/track.rs` |

## In the background

- **The window is a view.** Work that has to keep going (listening, sync, reminders, sampling) lives in a daemon or in the app process held without a window, so closing the window loses nothing.
- **`--background`** starts the app with no window. Start at login is a switch in the app and a CLI command, and it writes one XDG autostart entry. A line in the compositor's config that runs `<command> --background` counts as on: the app reports it and leaves it for the user to remove. On this machine those lines are in dotfiles' `hyprland.lua`.
- **Tray:** a StatusNotifierItem. Left click brings up the window, middle click does the app's main action (steno records, asst opens quick add), right click opens the menu, which ends with Quit. Its `IconThemePath` is a folder with an `index.theme` (asst writes one to `$XDG_RUNTIME_DIR/asst/icons`, steno ships one in its package); without the index, waybar does not search the folder.
- **Closing** hides the window while a tray icon or a bar module shows the app is still running, and quits otherwise, so the app never runs with nothing to click. Ctrl+Q quits. When quitting stops something the user counts on (steno's listener), it asks first and says what stops.
- **Bar module:** `<name> bar` streams waybar JSON, one line per change, with `text`, `tooltip` and a `class` per state (asst: `overdue`, `due`, `clear`, `offline`, `error`). The module's config lives in dotfiles' waybar config.
- **Notifications** carry their actions as buttons, and a click opens what the notification is about through the app action above.

## Window keys

- Ctrl+W closes the window (the app keeps running, as above), Ctrl+Q quits, Ctrl+F searches in an app with a search, and Ctrl+? shows every shortcut. These work from a text field too.
- Single-letter keys (asst's `j`, `k`, `x`) act only while focus is outside a text field. Where they are on, `?` also shows every shortcut.

## Install and run

- Every app has these `make` targets: `help`, `run`, `test`, `lint`, `install`, `uninstall`, `package`, `clean`. `uninstall` removes the launcher, the desktop entry and the icons, and leaves config, state and data.
- `make install` installs `scripts/<name>-live` as the command. It runs the checkout. A Rust app runs the last release build and rebuilds in the background for the next launch; a failed build never replaces a working binary, and its output goes to `$XDG_STATE_HOME/<name>-live.log`. A Python app runs the tree on the system Python (with dependencies, in a uv venv made with `--system-site-packages`), because `python-gobject`, GTK and libadwaita come from the distribution; `uv tool install` cannot see them.
- `<NAME>_SRC` points the launcher at another tree. `<NAME>_NO_REBUILD=1` skips the rebuild, for scripts that call the command often. `scripts/test-<name>-live` pins the launcher's behavior.

## Development and tests

- Nothing in a test or a dev run touches real data or the real display. A GUI app has a dev entry point that runs it with isolated XDG folders, a private session bus that cannot start the installed daemon, and its window off the real display (asst's `scripts/dev`, steno's `start_broadway` in its tests).
- The window can be driven and captured through app actions, so a test or an agent can check it without a pointer (asst's `drive`, `snapshot` and `dump` in `devel.rs`).
- A test that writes or deletes refuses to run against real data (wallhelper's `make test`).
