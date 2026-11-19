---
paths:
  - "home/hypr/**"
---

# Hyprland config

- Workspaces are 1–9, never 1–10: Super+N binds 1–9, so a workspace 10 can't be reached. `MAX_WORKSPACES = 9` in `screens.lua`; Super+0 walks its `slots_by_monitor`, and Tab and move-project read the 1–9 workspace rules it sets; scroll uses `m+1`/`m-1`; `workspace_swipe_create_new` is false; `workspace_pack.lua` `reclaim_strays` folds any id above 9 back into 1–9. Super+0 hops to the empty workspace (the scratchpad special workspace was removed 2026-10-31).
- The config is Lua, so `hyprctl dispatch exec` fails. Start a program with `hyprctl eval "hl.exec_cmd('...')"` or `hyprctl dispatch 'hl.dsp.exec_cmd("...")'`.
- If a window takes focus, record socket2 before changing a rule: `socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r l; do echo "$(date +%T.%3N) $l"; done` while repeating the action, then read the `activewindow`, `activespecial` and `urgent` lines. That is how the Playwright theft was found: `no_initial_focus` covers only the first map, and a new or selected tab asks for activation, which `misc:focus_on_activate` granted; the `playwright-browser` rule now sets `focus_on_activate = false`.
