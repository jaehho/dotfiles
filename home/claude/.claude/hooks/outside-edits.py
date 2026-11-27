#!/usr/bin/env python3
"""Tell Claude which files changed while it was not working.

The user edits between Claude's turns: review comments marked
`@claude`, fixes of their own. Claude must commit those alone before
editing the file (global CLAUDE.md, Projects), and that rule is easy
to skip when nothing points at the change. This hook points at it.

One script, by event:

- Stop, and PreToolUse on AskUserQuestion: snapshot the uncommitted
  files (a hash each) of every repo this session works in. A turn
  ends at Stop; a question waits for the user, who may edit
  meanwhile.
- UserPromptSubmit, and PostToolUse on AskUserQuestion: compare the
  repos with the snapshot. A file whose content changed since (newly
  changed, changed again, or back to HEAD) changed outside Claude's
  work, most likely by the user. Claude gets the list, the `@claude`
  lines in those files, and a reminder, as additionalContext.
- PostToolUse on Edit, Write, MultiEdit, NotebookEdit and Bash: add
  the repos the tool touched to the session's list: the edited
  file's, or those of the absolute paths under $HOME in the Bash
  command. The session's working directory is always on it. A
  subagent's call (its input has ``agent_id``) also snapshots those
  repos again, so its edits count as Claude's work.

Informs only: it exits 0 and never blocks. With no snapshot yet (a
session's first prompt), the uncommitted files of the working
directory's repo are listed as changes from before the session.
An edit the user makes while Claude is working lands in the next
snapshot unreported. State is per session in
$XDG_STATE_HOME/claude-hooks/outside-edits/ (default ~/.local/state);
files older than STATE_DAYS are pruned at Stop. Errors go to
outside-edits.log there.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
import traceback
from pathlib import Path

GIT_TIMEOUT_S = 5
# A repo with more uncommitted files than this is not snapshotted:
# hashing them would slow every prompt.
MAX_FILES = 500
# Files larger than this are compared by size and mtime, not content.
MAX_HASH_BYTES = 20_000_000
MAX_LISTED = 20
MAX_COMMENTS = 30
MAX_COMMENT_CHARS = 200
MARKER = "@claude"
# The marker as a word: not "context7@claude-plugins-official".
MARKER_WORD = re.compile(r"(?<![\w.-])@claude(?![\w-])")
STATE_DAYS = 14
TRACKED_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit", "Bash"}
QUESTION_TOOL = "AskUserQuestion"
STATE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))
) / "claude-hooks" / "outside-edits"
# An absolute or ~ path in a shell command, up to a space, quote or
# shell operator.
PATH_IN_COMMAND = re.compile(r"""(?<![\w.~/-])(~?/[^\s"'`;|&()<>]+)""")


def git(root: Path, *args: str) -> bytes | None:
    """Stdout of `git -C root ARGS`, or None when git fails."""
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True,
            timeout=GIT_TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout if result.returncode == 0 else None


def repo_root(path: Path) -> str:
    """The work tree holding `path` (an existing folder), or ""."""
    out = git(path, "rev-parse", "--show-toplevel")
    return out.decode().strip() if out else ""


def nearest_folder(path: Path) -> Path | None:
    """`path` if it is a folder, else its nearest existing parent."""
    for candidate in [path, *path.parents]:
        if candidate.is_dir():
            return candidate
    return None


def paths_in_command(command: str) -> list[Path]:
    """The absolute paths under $HOME that a shell command names."""
    home = Path.home()
    found = []
    for raw in PATH_IN_COMMAND.findall(command):
        path = Path(os.path.expanduser(raw.rstrip(".,:")))
        if path == home or home not in path.parents:
            continue
        found.append(path)
    return found


def file_hash(path: Path) -> str:
    """A fingerprint of a file's content, or "deleted"."""
    try:
        stat = path.stat()
    except OSError:
        return "deleted"
    if stat.st_size > MAX_HASH_BYTES:
        return f"size:{stat.st_size}:mtime:{stat.st_mtime_ns}"
    try:
        return hashlib.sha1(path.read_bytes()).hexdigest()
    except OSError:
        return "unreadable"


def uncommitted(root: str) -> dict[str, str] | None:
    """Each uncommitted file of the repo (untracked ones included,
    ignored ones not) and its hash; None when git fails or the repo
    has more than MAX_FILES of them."""
    out = git(
        Path(root), "status", "--porcelain=v1", "-z", "--untracked-files=all"
    )
    if out is None:
        return None
    entries = out.decode(errors="replace").split("\0")
    paths = []
    skip_next = False
    for entry in entries:
        if skip_next:
            skip_next = False
            continue
        if len(entry) < 4:
            continue
        status, path = entry[:2], entry[3:]
        if "R" in status or "C" in status:
            # A rename's source path follows; it no longer exists.
            skip_next = True
        if path.endswith("/"):
            continue
        paths.append(path)
    if len(paths) > MAX_FILES:
        return None
    return {path: file_hash(Path(root) / path) for path in paths}


def snapshot(roots: list[str]) -> dict[str, dict]:
    """HEAD and the uncommitted files' hashes of each repo."""
    taken = {}
    for root in roots:
        files = uncommitted(root)
        if files is None:
            continue
        head = git(Path(root), "rev-parse", "HEAD")
        taken[root] = {
            "head": head.decode().strip() if head else "",
            "files": files,
        }
    return taken


def changed_since(before: dict, now: dict, root: str) -> list[str]:
    """The files whose content changed between two snapshots of a repo.

    A file uncommitted in `before` and clean in `now` changed only if
    HEAD stayed put; otherwise it was committed.
    """
    old, new = before["files"], now["files"]
    changed = [path for path, h in new.items() if old.get(path) != h]
    if before["head"] == now["head"]:
        changed += [
            path
            for path in old
            if path not in new
            and old[path] != file_hash(Path(root) / path)
        ]
    return sorted(changed)


def marker_lines(root: str, paths: list[str]) -> list[str]:
    """`path:line: text` for each line holding MARKER in the files."""
    found = []
    for path in paths:
        try:
            data = (Path(root) / path).read_bytes()
        except OSError:
            continue
        if b"\0" in data[:8192] or len(data) > MAX_HASH_BYTES:
            continue
        lines = data.decode(errors="replace").splitlines()
        for number, line in enumerate(lines, start=1):
            if MARKER_WORD.search(line):
                text = line.strip()[:MAX_COMMENT_CHARS]
                found.append(f"{path}:{number}: {text}")
    return found


def report(changes: dict[str, list[str]], *, first: bool) -> str:
    """The text for Claude: the changed files, their @claude lines,
    and what to do before editing them."""
    when = (
        "before this session (uncommitted)"
        if first
        else "outside your work since your last turn or question, most "
        "likely by the user"
    )
    lines = [f"Files changed {when}:"]
    comments = []
    for root, paths in changes.items():
        shown = paths[:MAX_LISTED]
        more = len(paths) - len(shown)
        lines.append(f"- {root}: " + ", ".join(shown))
        if more:
            lines.append(f"  ... and {more} more")
        comments += [f"{root}/{line}" for line in marker_lines(root, paths)]
    if comments:
        lines.append(f"{MARKER} lines in them:")
        lines += [f"- {line}" for line in comments[:MAX_COMMENTS]]
        if len(comments) > MAX_COMMENTS:
            lines.append(f"  ... and {len(comments) - MAX_COMMENTS} more")
    lines.append(
        "Before you edit one of these files, commit the user's changes "
        "in it alone (global CLAUDE.md, Projects). Address each "
        f"{MARKER} comment and say how."
    )
    return "\n".join(lines)


def state_path(session: str) -> Path:
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", session) or "unknown"
    return STATE_DIR / f"{safe}.json"


def load_state(session: str) -> dict:
    try:
        return json.loads(state_path(session).read_text())
    except (OSError, ValueError):
        return {}


def save_state(session: str, state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = state_path(session)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(path)


def prune_states() -> None:
    cutoff = time.time() - STATE_DAYS * 86400
    for path in STATE_DIR.glob("*.json"):
        try:
            if path.stat().st_mtime < cutoff:
                path.unlink()
        except OSError:
            pass


def add_root(state: dict, folder: Path | None) -> None:
    """Put the repo holding `folder` on the session's list, once."""
    if folder is None:
        return
    known = state.setdefault("folder_roots", {})
    key = str(folder)
    if key not in known:
        known[key] = repo_root(folder)
    root = known[key]
    roots = state.setdefault("roots", [])
    if root and root not in roots:
        roots.append(root)


def touched_roots(state: dict, payload: dict) -> list[str]:
    """Add the repos a tool call touched to the session's list, and
    give them."""
    tool_input = payload.get("tool_input") or {}
    if payload.get("tool_name") == "Bash":
        folders = [
            nearest_folder(path)
            for path in paths_in_command(tool_input.get("command") or "")
        ]
    else:
        edited = tool_input.get("file_path") or tool_input.get(
            "notebook_path"
        )
        folders = [nearest_folder(Path(edited))] if edited else []
    for folder in folders:
        add_root(state, folder)
    known = state.get("folder_roots", {})
    return sorted(
        {known.get(str(f), "") for f in folders if f is not None} - {""}
    )


def track(state: dict, payload: dict) -> None:
    """Add the repos a tool call touched; after a subagent's call,
    snapshot them again so its edits are not reported."""
    roots = touched_roots(state, payload)
    if payload.get("agent_id") and "snapshot" in state:
        state["snapshot"].update(snapshot(roots))


def compare(state: dict, now: dict) -> tuple[dict[str, list[str]], bool]:
    """The changed files per repo, and whether there was no snapshot
    (so every uncommitted file counts)."""
    before = state.get("snapshot")
    if before is None:
        every = {r: sorted(s["files"]) for r, s in now.items() if s["files"]}
        return every, True
    changes = {}
    for root, taken in now.items():
        if root not in before:
            continue
        paths = changed_since(before[root], taken, root)
        if paths:
            changes[root] = paths
    return changes, False


def context(event: str, text: str) -> str:
    output = {"hookEventName": event, "additionalContext": text}
    return json.dumps({"hookSpecificOutput": output})


def main() -> int:
    payload = json.load(sys.stdin)
    session = payload.get("session_id") or ""
    event = payload.get("hook_event_name") or ""
    tool = payload.get("tool_name") or ""
    state = load_state(session)
    cwd = payload.get("cwd")
    if cwd:
        add_root(state, nearest_folder(Path(cwd)))

    if event == "PostToolUse" and tool in TRACKED_TOOLS:
        track(state, payload)
        save_state(session, state)
        return 0

    roots = state.get("roots", [])
    if event == "Stop" or (event == "PreToolUse" and tool == QUESTION_TOOL):
        state["snapshot"] = snapshot(roots)
        save_state(session, state)
        if event == "Stop":
            prune_states()
        return 0

    if event == "UserPromptSubmit" or (
        event == "PostToolUse" and tool == QUESTION_TOOL
    ):
        now = snapshot(roots)
        changes, first = compare(state, now)
        state["snapshot"] = now
        save_state(session, state)
        if changes:
            print(context(event, report(changes, first=first)))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # noqa: BLE001 - a hook must never fail the turn
        try:
            STATE_DIR.mkdir(parents=True, exist_ok=True)
            with (STATE_DIR / "outside-edits.log").open("a") as log:
                log.write(time.strftime("%FT%T ") + traceback.format_exc())
        except OSError:
            pass
        sys.exit(0)
