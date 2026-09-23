# Global preferences

## Communication and choices

- Be terse; match length to the task. Plain American English, light on em dashes. Don't narrate deliberation or repeat the diff.
- Prefer maintained open-source tools, especially standalone tools with multiple-account support.
- Keep system behavior close to distro/upstream defaults. When a fix adds a layer over earlier fixes, consider removing layers first.
- My browser is Firefox.

## Execution

- Detect the shell before using shell-specific syntax and the distro before package commands. Use an explicit Bash script when Bash is needed.
- Never run sudo. Prepare a robust executable `/tmp/<name>.sh` for privileged work, with a root check and clear invocation; the owner runs it.
- Avoid `pkill -f`/`pgrep -f` patterns that match the invoking shell. Use an exact process name or an identified PID; long process names may be truncated.
- Files in `~/.claude/` may be stow symlinks. Edit their targets under `~/dotfiles/home/claude/.claude/`; write-and-rename can replace a symlink with a plain file.

## Verification

- Unfamiliar or possibly-new names are lookup prompts, not inference prompts; assume anything may postdate training data. Check docs or source before asserting, and say what remains unverified.
- Reproduce the reported state. For layout bugs, measure rendered bounds through the ancestor chain and inspect the installed theme's cascade, including generic classes and toolkit defaults. Check rest, hover, and focus separately.
- Treat causes as hypotheses until a controlled change fixes the measured symptom. Parsing, reload success, and a clean exit do not establish correct behavior. Say exactly what was tested.
- If I report a fix failed, reopen the diagnosis and correct stale memory. Failed workarounds do not establish that a fix is impossible.
- Isolate tests from real data and input focus. For notifications, retain IDs returned by `Notify`; never clean up by count, list position, or log database row ID. Restarting swaync clears its history.
- A private D-Bus can still activate installed user services with real data. Set isolated `XDG_DATA_HOME`, `XDG_DATA_DIRS`, and config paths before `dbus-run-session`. Track child processes as well as launchers.

## GUI testing techniques

- To test without taking my screen or keyboard, use a Hyprland rule through `hyprctl eval`: `workspace = "name:x silent"`, `no_initial_focus`, `render_unfocused`. Capture inside the app; grim cannot see hidden workspaces.
- GTK4 Broadway: `gtk4-broadwayd :N`, `GDK_BACKEND=broadway BROADWAY_DISPLAY=:N`; HTTP port is `8080 + N`. Wayland/layer-shell apps need an isolated test adaptation. Set an explicit browser viewport; leave a short gap between pointer motion and a press.
- Headless browser fallback: `google-chrome-stable --headless=new --remote-debugging-pipe` uses CDP on fds 3/4, NUL-framed. Move pipe ends above 4 before mapping them; an open `confirm()` can block input until answered. `firefox-developer-edition --headless --marionette` is another option; top-level page `let`s require an injected `<script>`. A plain `--screenshot` may precede async rendering.

## Project conventions

- Check `Makefile` for common commands and GitHub issues (`gh issue list`) for current work when relevant; tasks live only in issues, never in TODO.md files; skip for quick questions or non-project work.
- Root docs, each only when it has content: `README.md` (install and use), `PRODUCT.md` (what it is and must never become), `DESIGN.md` (how it works now), `DESIGN_LOG.md` (dated decisions and why; append, don't rewrite), `ISSUES.md` (gotchas with evidence), `CHANGELOG.md` (release notes, for published packages), `CLAUDE.md` (agent rules and pointers only).
- A persistent desktop app of mine has a StatusNotifierItem tray icon and starts hidden from `hyprland.lua`'s tray block. A bar-specific module is not a substitute.
- Package lists live in `dotfiles/packages/` (`arch/` is a directory of `NN-*.txt`). Converge with `dotfiles sync`, never `make sync` (that name is gone). Status is `dotfiles`.

## Email

Use `gog` (Gmail API; account aliases in `~/.config/gogcli/config.json`). Sending is intentionally blocked. Its file-keyring password comes from `~/.config/environment.d/60-gog.conf`, loaded by fish and the systemd user manager.

For every draft written, revised, or reviewed, put the text both in chat and in `~/projects/mail-digest/drafts/`, following that repo's `session.md`. Pull Gmail-only drafts into files first so I can edit them in nvim.

## Maintaining instructions

Keep CLAUDE.md terse and scalable: preferences, constraints, and pointers. Reference `.env.example`, `package.json`, commands, or configs instead of duplicating derivable state. Project instructions should not repeat global ones; detailed recipes belong in troubleshooting docs. That doc is `ISSUES.md` at the repo root, created with the first gotcha and pointed to from CLAUDE.md.

Auto-memory is project-local. Promote cross-project preferences and traps here without asking, and mention the edit. Replace stale guidance rather than appending contradictions; record observations separately from unverified explanations.
