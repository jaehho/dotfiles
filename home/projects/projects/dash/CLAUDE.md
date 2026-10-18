# dash

Control-room dashboard shown as the desktop: dotfiles' hyprland.lua starts
it at login (`dash show`). Always on — no toggle. Super+D is workspace hop
only (empty slot, then back to where you were); it never turns dash off.
Seeing dash is landing on an empty workspace. While a workspace with
windows covers it the panels unmap (samplers keep running).
Waybar stays up: the panel uses `ExclusionMode.Normal`, so it sits below the
bar's exclusive zone. No hypridle integration. Transparent overlay: hyprpaper's live wallpaper shows through
the panel (hyprpaper sits below it at the background layer) and the glass
cards tint it; test mode draws its own backdrop so self-captured
screenshots keep it. Panels click through to their tools on top of it.

## Pieces

- `bin/dash` — launcher: show (ensure running) / stop
- `bin/dash-collect` — 1-min system sampler (systemd timer)
- `bin/dash-llm` — 1-min OpenRouter + z.ai + Claude-limit (ccusage only when a transcript changed, at most every 10 min)
  + MiMo token-plan snapshots (systemd timer). MiMo cookie comes live from
  Firefox (`api-platform_*` are session cookies in sessionstore*.jsonlz4);
  `MIMO_COOKIE` in `~/.config/mimo.env` is the fallback.
- `bin/dash-data` — read side the QML polls (`health` fresh, `board`
  cached 30 s in /tmp — don't trust it as "now" when verifying)
- `live/` — the Rust live feed (`make install` builds it): 100 ms JSON
  snapshots while the dashboard is open (live graphs, network rates). GPU via NVML, in-process. `make parity` diffs it against
  `dash-data health`.
- `bin/dash-spec` — notes-and-beats text stream for the visualizer, from
  the default sink's monitor (numpy; `dash-cava` is the old cava bridge,
  cava is no longer the feed). Capture must use `stream.capture.sink`,
  never `--target <sink>.monitor`: PipeWire does not resolve that name and
  pw-cat silently records the microphone instead. Tests:
  `uv run --no-project --with pytest --with numpy pytest tests`
- `test/headless.qml` — `make screenshot-headless`: the dashboard in a plain
  window on Qt's offscreen platform (no compositor, no screen, no Hyprland IPC)
- `qml/` — the Quickshell UI; palette is Catppuccin Mocha in `qml/Theme.qml`
  (the theme file was retired in dotfiles). The live dash reads symlinks in
  `~/.local/share/dash`: rerun `make install` after adding, renaming or
  moving a qml file. `make screenshot` and `make screenshot-headless` run
  the working tree and need no install.

State: `~/.local/state/dash/state.db` (the long-term archive — OpenRouter
serves only 30 days and Claude Code deletes transcripts after 30 days).
Claude Max limits come from `dash-llm` polling
`api.anthropic.com/api/oauth/usage` with the local Claude Code OAuth token
(`~/.claude/.credentials.json`, read-only — Claude Code owns refresh; an
expired token skips until the next local CC run). The statusline hook
(dotfiles `home/claude/.claude/hooks/statusline.js`) also appends rows, but
only fires for official-API sessions on this machine, so it never sees burn
from other machines or z.ai sessions.

## Keys to data quality

- OpenRouter `/activity` needs `OPENROUTER_MANAGEMENT_KEY` in
  `~/.config/openrouter.env`; without it only `/key` totals exist.
- MiMo plan % needs `api-platform_serviceToken` + `userId`. Auto-read from
  Firefox session cookies when you are logged in at platform.xiaomimimo.com;
  else set `MIMO_COOKIE` in `~/.config/mimo.env`. The `tp-` key cannot read quota.
- Model-scoped weekly rows (Opus/Sonnet) are always archived in
  `claude_limits.scoped`; show them with `SHOW_SCOPED_QUOTAS=1` in
  `~/.config/dash/prefs` (off by default).
- A unit that is failed on every normal day (it would keep the SYSTEM
  failed-unit line red) goes in `IGNORE_FAILED=unit,unit` in the same
  prefs file; alarms stay rare so a new failure is the first red thing.
- `ccusage` must be on PATH (dotfiles `packages/npm.txt`).
- Cost figures are list-price equivalents; the real Max constraint is the
  rate-limit percentages.

## Issues

Gotchas are GitHub issues labeled `gotcha`: run
`gh issue list --label gotcha --state all` and read the relevant ones before
touching hyprland dispatch, env gates, Process restarts,
or `make screenshot`. Decisions use label `decision`. Headlines: dispatch via
`hl.dsp.*` only (#5); special workspaces are dispatchable only from binds
(#6); dash is always-on, Super+D is workspace hop only (#15).
