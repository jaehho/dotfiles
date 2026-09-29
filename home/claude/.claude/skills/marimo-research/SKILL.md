---
name: marimo-research
description: Rules and checklist for writing or editing marimo notebooks used for research analysis (data collection, analysis, figures), where the code is the lab record. Use whenever creating, restructuring, or editing a research marimo notebook or a project's notebooks/ folder. Not for driving a live kernel (that is marimo-pair).
---

# Research marimo notebooks

The artifact is the code; outputs are secondary. A reader must be able to trace every number to a function, a file, and a stated choice. Repo-specific constants (stacks, product ids, seed lists) belong in that repo's `CLAUDE.md` and its `config.py`, not here.

## Layout

Flat `notebooks/`, files named by role so they stay importable (`from load import load_census`). No stage numbers: a module name cannot start with a digit, and the import graph already shows order without drifting.

| file | role | network | writes |
|---|---|---|---|
| `config.py` | shared constants (`Cfg`): paths, dataset ids, knobs shared by more than one notebook | no | nothing |
| `collect.py` | every fetch; the only writer of `data/`; owns remote ids (`Sources`) | yes | `data/` |
| `load.py` | pure readers and transforms of `data/` | no | nothing |
| `<question>.py` | one scientific question each | no | nothing |
| `fig_<name>.py` | figures | no | `figures/` |
| `tool_<name>.py` | debug and API tools | only when the tool is about the API | `figures/` or nothing |

- Enforce the boundaries with a test, not a comment: an AST test in `tests/` that only `collect.py` and `tool_*` import network clients, that `data/` paths and remote ids appear as literals only in `config.py` / `collect.py`, and that every `@app.function` / `@app.class_definition` is used by some cell in its own notebook (`main` exempt). A rule without a test drifts.
- Shared constants live once in `config.py`. Knobs used by one notebook stay in that notebook as plain setup constants, not a second class named `Cfg`. Never restate a path, id, or threshold as a literal; reference the symbol, including in default args, button labels, and docstrings.
- Reusable code is `@app.function` / `@app.class_definition` in the notebook that owns the concept; other notebooks and `tests/` import it. Split a notebook that grows past roughly 400 lines by concern, into another notebook. Use a plain `.py` module only for code no notebook tour explains (vendored helpers). Large HTML/CSS/JS templates go in `assets/` and load by a path from `Cfg`.
- Tests import notebooks through pytest `pythonpath = ["notebooks"]`, not `sys.path` hacks. marimo already puts the notebook's directory on `sys.path`.

## Structure of a notebook

- Imports, including cross-notebook imports, go in `with app.setup:`. Setup names are visible to every cell and every `@app.function`.
- Reusable-function unit: a markdown cell saying what the step is (math in `$$...$$` when it clarifies), the `@app.function`, then a small demo cell that calls it on real local data. Merge or split when the content wants it; a markdown cell that only titles the function is noise.
- Every function gets a demo, no exceptions but `main`. A network function demos on one small input behind a run button; a function that writes demos to a scratch path; a guard demos its failure path by catching the error and showing the message; a constants class shows its values as a table. Writing the demo is how a reader learns why the function exists, so a function whose demo would be pointless is a sign to inline it.
- One fact per cell. Do not pack results with `mo.vstack`, `mo.plain`, or dicts. Use real displays: a DataFrame as the last expression, `mo.ui.table`, a matplotlib or plotly figure, `mo.md` with numbers interpolated.
- Cell-local temporaries, including loop variables, are `_`-prefixed (`for _t in types:`); marimo keeps those local, so there is no `MultipleDefinitionError`. Never define the same public name in two cells.
- Never mutate an object another cell defined (`df["x"] = ...`); marimo does not rerun dependents on mutation. Build a new value (`df.assign(x=...)`) under a new name.
- Python cells keep code visible. Markdown explanation cells may be `hide_code=True` (per cell; there is no global default).
- Network cells sit behind `mo.ui.run_button`. Opening or batch-running a notebook must not fetch. Secrets come from the environment, never a cell.
- Batch entry is `if __name__ == "__main__": app.run()` in every notebook, collectors included; `python notebooks/x.py` runs every cell headless with run buttons off, so it never fetches. Do not add a `main()` that re-implements the tour. The exception is a collector or API check whose batch job is to fetch: its `main()` calls the same `@app.function`s, and the Makefile calls it directly (`cd notebooks && python -c 'import collect; collect.main()'`).

## Readability

- Explicit step-by-step code. No clever one-liners or deep helper chains.
- Parameters and variables are named for what they hold (`census`, `type_of`), not abbreviations (`ct`). A lookup's docstring says what it is used for, not only its shape.
- Provenance lives in function names, docstrings, and constants. Do not pack URLs, issue numbers, or product ids into markdown; let the dependency graph show data flow.
- Choice comments are short prose at the site of the choice, reading like the rest of the file: name the real options and why this one; for open-ended options, say what question the knob answers and give a couple of concrete values; say "arbitrary" when it is. No labels or lists. Do not hard-wrap comment lines.

```python
# Ranking cutoff in synapses, not a biological threshold. Twenty keeps the long tail from drowning the figure; raise it toward 50 or 100 if you only want strong partners, or swap in a quantile if the distribution shifts.
MIN_SYN = 20
```

## Checklist before calling it done

1. `marimo check --strict notebooks/` is clean (in `make test` if the repo has one).
2. `make test` passes, including the boundary test.
3. `python notebooks/<file>.py` runs headless without network. Open it in `marimo edit --watch` and look at the rendered cells, or say you only ran it headless.
4. `grep` for each literal you touched (paths, ids, thresholds): one definition only.
5. Every network path is in `collect.py` or a `tool_*`, behind a run button.
