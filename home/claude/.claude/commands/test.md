---
description: Run the project's test suite and report results
---

Run the test suite for the current project, then summarize results.

Use this command:
- `uv run pytest -x --tb=short -q` if a `uv.lock` exists in the project root
- `pytest -x --tb=short -q` otherwise

Behavior:
- On pass: report counts (e.g. "71 passed").
- On fail: show the failing test names and short tracebacks, then propose a fix if the cause is obvious.
- If pytest isn't configured in this project (no `tests/` dir and no `[tool.pytest.ini_options]` in `pyproject.toml`), say so and stop.

`$ARGUMENTS` (if provided) is passed through to pytest — e.g. `/test tests/test_rk4.py -v` runs a single file verbosely.
