# Global Preferences

## Environment

- **Detect the shell before using shell syntax.** Check `$SHELL` (or `echo $0`) instead of assuming bash. Features like `export FOO=bar`, `source file.sh`, brace expansion, and `[[ ... ]]` are not portable across shells. Prefer POSIX-portable commands, or explicitly note which shell a snippet targets.
- **Detect the distro before using package commands.** Read `/etc/os-release` or use `command -v` to find the installed package manager. Don't assume any particular one is available.
- **Never use sudo.** Failed sudo attempts can lock me out of my system. If a task genuinely requires privileged access, stop and ask me to run the command myself — I can use the `!` REPL prefix in Claude Code to feed the output back.

## Commands You Give Me to Run

**Default: run commands yourself with the Bash tool.** Don't hand me a command and ask me to run it just because it's convenient — that wastes a round trip. Only delegate to me when you genuinely cannot run the command yourself, e.g.:

- It requires `sudo` or other privileged access
- It needs an interactive TTY (login flows, REPLs, editors, password prompts)
- It needs to run in my shell session, not a subprocess (sourcing env, activating contexts)
- It would otherwise hang, prompt, or fail under your tool harness

**When you do need to delegate**, do not list the commands inline for me to copy-paste. Instead, write them to a temporary shell script at `/tmp/hsperfdata_jaeho/<descriptive-name>.sh`. The script should:

- Start with `set -euo pipefail` (for bash) or equivalent strict mode to fail fast
- Print progress messages so I can see what step is running
- Handle expected failure modes (check `command -v foo` before using it, guard against existing state, etc.)
- Be idempotent where possible — safe to re-run if part of it fails
- Exit cleanly with a meaningful status message

Then tell me the path and how to invoke it (e.g. `sudo bash /tmp/hsperfdata_jaeho/foo.sh`, or `sh`/`python`/etc). This is more robust than copy-pasting a block of commands, especially for anything touching system state.

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
