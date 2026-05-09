# Claude reconcile manifests

Source of truth for `make claude-reconcile`. The reconcile script enforces strict
parity: anything installed at user scope but not declared here is removed.

## Files

- `mcp-servers.json` — standalone MCP servers written into `~/.claude.json`'s
  `mcpServers` block. Use `${VAR}` placeholders for secrets; the reconcile
  substitutes from `~/.config/claude-mcp-secrets.env` (gitignored).
- `marketplaces.json` — plugin marketplaces to register.
- `skills-sources.json` — third-party skill repos to clone into
  `~/.claude/skills-sources/<source>/`, plus skill-name → clone-subpath mappings
  for `~/.claude/skills/`.

The plugin set lives in the parent `settings.json` under `enabledPlugins` (a
plugin is "kept" iff its key is `true`; `false` keeps it installed but disabled;
absent means uninstall). Custom skills authored locally live under
`../skills/<name>/` and are symlinked into `~/.claude/skills/<name>` by the
reconcile.
