# Global Preferences

## Environment

- **Detect the shell before using shell syntax.** Check `$SHELL` (or `echo $0`) instead of assuming bash. Features like `export FOO=bar`, `source file.sh`, brace expansion, and `[[ ... ]]` are not portable across shells. Prefer POSIX-portable commands, or explicitly note which shell a snippet targets.
- **Detect the distro before using package commands.** Read `/etc/os-release` or use `command -v` to find the installed package manager. Don't assume any particular one is available.
- **Never use sudo.** Failed sudo attempts can lock me out of my system. If a task genuinely requires privileged access, stop and ask me to run the command myself — I can use the `!` REPL prefix in Claude Code to feed the output back.

## Output Style

- **Default to terse.** A clear sentence beats a clear paragraph; a direct answer beats a heading-structured response.
- **Don't summarize what the diff already shows.** If I can read the change, I don't need a recap of it.
- **Don't narrate deliberation.** State conclusions and decisions; skip the "let me think about..." preamble.
- **Match response length to the task.** A yes/no question gets a one-line answer, not a sectioned report.
- **Plain, precise language.** Avoid dramatic phrasing and unnecessary jargon. Prefer shorter, more ordinary words when they carry the same information.
- **No emdashes.** Use periods, commas, semicolons, parentheses, or colons instead. Applies to prose you write for me (chat, commit messages, PR descriptions, code comments, docs).

## Authoring CLAUDE.md Files

When creating or editing any CLAUDE.md file:

- **Never hardcode details that change frequently.** Versions, file counts, dependency lists, env var lists, endpoint inventories, directory listings, line counts, etc. drift out of sync within days.
- **Point to the source of truth instead.** Give a command to run, a file to read, or a config location where the current information lives.
- **Examples:**
  - Instead of "We have 47 API endpoints" → "Run `make list-routes` to see current endpoints"
  - Instead of listing all env vars → "See `.env.example` for required environment variables"
  - Instead of "Using React 18.2.0" → "See `package.json` for current dependency versions"
  - Instead of a file tree → "Run `tree -L 2` or see the `Structure` section of the README"
- **What belongs in CLAUDE.md:** stable context — project philosophy, conventions, non-obvious constraints, where-to-find-what, commands to run, and gotchas that aren't visible from the code.
- **What does NOT belong in CLAUDE.md:** anything derivable from reading the current project state with a single command.

## MCP Tools

- Prefer `zotero_semantic_search` over `zotero_get_item_fulltext` when looking for specific content in papers. Only use fulltext when the entire paper content is actually needed.
