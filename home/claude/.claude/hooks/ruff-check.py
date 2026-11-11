#!/usr/bin/env python3
"""PostToolUse hook: run the project's ruff on the file Claude edited.

Reads tool-input JSON from stdin. If the edited file is `.py`/`.pyi`,
runs `ruff check` on that file alone: ruff lints file by file, and
findings in files the edit did not touch are not Claude's to fix.
The ruff is the project's own (`<root>/.venv/bin/ruff`, when
hook_common.venv_tool allows it), else the one on PATH, so where a
project locks ruff its version and config decide (ruff's default rule
set changed in 0.16 and again in 0.17). `--force-exclude` keeps the
project's excludes. Findings go back to Claude as additionalContext
with exit 0, which informs without blocking. Silent when clean.

In a repo that is not only mine (an origin outside github.com/LOGIN/,
or a commit by anyone but me, bots aside), only findings the edit
brought are shown. Ruff also lints the file as it is at HEAD, from
stdin, and a finding that version has too is left out, matched by
code, message and the flagged line's text, so shifted lines still
match. A finding the edit causes on a line it did not touch (say, an
import it left unused) is still shown. The other committers' code
keeps their lint.

Every run passes `--no-fix`: a project whose ruff config sets
`fix = true` would otherwise have the hook rewrite files, silently
when every finding is fixable.

A hash-based cache at $XDG_CACHE_HOME/claude-hooks/ruff-cache.json
(default ~/.cache) skips the run when the file, the ruff config files
between it and the project root, and the ruff version are unchanged
since the last clean run.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import NamedTuple

from hook_common import GIT_TIMEOUT_S, context_json, venv_tool

# Whose GitHub noreply address and github.com/<login>/ origin are mine.
MY_GITHUB_LOGIN = "jaehho"
MAX_LINES = 40
TIMEOUT_S = 30
RUFF_BIN = "ruff"
RUFF_CONFIGS = ("pyproject.toml", "ruff.toml", ".ruff.toml")
CACHE_DIR = Path(
    os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
) / "claude-hooks"
CACHE_FILE = CACHE_DIR / "ruff-cache.json"


def project_root(start: Path) -> Path | None:
    for parent in [start, *start.parents]:
        if (parent / "pyproject.toml").exists():
            return parent
        if (parent / ".git").exists():
            return parent
    return None


def ruff_version(ruff: str) -> str:
    """`ruff --version` output, or "" when it cannot be run."""
    try:
        result = subprocess.run(
            [ruff, "--version"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout


def config_candidates(edited: Path, root: Path | None) -> list[Path]:
    """Ruff config paths from the edited file's folder up to `root`."""
    folders = [edited.parent, *edited.parent.parents]
    if root is not None and root in folders:
        folders = folders[: folders.index(root) + 1]
    else:
        folders = folders[:1]
    return [folder / name for folder in folders for name in RUFF_CONFIGS]


def fingerprint(edited: Path, *, configs: list[Path], version: str) -> str:
    """Hash of the edited file, the config files and ruff's version."""
    h = hashlib.sha256(version.encode())
    for path in [edited, *configs]:
        try:
            st = path.stat()
        except OSError:
            continue
        h.update(f"{path}:{st.st_mtime_ns}:{st.st_size}".encode())
    return h.hexdigest()


