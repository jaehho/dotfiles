#!/usr/bin/env python3
"""PostToolUse hook: run ruff check on edited Python files.

Reads tool-input JSON from stdin. Runs `ruff check <file>` on the edited
file. Silent + exit 0 on clean; exit 2 with details on stderr otherwise.
Skips non-Python files. Uses ruff's default rule set unless the project
configures `[tool.ruff]` in pyproject.toml.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

TIMEOUT_S = 15
RUFF_BIN = "ruff"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path.endswith((".py", ".pyi")):
        return 0
    if not Path(file_path).exists():
        return 0

    try:
        result = subprocess.run(
            [RUFF_BIN, "check", "--output-format=concise", file_path],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_S,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 0

    if result.returncode == 0:
        return 0

    output = result.stdout.strip() or result.stderr.strip()
    if not output:
        return 0

    print(f"ruff: violations in {file_path}", file=sys.stderr)
    print(output, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
