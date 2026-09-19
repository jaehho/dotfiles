# Claude reconcile manifests

Source of truth for `scripts/claude-reconcile.sh`. Preview with `--dry-run`;
without `--interactive`, undeclared user-scope entries are removed. Converge
runs `--interactive` without a terminal, so it adds declared entries and defers
removals. See the script's `--help` for the manual removal flow.

## Files

- `mcp-servers.json` — standalone MCP servers written into `~/.claude.json`'s
  `mcpServers` block. Use `${VAR}` placeholders for secrets; the reconcile
  substitutes from `~/.config/claude-mcp-secrets.env` (gitignored).
- `marketplaces.json` — plugin marketplaces to register.
- `claude-json.json` — top-level `~/.claude.json` keys to enforce, for toggles
  with no `settings.json` equivalent. Undeclared keys are left alone.
- `skills-sources.json` — third-party skill repos to clone into
  `~/.claude/skills-sources/<source>/`, plus skill-name → clone-subpath mappings
  for `~/.claude/skills/`. Its `listing` block drives `settings.json` →
  `skillOverrides`: every skill the reconcile installs (third-party *and*
  `../skills/`) gets `listing.default`, unless named in `listing.overrides`.
  Its `managed` list names entries in `~/.claude/skills/` that Claude Code
  itself owns (today `synced`, the claude.ai skill-sync bucket): kept, never
  pruned, never a listing override.

The plugin set lives in the parent `settings.json` under `enabledPlugins` (a
plugin is "kept" iff its key is `true`; `false` keeps it installed but disabled;
absent means uninstall). claude.ai connectors follow the account, so a connector wanted on claude.ai but
not here is blocked by `deniedMcpServers` in `settings.json`; `/mcp` toggles are
per project and come back in every new directory. The reconcile prunes toggles
left behind by removed plugins and servers.

Custom skills authored locally live under
`../skills/<name>/` and are symlinked into `~/.claude/skills/<name>` by the
reconcile.

## Skill listing levels

`skillOverrides` values, from Claude Code: `on` (default if absent) · `name-only`
(name listed, description hidden) · `user-invocable-only` (hidden from the model,
`/name` still works) · `off` (hidden from both). We default to
`user-invocable-only` so an added skill costs no context and never auto-triggers
until it is asked for by name.

Per project, re-enable with `.claude/settings.local.json` — later scopes win:

```json
{ "skillOverrides": { "typst-author": "on" } }
```

`skillOverrides` does not apply to plugin-provided skills; Claude Code pins those
to `on`. Gate them with `enabledPlugins` in the parent `settings.json` instead.
