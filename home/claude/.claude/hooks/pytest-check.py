#!/usr/bin/env python3
"""Stop hook: run the project's pytest suite if Python files were modified.

Triggers when Claude tries to end a turn. Skips if no modified .py files
in the working tree (avoids running on chats / non-code turns). Exits 2
with failure summary on stderr if tests fail — forces Claude to continue
and address. Respects stop_hook_active to prevent infinite loops.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

TIMEOUT_S = 120
MAX_OUTPUT_CHARS = 4000


def project_root(start: Path) -> Path | None:
    for parent in [start, *start.parents]:
        if (parent / "pyproject.toml").exists():
            return parent
    return None


def has_pytest(root: Path) -> bool:
    try:
        text = (root / "pyproject.toml").read_text()
    except OSError:
        return False
    if "[tool.pytest" in text:
        return True
    return (root / "tests").is_dir() or (root / "test").is_dir()


def modified_python_files(root: Path) -> list[str]:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    paths: list[str] = []
    for line in out.splitlines():
        path = line[3:].strip()
        if path.endswith((".py", ".pyi")):
            paths.append(path)
    return paths


def pytest_cmd(root: Path) -> list[str]:
    if (root / "uv.lock").exists():
        return ["uv", "run", "pytest", "-x", "--tb=short", "-q"]
    return ["pytest", "-x", "--tb=short", "-q"]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get("stop_hook_active"):
        return 0

    cwd = Path(payload.get("cwd") or ".").resolve()
    root = project_root(cwd)
    if root is None or not has_pytest(root):
        return 0

    if not modified_python_files(root):
        return 0

    try:
        result = subprocess.run(
            pytest_cmd(root),
            capture_output=True,
            text=True,
            cwd=root,
            timeout=TIMEOUT_S,
        )
    except FileNotFoundError:
        return 0
    except subprocess.TimeoutExpired:
        print(f"pytest: timed out after {TIMEOUT_S}s in {root}", file=sys.stderr)
        return 2

    if result.returncode == 0:
        return 0

    blob = (result.stdout + result.stderr).strip()
    if len(blob) > MAX_OUTPUT_CHARS:
        blob = "...\n" + blob[-MAX_OUTPUT_CHARS:]
    print(f"pytest failed in {root}:", file=sys.stderr)
    print(blob, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
