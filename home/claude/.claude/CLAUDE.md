# Global preferences

## Choices

- Keep system behavior close to distro/upstream defaults.
- I use fish, Firefox, and nvim. Python is uv (`uv sync`, `uv run`), never pip or a hand-activated venv.
- Dataframes: polars, not pandas; convert where a library hands back pandas.
- Python line length is PEP 8: 79 for code, 72 for comments, docstrings, and flowing text (markdown cells included). Lint it (ruff `E501`, `W505` with `max-doc-length = 72`).

## Working

- Files in `~/.claude/` may be stow symlinks. Edit their targets under `~/dotfiles/home/claude/.claude/`.
- Read files, logs, and command output yourself; don't ask me to paste them. Make config changes by writing files, not GUI walkthroughs.
- `!` commands have no TTY, so anything that prompts (sudo, `ssh -t`, pickers) needs a separate terminal.
- Unfamiliar or possibly-new names are lookup prompts, not inference prompts; assume anything may postdate training data. Check docs or source before asserting, and say what remains unverified. This includes the defaults and behavior of tools I already know (a linter's default rule set, a flag's default): read the docs or run the tool's own CLI, not memory. For cited works, check Zotero before web search.
- Library docs, in this order: the installed source and `--help`; the clones in `~/projects/upstream` (`git -C <dir> describe --tags --always` gives a clone's version); context7, whose docs can be newer than the installed version. If a library whose prose docs you need is missing and its source is in a git repo, shallow-clone it at the installed version's tag into `~/projects/upstream` and say what you cloned.
- Exercise the path I will hear, see, or click, or say which narrower thing you checked.
- Before running a sync, reconcile, or apply script, read all of its dry-run output and apply only the changes I asked for.

## Projects

- Add a test when a rule breaks silently and is cheap to check (network boundaries, path literals, imported helpers). Don't test style, prose, or section conventions; research needs room to move.
- When a change touches several similar things (notebooks, modules, the same bug in several places), make it in one instance first and wait for confirmation before rolling it out to the rest.
- Commit work in small commits instead of leaving it uncommitted. A task's first commit takes its real type (`fix(scope):`); only follow-up commits are `wip(scope):`. Never discard uncommitted work (`git checkout`/`restore` on a file).
- A task that needs a second commit gets a branch. When the fix for a change just committed would be a second commit, whether I push back or you find the miss yourself (a lint error, a missed file), move the first commit onto `task/<slug>` (`task/<issue>-<slug>` when an issue exists) and commit follow-ups there. Reset the default branch back one commit only if that commit is unpushed; otherwise leave it and say so. If the tree has unrelated changes, stop and say so. Merge only when I say, with `--no-ff` and a real message, so `git diff M^1 M` is the net change. After a merge I ask for, delete the task branch with `git branch -d`. A new ask is a new task. A project's own workflow overrides this.
- Tasks, gotchas, and design decisions live in GitHub issues, never in TODO.md, ISSUES.md, or DESIGN_LOG.md. Label gotchas `gotcha` (symptom, evidence, recovery, verification; open until believed fixed, reopen on recurrence) and decisions `decision` (what and why; closed once decided). Before changing broken behavior, search both labels open and closed.
- Root docs, each only when it has content: `README.md` (install, use, what it is and how it works), `CHANGELOG.md` (release notes, for published packages), `CLAUDE.md` (agent rules and pointers only). Projects with a UI that the impeccable skill works on also keep `PRODUCT.md` and `DESIGN.md`, which it reads by name.
- Writing CLAUDE.md, rules, skills, or READMEs: read `~/dotfiles/docs/writing-claude-files.md` (sources and dated checks).
- Before an upstream issue or PR: read `CONTRIBUTING.md` and templates and follow them; search open and closed issues and PRs; comment on an existing thread rather than filing. Find who writes the good ones (list issues by label through the tracker API, count authors, compare median description length), read three to five of the same kind, and match their title style, structure, and length. Put long evidence in your own issue or an attachment, not the report; keep the prose simple and add detail only when the repro needs it. Open PRs as drafts unless I say otherwise.

## Memory

Auto-memory is project-local.
