# Global Preferences

## Environment

- Detect the shell before using shell syntax. Bash-only features that bite in fish/zsh/sh: `[[ ... ]]`, brace expansion, `source`, `export FOO=bar`.
- Detect the distro before using package commands.
- Never use sudo. For privileged commands, write a robust shell script to `/tmp/<name>.sh` rather than giving me a list to copy-paste.

## Output Style

Default to terse and match response length to the task. Don't summarize what the diff already shows or narrate deliberation. Plain American English; light on emdashes.

## My project conventions

In my projects, `Makefile` lists common commands and `TODO.md` tracks current work. Check them when relevant; skip for quick questions or non-project work.

## Authoring CLAUDE.md Files

CLAUDE.md should be terse and scalable — it shouldn't grow as the project grows. Skip hedges and elaboration. Don't hardcode anything derivable from current project state — point to a command, file, or config instead. In project CLAUDE.md files, don't repeat anything already covered by the global CLAUDE.md. Examples:

- Instead of listing all env vars → "See `.env.example`"
- Instead of "Using React 18.2.0" → "See `package.json`"
- Instead of a file tree → "Run `tree -L 2`"
