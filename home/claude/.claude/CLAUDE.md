# Global preferences

## Communication

- Be terse; match length to the task. Plain American English. No em dashes: use commas, parentheses, semicolons, or two sentences. Don't narrate deliberation or repeat the diff.
- Write plainly: no dramatic phrasing, rhetorical questions, or "this, not that" constructions.
- Give the skeptic's case first. No reflexive affirmation or concede-then-reaffirm; feedback on work should be mostly critique.
- When teaching me something new, define each term precisely at first use. An expert audience means terser, not more advanced notation; match the level of the source I learned from.
- Write documents, notebooks, and comments for a reader who has not seen our conversation. My questions and confusions get answered in the reply; they do not become caveats, clarifications, or "X is not assumed" remarks in the work. Put in the work only what a cold reader needs to follow it.

## Choices

- Prefer maintained open-source, standalone tools over suite-bound ones.
- Keep system behavior close to distro/upstream defaults. When a fix adds a layer over earlier fixes, consider removing layers first.
- I use fish, Firefox, and nvim. Python is uv (`uv sync`, `uv run`), never pip or a hand-activated venv.
- Dataframes: polars, not pandas; convert where a library hands back pandas.
- Python line length is PEP 8: 79 for code, 72 for comments, docstrings, and flowing text (markdown cells included). Lint it (ruff `E501`, `W505` with `max-doc-length = 72`). Break prose at thoughts (after a sentence, comma, or semicolon), one thought per line, not at the width alone.
- Colors: before choosing or changing any color (UI, charts, notebooks, themes), read `~/dotfiles/docs/color-preferences.md` and follow it. Update that file only when taste changes, not for a one-off surface.

## Working

- Files in `~/.claude/` may be stow symlinks. Edit their targets under `~/dotfiles/home/claude/.claude/`.
- Read files, logs, and command output yourself; don't ask me to paste them. Make config changes by writing files, not GUI walkthroughs.
- `!` commands have no TTY, so anything that prompts (sudo, `ssh -t`, pickers) needs a separate terminal.
- Unfamiliar or possibly-new names are lookup prompts, not inference prompts; assume anything may postdate training data. Check docs or source before asserting, and say what remains unverified. This includes the defaults and behavior of tools I already know (a linter's default rule set, a flag's default): read the docs or run the tool's own CLI, not memory. For cited works, check Zotero before web search.
- Exercise the path I will hear, see, or click, or say which narrower thing you checked.

## Projects

- Add a test when a rule breaks silently and is cheap to check (network boundaries, path literals, imported helpers). Don't test style, prose, or section conventions; research needs room to move. State a rule first and add a test after it has been broken in practice.
- When a change touches several similar things (notebooks, modules, the same bug in several places), make it in one instance first and wait for confirmation before rolling it out to the rest.
- Commit work in small WIP commits instead of leaving it uncommitted. Never discard uncommitted work (`git checkout`/`restore` on a file).
- Tasks, gotchas, and design decisions live in GitHub issues, never in TODO.md, ISSUES.md, or DESIGN_LOG.md. Label gotchas `gotcha` (symptom, evidence, recovery, verification; open until believed fixed, reopen on recurrence) and decisions `decision` (what and why; closed once decided). Before changing broken behavior, search both labels open and closed.
- Root docs, each only when it has content: `README.md` (install, use, what it is and how it works), `CHANGELOG.md` (release notes, for published packages), `CLAUDE.md` (agent rules and pointers only). Projects with a UI that the impeccable skill works on also keep `PRODUCT.md` and `DESIGN.md`, which it reads by name.
- Before an upstream issue or PR: read `CONTRIBUTING.md` and templates and follow them; search open and closed issues and PRs; comment on an existing thread rather than filing. Keep the prose simple; add detail only when the repro needs it. Open PRs as drafts unless I say otherwise.

## Memory

Auto-memory is project-local. At the end of a session, propose promoting cross-project rules here instead of leaving them in one project.
