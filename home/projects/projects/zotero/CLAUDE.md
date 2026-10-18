# Zotero plugins

Open Claude at **this directory** (`~/projects/zotero`) for all Zotero plugin
work so memories and shared docs stay in one project.

Each child is its own git repo (separate GitHub releases):

- `zotero-citegraph/` — citation graph plugin
- `zotero-tray/` — tray icon instead of quitting

## Shared rules

- Before handoff/commit: run that repo's `make check` (or `make test` if it has
  no live suite). Unit tests alone are not enough for plugin UI/API work.
  The live suite is the gate; the zotero-dev MCP is a probe for interactive
  debugging and does not replace it.
- Live Zotero tests use an **isolated** profile+data (`~/.local/share/citegraph-test`,
  `-profile`/`-datadir`/`-no-remote`). Never overwrite the user's installed
  plugin or kill their running Zotero.
- No focus steal: park the test window on a silent Hyprland workspace via
  `hyprctl eval` + `hl.window_rule` (`workspace = name:… silent`,
  `no_initial_focus`, `render_unfocused`). Capture inside the app; grim cannot
  see hidden workspaces.
- Release: `make release` in the plugin repo (tag + GitHub XPI + updates.json).
  Zotero auto-updates from `releases/latest/download/updates.json`. Side-loading
  an XPI into `extensions/` is not a release.

## Build

Plain-JS bootstrap plugins. `addon/` is the XPI body; `make xpi` zips it.
No TypeScript, no esbuild, no `zotero-plugin-scaffold` (the MCP's
`zotero_scaffold_*` tools are therefore unused). Hot-reload iteration is
`make dev` / `make run` (source proxy + `-purgecaches`).

## zotero-dev MCP

Project-scoped in `.mcp.json`: screenshot, DOM/styles, click/type, JS eval in
the privileged Zotero context, logs, plugin reload. It talks Firefox RDP to the
**test instance only** (`ZOTERO_RDP_PORT=6100`).

- Bridge XPI (`mcp-rdp@zotero.org`, `tools/`) is installed by
  `zotero-citegraph/scripts/test-zotero-setup.sh` into the test profile.
  Never install it into the user's daily Zotero — it serves privileged JS eval.
- Start the test Zotero first (`make check`, or
  `zotero -profile … -datadir … -no-remote`); the MCP cannot start it for you.
- Debug the bridge via `<test profile>/mcp-rdp-events.log`.

## Shared gotchas

Zotero 10 install, API, and live-test traps are closed `gotcha` issues in this
repo: `gh issue list -R jaehho/zotero --label gotcha --state all --search <term>`.
Plugin-specific ones are `gotcha` issues in each plugin's repo. Reopen one that
recurs; file new traps there, not in files.

## Commands (per repo)

`make test` · `make check` · `make xpi` · `make dev` / `make run` · `make release`
