# Zotero plugins

Open Claude at **this directory** (`~/projects/zotero`) for all Zotero plugin
work so memories and shared docs stay in one project. Each child is its own
git repo (separate GitHub releases): `zotero-citegraph/` (citation graph) and
`zotero-tray/` (tray icon instead of quitting). Both are plain-JS bootstrap
plugins with no TypeScript or scaffold, so the MCP's `zotero_scaffold_*`
tools are unused. `make help` lists each repo's targets.

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

## zotero-dev MCP

Project-scoped in `.mcp.json`; talks Firefox RDP to the **test instance only**
(`ZOTERO_RDP_PORT=6100`).

- The bridge XPI (`mcp-rdp@zotero.org`, `tools/`) is installed into the test
  profile by `zotero-citegraph/scripts/test-zotero-setup.sh`. Never install it
  into the user's daily Zotero: it serves privileged JS eval.
- Start the test Zotero first (`make check`, or
  `zotero -profile … -datadir … -no-remote`); the MCP cannot start it.
- Debug the bridge via `<test profile>/mcp-rdp-events.log`.

## Gotchas

Shared Zotero 10 install, API, and live-test traps are closed `gotcha` issues
here: `gh issue list -R jaehho/zotero --label gotcha --state all --search <term>`.
Plugin-specific ones live in each plugin's repo. Reopen one that recurs; file
new traps there, not in files.
