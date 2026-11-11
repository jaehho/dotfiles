"""Shared by the PostToolUse lint hooks: which tools, and how to reply.

ruff-check.py and ty-check.py prefer the ruff and ty a project locks,
in <root>/.venv/bin. The hooks run on every Python edit without
asking, so a binary there is used only when the venv was made on this
machine: <root> is in a git work tree and git tracks nothing under
.venv. A repo that commits a .venv (a cloned upstream, say) cannot
get its binary run this way; the hooks fall back to PATH's ruff and
skip ty there.

The hooks reply with hookSpecificOutput.additionalContext and exit 0:
Claude reads the text next to the tool result, and nothing is
blocked.
"""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

GIT_TIMEOUT_S = 5


def venv_tool(root: Path, name: str) -> Path | None:
    """`root`/.venv/bin/`name` when the hooks may run it, else None."""
    tool = root / ".venv" / "bin" / name
    if not os.access(tool, os.X_OK):
        return None
    if not venv_untracked(root):
        return None
    return tool


def venv_untracked(root: Path) -> bool:
    """Whether `root` is in a git work tree tracking nothing in .venv.

    False when git is missing or slow, or `root` is not in a work tree.
    """
    try:
        listed = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z", "--", ".venv"],
            capture_output=True,
            timeout=GIT_TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return listed.returncode == 0 and not listed.stdout


def context_json(text: str) -> str:
    """The PostToolUse output that hands `text` to Claude, unblocked."""
    return json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": text,
        }
    })
