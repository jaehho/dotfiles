# dash

The data side of the bar's dash panel (dotfiles `home/hypr/.config/quickshell/bar/Dash*.qml`, Super+D): samplers into a SQLite archive, and `dash-data`, which the panel and the bar's alert glyph read. The panel's own rules are dotfiles `.claude/rules/dash-panel.md`. The desktop overlay, its `dash` CLI and the `dash-live` feed were retired 2026-11-18 (git history before that date has them).

## Traps

- `bin/dash-data board` is cached 30 s in /tmp; don't trust it as "now" when verifying. Tests: `uv run --no-project --with pytest pytest tests`
- `dash-llm` reads the Claude Code OAuth token (`~/.claude/.credentials.json`) read-only; Claude Code owns refresh, so an expired token skips until the next local CC run. The statusline hook (dotfiles `home/claude/.claude/hooks/statusline.js`) never sees burn from other machines.
- State is `~/.local/state/dash/state.db`, the long-term archive (OpenRouter keeps 30 days, Claude Code deletes transcripts after 30).

## Data-quality keys

- OpenRouter `/activity` needs `OPENROUTER_MANAGEMENT_KEY` in `~/.config/openrouter.env`; without it only `/key` totals exist.
- In `~/.config/dash/prefs`: `SHOW_SCOPED_QUOTAS=1` shows the Opus/Sonnet weekly rows (always archived in `claude_limits.scoped`); `IGNORE_FAILED=unit,unit` hides units that fail on every normal day so a new failure is the first red thing.
- `ccusage` must be on PATH (npm global). Cost figures are list-price equivalents; the real Max constraint is the rate-limit percentages.

## Issues

Read the relevant `gotcha` issues (`gh issue list --label gotcha --state all`) before touching hyprland dispatch, env gates or Process restarts. Decisions use label `decision`. Headline: dispatch via `hl.dsp.*` only (#5).
