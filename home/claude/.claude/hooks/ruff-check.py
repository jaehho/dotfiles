#!/usr/bin/env python3
"""PostToolUse hook: run ruff check on the project after Python edits.

Reads tool-input JSON from stdin. If the edited file is `.py`/`.pyi`,
runs `ruff check` on the project root (so cross-file issues — unused
exports, F811 collisions — are caught). Falls back to file-scoped if
no project root can be located. Silent + exit 0 on clean; exit 2 with
details on stderr otherwise.

A hash-based cache at $XDG_CACHE_HOME/claude-hooks/ruff-cache.json
(default ~/.cache) skips redundant runs when the project state hasn't
changed since the last successful invocation.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

TIMEOUT_S = 30
RUFF_BIN = "ruff"
CACHE_DIR = Path(
    os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
) / "claude-hooks"
CACHE_FILE = CACHE_DIR / "ruff-cache.json"


def project_root(start: Path) -> Path | None:
    for parent in [start, *start.parents]:
        if (parent / "pyproject.toml").exists() or (parent / ".git").exists():
            return parent
    return None


def fingerprint(target: Path) -> str:
    """Hash of all .py/.pyi mtimes under target + ruff config files."""
    h = hashlib.sha256()
    try:
        result = subprocess.run(
            [RUFF_BIN, "--version"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        h.update(result.stdout.encode())
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    if target.is_file():
        try:
            st = target.stat()
            h.update(f"{target}:{st.st_mtime_ns}:{st.st_size}".encode())
        except OSError:
            pass
        return h.hexdigest()

    for sub in sorted(target.rglob("*")):
        if not sub.is_file():
            continue
        name = sub.name
        if not (name.endswith((".py", ".pyi")) or name in ("pyproject.toml", "ruff.toml", ".ruff.toml")):
            continue
        if ".venv" in sub.parts or "node_modules" in sub.parts or ".git" in sub.parts:
            continue
        try:
            st = sub.stat()
            h.update(f"{sub}:{st.st_mtime_ns}:{st.st_size}".encode())
        except OSError:
            continue
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


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path.endswith((".py", ".pyi")):
        return 0
    edited = Path(file_path)
    if not edited.exists():
        return 0

    root = project_root(edited.parent.resolve())
    target = root if root is not None else edited

    cache = load_cache()
    fp = fingerprint(target)
    if cache.get(str(target)) == fp:
        return 0

    try:
        result = subprocess.run(
            [RUFF_BIN, "check", "--output-format=concise", str(target)],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_S,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 0

    if result.returncode == 0:
        cache[str(target)] = fp
        save_cache(cache)
        return 0

    output = result.stdout.strip() or result.stderr.strip()
    if not output:
        return 0

    print(f"ruff: violations in {target}", file=sys.stderr)
    print(output, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
