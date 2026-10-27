# Global preferences

## Choices

- Keep system behavior close to distro/upstream defaults.
- I use fish, Firefox, and nvim. Python is uv (`uv sync`, `uv run`), never pip or a hand-activated venv.
- Dataframes: polars, not pandas; convert where a library hands back pandas.
- Python line length is PEP 8: 79 for code, 72 for comments and docstrings. Lint it (ruff `E501`, `W505` with `max-doc-length = 72`).
- Prose is not hard-wrapped: a paragraph in a markdown cell, README, doc, or note is one line, and a list item is one line.

## Working

- Files in `~/.claude/` may be stow symlinks. Edit their targets under `~/dotfiles/home/claude/.claude/`.
- Read files, logs, and command output yourself; don't ask me to paste them. Make config changes by writing files, not GUI walkthroughs.
- Don't build a fix for a cause you haven't proven. Add logging that pins it down first, then fix what it shows.
- Writing that goes out under my name (mail, messages, issue and PR text, posts): read `~/projects/writing/CLAUDE.md` and `STYLE.md` first and work in that repo, not `/tmp`.
- Google services (Gmail, Calendar, Drive, Docs) go through the `gog` CLI; `gog auth list` shows the accounts, `gog --help` the commands. Pass `--readonly` unless I ask for a change, and never send mail without asking.
- `!` commands have no TTY, so anything that prompts (sudo, `ssh -t`, pickers) needs a separate terminal.
- Unfamiliar or possibly-new names are lookup prompts, not inference prompts; assume anything may postdate training data. Check docs or source before asserting, and say what remains unverified. This includes the defaults and behavior of tools I already know (a linter's default rule set, a flag's default): read the docs or run the tool's own CLI, not memory. For cited works, check Zotero before web search.
- Library docs, in this order: the installed source and `--help`; the clones in `~/projects/upstream` (`git -C <dir> describe --tags --always` gives a clone's version); context7, whose docs can be newer than the installed version. If a library whose prose docs you need is missing and its source is in a git repo, shallow-clone it at the installed version's tag into `~/projects/upstream` and say what you cloned.
- Exercise the path I will hear, see, or click, or say which narrower thing you checked.
- Before running a sync, reconcile, or apply script, read all of its dry-run output and apply only the changes I asked for.

## Projects

- Add a test when a rule breaks silently and is cheap to check (network boundaries, path literals, imported helpers). Don't test style, prose, or section conventions; research needs room to move.
- When a change touches several similar things (notebooks, modules, the same bug in several places), make it in one instance first and wait for confirmation before rolling it out to the rest.
- Commit work in small commits instead of leaving it uncommitted. A task's first commit takes its real type (`fix(scope):`); only follow-up commits are `wip(scope):`. Never discard uncommitted work (`git checkout`/`restore` on a file).
- A task (a feature, bug fix, or experiment) that needs a second commit gets a topic branch: move the first commit onto it, and reset the default branch only if that commit is unpushed. Merge when the task is complete to my satisfaction: if it looks done, say it is ready to merge and wait for my confirmation — silence is not yes. On confirm, merge with `--no-ff` and a real message, so `git diff M^1 M` is the net change, then delete the topic branch.
- Tasks, gotchas, and design decisions live in GitHub issues, never in TODO.md, ISSUES.md, or DESIGN_LOG.md. Label gotchas `gotcha` (symptom, evidence, recovery, verification; open until believed fixed, reopen on recurrence) and decisions `decision` (what and why; closed once decided). Before changing broken behavior, search both labels open and closed.
- Root docs, each only when it has content: `README.md` (install, use, what it is and how it works), `CHANGELOG.md` (release notes, for published packages), `CLAUDE.md` (agent rules and pointers only). Projects with a UI that the impeccable skill works on also keep `PRODUCT.md` and `DESIGN.md`, which it reads by name.
- Meetings steno recorded about a project are in its `notes/meetings/` (generated, read-only; start at `README.md` there).
- My apps run live from their checkouts: `make install` writes launchers under `~/.local` (no sudo, no `/usr` package), so a merge ships by rerunning it or relaunching. Their `packaging/PKGBUILD` feeds the AUR; never install it here (dotfiles #67).
- Writing CLAUDE.md, rules, skills, or READMEs: read `~/dotfiles/docs/writing-claude-files.md` (sources and dated checks).
- Before an upstream issue or PR: read `CONTRIBUTING.md` and templates and follow them; search open and closed issues and PRs; comment on an existing thread rather than filing. Find who writes the good ones (list issues by label through the tracker API, count authors, compare median description length), read three to five of the same kind, and match their title style, structure, and length. Put long evidence in your own issue or an attachment, not the report; keep the prose simple and add detail only when the repro needs it. Open PRs as drafts unless I say otherwise.

## Memory

Auto-memory is project-local.
