# Working on wonlab

You are a Claude Code session on wonlab, the owner's home server, running as `jaeho` (uid 1002, in the `docker` group). The owner attaches to you with `tmux attach -t ome-dev` over ssh, or through Remote Control in the Claude app, and may not be watching: say what you did and what they should check, in this session. These rules are the owner's laptop rules, cut to what applies here (2026-11-23).

## The host

- `jaewon0907` owns the box and may use all its RAM and CPU; never cap or disturb that account.
- Never run sudo. Root work is a reviewed script staged in `~jaeho/<task>/` with the exact `sudo` command for the owner, who runs it in their own terminal; a dry run first, then an install that checks a sha, validates, reloads and keeps a rollback.
- Never print any part of a token, password or env. Never `source` a secrets file. Use `docker inspect` only with `-f` and named fields that hold no env.
- Stop a process by the PID you recorded or by exact name (`pkill -x`), never `pkill -f`.
- What runs here, and is not yours to change without the owner: the Docker services in `/Totoro/Docker/` (Caddy, Pi-hole, Headscale, Jellyfin and the rest), Odysseus, Open WebUI, and OpenClaw (container `openclaw`, kept with no jobs to compare its UI; never turn its crons, heartbeat or Telegram on). Host notes from the owner's wonlab skill are in `~/projects/notes/wonlab/`; they were written for a laptop session reaching wonlab over ssh, and here you are already on it.
- ome, the project you work on, runs as the user service `ome` from `~/ome`, which only its `deploy/wonlab/deploy.sh` writes; never edit `~/ome` or run uv there. Its workspace (`~/.local/share/ome/workspace`), state (`~/.local/state/ome`) and secrets (`~/.config/ome`) are live data.
- `~/dotfiles` is the owner's laptop dotfiles. This host stows its `tmux`, `nvim`, `fish`, `git`, `theme` and `wonlab` packages (without `btop.conf`), and the first interactive fish of each day fast-forwards it and restows them (`dotfiles-pull`). This file and ome's CLAUDE.md live in its `home/wonlab/projects/`. Edit dotfiles here as on the laptop, following `~/dotfiles/CLAUDE.md`: commit to `main` and push right after; a file only wonlab needs goes in `home/wonlab/`. Host-only settings go outside it, such as git's `safe.directory` in `~/.config/git/config`.
- Skills: `~/.claude/skills/` links gui-testing and writing-functions into `~/dotfiles`, and impeccable into its clone in `~/.claude/skills-sources/pbakaus`.

## Choices

- Python is uv (`uv sync`, `uv run`), never pip or a hand-activated venv. Line length is PEP 8: 79 for code, 72 for comments and docstrings (ruff `E501`, `W505`). Dataframes: polars.
- Prose is not hard-wrapped: a paragraph in a README, doc or note is one line.

## Working

- Read files, logs and command output yourself. Don't build a fix for a cause you haven't proven: add logging that pins it down first, then fix what it shows.
- Unfamiliar or possibly new names are lookup prompts: check the installed source, `--help` or docs before asserting, and say what remains unverified.
- Exercise the path the owner will see, or say which narrower thing you checked.
- Writing that goes out under the owner's name (issue and PR text, comments, mail): read `~/projects/writing/CLAUDE.md` and `STYLE.md` first and work in that repo; pull before and push after.
- Google services go through `gog`, with `--readonly` unless the owner asks for a change; never send mail.
- To test or screenshot the web app, use headless Chrome (`google-chrome --headless=new --remote-debugging-port=0 --user-data-dir=<scratch>`, port read from `<scratch>/DevToolsActivePort`); there is no display here. The `gui-testing` skill has the rest.

## Projects

- Commit in small commits; never discard uncommitted work. A task's first commit takes its real type (`feat(scope):`), follow-ups are `wip(scope):`.
- A task that needs a second commit gets a topic branch in a worktree under `~/projects/<repo>.wt/`; in a worktree, `unset VIRTUAL_ENV UV_PROJECT_ENVIRONMENT` before uv.
- Each branch gets an independent review by a subagent (give it the code and the owner's words, not your conclusions), then fixes. The owner approved merging once a review passes (2026-11-23): merge with `--no-ff` and a real message, so `git diff M^1 M` is the net change, delete the branch, push, then deploy and tell the owner what to check.
- Ask before anything that turns a service or job off, deletes data, or reaches outside wonlab in the owner's name.
- Tasks, gotchas and decisions are GitHub issues, never TODO files: label gotchas `gotcha` (symptom, evidence, recovery, verification) and decisions `decision` (closed once decided). Search both before changing broken behaviour.
- Add a test when a rule breaks silently and is cheap to check. Don't test style or prose.
- When a change touches several similar things, make it in one first and wait for the owner.
- Before an upstream issue or PR: read CONTRIBUTING and the templates, search existing threads, match their style; open PRs as drafts.
