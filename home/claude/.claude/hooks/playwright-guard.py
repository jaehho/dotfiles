#!/usr/bin/env python3
"""PreToolUse hook: keep the Playwright MCP browser off the screen.

Matched on mcp__plugin_playwright_playwright__.*. Playwright MCP opens
a headed Chrome. The class `playwright` makes Hyprland open it on a
silent workspace (hyprland.lua, rule playwright-browser). Without that class
Chrome is `google-chrome`, matches no rule, opens on the current
workspace and takes focus and keyboard.

The class comes from PLAYWRIGHT_MCP_CONFIG (settings.json env), which the
MCP server reads from its own environment. Claude Code spawns the server
once per session, so a session started before the setting existed, or
without it, runs an unconfigured server for its whole life. This hook
walks from itself up to the claude process, finds the playwright-mcp
server below it, and reads that server's /proc environ. It blocks
(exit 2, reason on stderr) unless the server has the config and the
config sets --class=playwright. browser_close always passes so a stray
window can still be closed.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

SERVER_MARK = "playwright-mcp"
CONFIG_ENV = "PLAYWRIGHT_MCP_CONFIG"
WANT_ARG = "--class=playwright"
ALWAYS_ALLOWED = "mcp__plugin_playwright_playwright__browser_close"

HOW = (
    "Load the gui-testing skill and test headless (headless Chrome with "
    "--remote-debugging-pipe, or headless Firefox with --marionette), or "
    "ask the owner to restart this Claude session so the Playwright MCP "
    "server starts with the settings.json env. Do not take the owner's "
    "focus or keyboard."
)


def ppid_of(pid: int) -> int:
    """Parent pid from /proc/<pid>/stat (comm can hold spaces)."""
    stat = Path(f"/proc/{pid}/stat").read_text()
    return int(stat.rsplit(")", 1)[1].split()[1])


def find_claude(start: int) -> int | None:
    """Nearest ancestor of `start` whose comm is `claude`."""
    pid = start
    while pid > 1:
        try:
            if Path(f"/proc/{pid}/comm").read_text().strip() == "claude":
                return pid
            pid = ppid_of(pid)
        except (OSError, ValueError, IndexError):
            return None
    return None


def descendants(root: int) -> list[int]:
    """All pids below `root`, from one scan of /proc."""
    children: dict[int, list[int]] = {}
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            children.setdefault(ppid_of(int(entry.name)), []).append(
                int(entry.name)
            )
        except (OSError, ValueError, IndexError):
            continue
    found, queue = [], [root]
    while queue:
        for child in children.get(queue.pop(), []):
            found.append(child)
            queue.append(child)
    return found


def servers_below(claude: int) -> list[int]:
    """Processes below claude whose command line names the MCP server."""
    out = []
    for pid in descendants(claude):
        try:
            argv = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
        except OSError:
            continue
        if any(SERVER_MARK in a.decode(errors="replace") for a in argv):
            out.append(pid)
    return out


def env_of(pid: int) -> dict[str, str]:
    raw = Path(f"/proc/{pid}/environ").read_bytes().split(b"\0")
    pairs = (e.decode(errors="replace").partition("=") for e in raw if e)
    return {k: v for k, _, v in pairs}


def config_problem(path: str) -> str | None:
    """Why the config file would not give the silent class, or None."""
    try:
        config = json.loads(Path(path).read_text())
    except (OSError, ValueError) as err:
        return f"{path} is unreadable ({err})"
    browser = config.get("browser", {})
    args = browser.get("launchOptions", {}).get("args", [])
    if WANT_ARG not in args:
        return f"{path} does not set {WANT_ARG} in launchOptions.args"
    if config.get("extension") or browser.get("cdpEndpoint"):
        return f"{path} attaches to an existing browser"
    return None


def problem(start: int) -> str | None:
    """Why the session's Playwright server is unsafe, or None."""
    claude = find_claude(start)
    if claude is None:
        return "no claude process found above this hook"
    servers = servers_below(claude)
    if not servers:
        return f"no {SERVER_MARK} process found below claude ({claude})"
    for pid in servers:
        try:
            path = env_of(pid).get(CONFIG_ENV)
        except OSError as err:
            return f"cannot read the environment of pid {pid} ({err})"
        if not path:
            return (
                f"the {SERVER_MARK} server (pid {pid}) has no {CONFIG_ENV}, "
                "so its Chrome has class google-chrome and opens on the "
                "current workspace with focus"
            )
        bad = config_problem(path)
        if bad:
            return bad
    return None


def main() -> int:
    try:
        tool = json.load(sys.stdin).get("tool_name", "")
    except ValueError:
        tool = ""
    if tool == ALWAYS_ALLOWED:
        return 0
    why = problem(os.getppid())
    if why is None:
        return 0
    print(f"Blocked {tool or 'Playwright MCP'}: {why}. {HOW}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
