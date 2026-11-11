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

A hash-based cache at $XDG_CACHE_HOME/claude-hooks/ruff-cache.json
(default ~/.cache) skips the run when the file, the ruff config files
between it and the project root, and the ruff version are unchanged
since the last clean run.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from hook_common import context_json, venv_tool

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
            [ruff, "check", "--output-format=concise", "--force-exclude",
             str(edited)],
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

    print(context_json(findings_text(
        output,
        shown_path=os.path.relpath(edited, root or edited.parent),
        source="the project's .venv" if local is not None else "PATH",
        limit=MAX_LINES,
    )))
    return 0


if __name__ == "__main__":
    sys.exit(main())
