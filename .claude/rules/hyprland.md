---
paths:
  - "home/hypr/**"
---

# Hyprland config

- Workspaces are 1–9, never 1–10: Super+N binds 1–9, so a workspace 10 can't be reached. `MAX_WORKSPACES = 9` in `screens.lua`; Super+0 walks its `slots_by_monitor`, and Tab and move-project read the 1–9 workspace rules it sets; scroll uses `m+1`/`m-1`; `workspace_swipe_create_new` is false; `workspace_pack.lua` `reclaim_strays` folds any id above 9 back into 1–9. Super+0 hops to the empty workspace (the scratchpad special workspace was removed 2026-10-31).
- The config is Lua, so `hyprctl dispatch exec` fails. Start a program with `hyprctl eval "hl.exec_cmd('...')"` or `hyprctl dispatch 'hl.dsp.exec_cmd("...")'`.
- If a window takes focus, record socket2 before changing a rule: `socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r l; do echo "$(date +%T.%3N) $l"; done` while repeating the action, then read the `activewindow`, `activespecial` and `urgent` lines. That is how the Playwright theft was found: `no_initial_focus` covers only the first map, and a new or selected tab asks for activation, which `misc:focus_on_activate` granted; the `playwright-browser` rule now sets `focus_on_activate = false`.
- A rule's `match` value (class, title, namespace) is an RE2 full match (`RegexMatchEngine.cpp`, 0.57.2): `^bar-notification` matches no longer name, and nothing reports a rule that never applies. Spell each name whole or end the pattern with `.*`.
- After any write to `hyprland.lua`, run `luac -p` on it, then `hyprctl reload`, then `hyprctl configerrors`. The file watcher can fire on the truncated file mid-write and load half of it ("unfinished string near <eof>"), and nothing guarantees a second reload once the write finishes (2026-11-23: one watcher reload in the log for many edits). An atomic rename is no fix: it swaps the inode the watcher holds.