def load_cache() -> dict[str, str]:
    try:
        return json.loads(CACHE_FILE.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(cache: dict[str, str]) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        CACHE_FILE.write_text(json.dumps(cache))
    except OSError:
        pass


def findings_text(
    output: str, *, shown_path: str, source: str, limit: int
) -> str:
    """Lines for Claude: a header, then up to `limit` lines of ruff."""
    lines = output.splitlines()
    if len(lines) > limit:
        lines = [*lines[:limit], f"... {len(lines) - limit} more lines"]
    return "\n".join([f"ruff ({source}): findings in {shown_path}", *lines])


class CannotCompare(Exception):
    """The edited file has no HEAD version, or ruff's JSON is unread."""


class SinceHead(NamedTuple):
    """Findings in the edited file, split against its HEAD version."""

    fresh: list[str]  # concise lines for findings HEAD's version lacks
    standing: int  # findings left out because HEAD's version has them


def git_output(root: Path, *args: str) -> bytes:
    """Stdout of `git -C root ARGS`; b"" when git fails."""
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True,
            timeout=GIT_TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return b""
    return result.stdout if result.returncode == 0 else b""


def git_text(root: Path, *args: str) -> str:
    """`git_output` decoded as text."""
    return git_output(root, *args).decode(errors="replace")


def foreign_origin(url: str, *, login: str) -> bool:
    """Whether `url` is a remote outside github.com/LOGIN/.

    No origin, or a local path (a makepkg build clone), is not one.
    """
    url = url.strip()
    if url == "" or url.startswith(("/", "./", "../", "file://")):
        return False
    mine = rf"github\.com[:/]{re.escape(login)}/"
    return re.search(mine, url) is None


def other_author(authors: str, *, my_email: str, login: str) -> bool:
    """Whether `git log --format=%an%x09%ae` output names someone else.

    Mine are `my_email` and LOGIN's GitHub noreply address. Authors
    named `...[bot]` (Copilot, Dependabot) are not people.
    """
    noreply = re.compile(
        rf"(\d+\+)?{re.escape(login)}@users\.noreply\.github\.com",
        re.IGNORECASE,
    )
    for line in authors.splitlines():
        name, _, email = line.partition("\t")
        if name.endswith("[bot]") or "[bot]@" in email:
            continue
        if email.lower() == my_email.lower() or noreply.fullmatch(email):
            continue
        return True
    return False


def shared_repo(root: Path, *, login: str) -> bool:
    """Whether the repo at `root` is not only mine (see the docstring
    at the top). Origin first: it settles most shared repos without
    reading the history."""
    origin = git_text(root, "remote", "get-url", "origin")
    if foreign_origin(origin, login=login):
        return True
    return other_author(
        git_text(root, "log", "--format=%an%x09%ae"),
        my_email=git_text(root, "config", "user.email").strip(),
        login=login,
    )


def ruff_json(
    ruff: str, source: bytes, *, filename: str, cwd: Path
) -> list[dict]:
    """Ruff's JSON findings for `source` linted as if it were
    `filename`. Raises CannotCompare when ruff fails."""
    try:
        result = subprocess.run(
            [ruff, "check", "--no-fix", "--output-format=json",
             "--force-exclude", "--stdin-filename", filename, "-"],
            input=source,
            capture_output=True,
            cwd=cwd,
            timeout=TIMEOUT_S,
            check=False,
        )
        findings = json.loads(result.stdout)
    except (OSError, subprocess.TimeoutExpired, ValueError) as err:
        raise CannotCompare(str(err)) from err
    if not isinstance(findings, list):
        raise CannotCompare("ruff's JSON is not a list")
    return findings


def finding_key(finding: dict, lines: list[str]) -> tuple[str, str, str]:
    """What names a finding in any version of a file: its code, its
    message and the stripped text of the line it flags."""
    row = (finding.get("location") or {}).get("row", 0)
    text = lines[row - 1].strip() if 0 < row <= len(lines) else ""
    return str(finding.get("code")), str(finding.get("message")), text


def new_findings(
    now: list[dict],
    before: list[dict],
    *,
    now_lines: list[str],
    before_lines: list[str],
) -> list[dict]:
    """The findings in `now` that `before` lacks. Keys are counted, so
    a second copy of a standing finding is new."""
    standing = Counter(finding_key(f, before_lines) for f in before)
    fresh = []
    for finding in now:
        key = finding_key(finding, now_lines)
        if standing[key] > 0:
            standing[key] -= 1
        else:
            fresh.append(finding)
    return fresh


def concise_line(finding: dict, *, shown_path: str) -> str:
    """One finding in the form of ruff's concise output."""
    location = finding.get("location") or {}
    where = f"{shown_path}:{location.get('row')}:{location.get('column')}"
    code = finding.get("code")
    fix = " [*]" if finding.get("fix") else ""
    rule = f"{code}{fix} " if code else ""
    return f"{where}: {rule}{finding.get('message')}"


def findings_since_head(ruff: str, edited: Path, root: Path) -> SinceHead:
    """`edited`'s findings split into those its HEAD version lacks and
    a count of those it has. Raises CannotCompare when git has no HEAD
    version of the file or ruff fails."""
    shown_path = os.path.relpath(edited, root)
    before_src = git_output(root, "show", f"HEAD:./{shown_path}")
    if not before_src:
        raise CannotCompare(f"no HEAD version of {shown_path}")
    try:
        now_src = edited.read_bytes()
    except OSError as err:
        raise CannotCompare(str(err)) from err
    now = ruff_json(ruff, now_src, filename=shown_path, cwd=root)
    before = ruff_json(ruff, before_src, filename=shown_path, cwd=root)
    fresh = new_findings(
        now,
        before,
        now_lines=now_src.decode(errors="replace").splitlines(),
        before_lines=before_src.decode(errors="replace").splitlines(),
    )
    return SinceHead(
        fresh=[concise_line(f, shown_path=shown_path) for f in fresh],
        standing=len(now) - len(fresh),
    )


def since_head_text(split: SinceHead) -> str:
    """The new findings, then a line on the standing ones left out."""
    if split.standing == 0:
        return "\n".join(split.fresh)
    note = (
        f"Left out {split.standing} finding(s) this file already had"
        " at HEAD: the repo is not only mine, so leave those."
    )
    return "\n".join([*split.fresh, note])


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path.endswith((".py", ".pyi")):
        return 0
    edited = Path(file_path).resolve()
    if not edited.exists():
        return 0

    root = project_root(edited.parent)
    local = venv_tool(root, "ruff") if root is not None else None
    ruff = str(local) if local is not None else RUFF_BIN

    cache = load_cache()
    fp = fingerprint(
        edited,
        configs=config_candidates(edited, root),
        version=ruff_version(ruff),
    )
    if cache.get(str(edited)) == fp:
        return 0

    try:
        result = subprocess.run(
            [ruff, "check", "--no-fix", "--output-format=concise",
             "--force-exclude", str(edited)],
            capture_output=True,
            text=True,
            cwd=root or edited.parent,
            timeout=TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 0

    if result.returncode == 0:
        cache[str(edited)] = fp
        save_cache(cache)
        return 0

    output = result.stdout.strip() or result.stderr.strip()
    if not output:
        return 0

    if root is not None and shared_repo(root, login=MY_GITHUB_LOGIN):
        try:
            split = findings_since_head(ruff, edited, root)
        except CannotCompare:
            pass  # an untracked file, say: every finding is new
        else:
            if not split.fresh:
                cache[str(edited)] = fp
                save_cache(cache)
                return 0
            output = since_head_text(split)

    print(context_json(findings_text(
        output,
        shown_path=os.path.relpath(edited, root or edited.parent),
        source="the project's .venv" if local is not None else "PATH",
        limit=MAX_LINES,
    )))
    return 0


if __name__ == "__main__":
    sys.exit(main())
