# dash

Control-room dashboard shown as the desktop: dotfiles' hyprland.lua starts it at login (`dash show`). Always on, no toggle. Super+D is workspace hop only (empty slot, then back); it never turns dash off. While a workspace with windows covers it the panels unmap (samplers keep running). Waybar stays up (`ExclusionMode.Normal`). No hypridle integration. The overlay is transparent: hyprpaper's wallpaper shows through the glass cards; test mode draws its own backdrop so self-captured screenshots keep it.

## Traps

- `bin/dash-data board` is cached 30 s in /tmp; don't trust it as "now" when verifying. `health` is fresh.
- `bin/dash-spec` must capture with `stream.capture.sink`, never `--target <sink>.monitor`: PipeWire does not resolve that name and pw-cat silently records the microphone instead. Tests: `uv run --no-project --with pytest --with numpy pytest tests`
- The live dash reads symlinks in `~/.local/share/dash`: rerun `make install` after adding, renaming or moving a qml file. `make screenshot` and `make screenshot-headless` run the working tree and need no install.
- `dash-llm` reads the Claude Code OAuth token (`~/.claude/.credentials.json`) read-only; Claude Code owns refresh, so an expired token skips until the next local CC run. The statusline hook (dotfiles `home/claude/.claude/hooks/statusline.js`) never sees burn from other machines.
- State is `~/.local/state/dash/state.db`, the long-term archive (OpenRouter keeps 30 days, Claude Code deletes transcripts after 30).

## Data-quality keys

- OpenRouter `/activity` needs `OPENROUTER_MANAGEMENT_KEY` in `~/.config/openrouter.env`; without it only `/key` totals exist.
- MiMo plan % needs `api-platform_serviceToken` + `userId`, read from Firefox session cookies when logged in at platform.xiaomimimo.com; else `MIMO_COOKIE` in `~/.config/mimo.env`. The `tp-` key cannot read quota.
- In `~/.config/dash/prefs`: `SHOW_SCOPED_QUOTAS=1` shows the Opus/Sonnet weekly rows (always archived in `claude_limits.scoped`); `IGNORE_FAILED=unit,unit` hides units that fail on every normal day so a new failure is the first red thing.
- `ccusage` must be on PATH (dotfiles `packages/npm.txt`). Cost figures are list-price equivalents; the real Max constraint is the rate-limit percentages.

## Issues

Read the relevant `gotcha` issues (`gh issue list --label gotcha --state all`) before touching hyprland dispatch, env gates, Process restarts, or `make screenshot`. Decisions use label `decision`. Headlines: dispatch via `hl.dsp.*` only (#5); special workspaces are dispatchable only from binds (#6); dash is always-on, Super+D is workspace hop only (#15).
