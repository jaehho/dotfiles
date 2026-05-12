#!/usr/bin/env python3
"""PostToolUse hook: run pyright on Python edits and surface errors to Claude.

Reads tool-input JSON from stdin (Claude Code hook contract). If the edited
file is Python and the project has pyright configured, runs pyright on the
project root and emits errors to stderr (exit 2 → blocking-feedback to Claude).
Silent + exit 0 on clean runs or when pyright doesn't apply.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

MAX_DIAGS = 30
TIMEOUT_S = 30
PYRIGHT_BIN = "pyright"


def project_root(start: Path) -> Path | None:
    """Walk up from `start` looking for a project with pyright config."""
    for parent in [start, *start.parents]:
        pyproject = parent / "pyproject.toml"
        if pyproject.exists():
            try:
                if "[tool.pyright]" in pyproject.read_text():
                    return parent
            except OSError:
                pass
        if (parent / "pyrightconfig.json").exists():
            return parent
    return None


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
    root = project_root(edited.parent)
    if root is None:
        return 0

    try:
        result = subprocess.run(
            [PYRIGHT_BIN, "--outputjson"],
            capture_output=True,
            text=True,
            cwd=root,
            timeout=TIMEOUT_S,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 0

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return 0

    diags = [
        d for d in data.get("generalDiagnostics", []) if d.get("severity") == "error"
    ]
    if not diags:
        return 0

    lines = [f"pyright: {len(diags)} error(s) in {root}"]
    for d in diags[:MAX_DIAGS]:
        f = d["file"]
        try:
            rel = os.path.relpath(f, root)
        except ValueError:
            rel = f
        ln = d["range"]["start"]["line"] + 1
        rule = d.get("rule", "")
        msg = d["message"].split("\n", 1)[0]
        suffix = f" ({rule})" if rule else ""
        lines.append(f"  {rel}:{ln}  {msg}{suffix}")
    if len(diags) > MAX_DIAGS:
        lines.append(f"  ... {len(diags) - MAX_DIAGS} more")

    print("\n".join(lines), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
