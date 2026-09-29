---
name: marimo-research
description: Rules and checklist for writing or editing marimo notebooks used for scientific or data-science research (data collection, analysis, figures), where the notebooks are the lab record. Use whenever creating, restructuring, or editing a research marimo notebook or a project's notebooks/ folder. Not for driving a live kernel (that is marimo-pair).
---

# Research marimo notebooks

Notebooks are the lab record. Every number must trace to code, a data file, and a stated choice, and each question notebook is a written account of the scientific method applied to one question. Project-specific constants (datasets, ids, thresholds) belong in that project's `CLAUDE.md` and `config.py`, not here.

## Layout

Flat `notebooks/`, files named by role so they stay importable (`from load import load_measurements`). No stage numbers: a module name cannot start with a digit, and the import graph already shows order.

| file | role | fetches | writes |
|---|---|---|---|
| `config.py` | shared constants (`Cfg`): paths, dataset ids, knobs shared by more than one notebook | no | nothing |
| `collect.py` | every fetch; the only writer of `data/`; owns remote ids (`Sources`) | yes | `data/` |
| `load.py` | pure readers and transforms of `data/` | no | nothing |
| `<question>.py` | one research question, as one or two scientific-method cycles | no | nothing |
| `fig_<name>.py` | figures | no | `figures/` |
| `tool_<name>.py` | debug and API tools | only when the tool is about the API | `figures/` or nothing |

- Two registers. `config`, `collect`, `load`, `fig_*`, and `tool_*` are polished references: present tense, no results discussion. Question notebooks are the research record (see Question notebooks).
- Shared constants live once in `config.py`. Knobs used by one notebook stay in that notebook as setup constants, not a second `Cfg`. Never restate a path, id, or threshold as a literal; reference the symbol.
- A notebook that grows past roughly 400 lines, or past two cycles, splits by question. Large HTML/CSS/JS templates go in `assets/` and load by a path from `Cfg`.
- Tests import notebooks through pytest `pythonpath = ["notebooks"]`, not `sys.path` hacks.

## Functions or cells

A step used once is a cell. Make it an `@app.function` only when it is used from more than one place: two or more cells, another notebook, or a test that guards it. Turning every step into a function hides the analysis behind names and adds a demo for each.

- Loop over cases inside one cell (`for _t in types:`) instead of writing a function to call once per case.
- Reusable code lives in the notebook that owns the concept; others import it. A plain `.py` module is only for code no notebook explains (vendored helpers).
- Each `@app.function` is immediately followed by the cell that calls it (its demo), so the reader sees what it does before meeting the next definition. Never batch several definitions and demonstrate them later.
- The demo names both sides of the call: a comment in `input -> return` form says what goes in and what comes back (`# pairs (pre, post, weight) -> one total per partner`). marimo displays only a cell's last expression, so the input cannot sit beside its result and has to be written down.
- Demo on real project data when that is clearest; a small sample is fine, and often clearer, for a pure transform or a metric. A function that fetches remote data runs on one small input behind a run button.
- When a function stops being reused, inline it.

## Structure of a notebook

- Imports, including cross-notebook imports, go in `with app.setup:`. The setup cell may not reference any other cell's variables.
- One fact per cell. Use real displays: a DataFrame as the last expression, a figure, `mo.md` with numbers interpolated. Do not pack results with `mo.vstack` or dicts.
- Cell-local temporaries, including loop variables, are `_`-prefixed; never define the same public name in two cells.
- Never mutate an object another cell defined; marimo does not rerun dependents on mutation. Build a new value under a new name.
- Markdown cells may be `hide_code=True`; Python cells keep code visible.
- Cells that fetch sit behind `mo.ui.run_button`. Opening or batch-running a notebook must not fetch. Secrets come from the environment.
- Batch entry is `if __name__ == "__main__": app.run()`. A collector whose batch job is to fetch also has a `main()` that calls the same functions; the Makefile calls it directly.

## Question notebooks follow the scientific method

The notebook is the log. Each question notebook holds one cycle, at most two, in order:

```
# Title
Short context: what is studied, scope (subset, dataset version), terms.

## Cycle 1 (YYYY-MM-DD): <short question>
### Question
### Hypothesis     who posed it and when; numbered predictions that could fail
### Methods        data, definitions, diagrams, reused functions
### Results        outputs, each claim interpolated from live values
### Discussion     prediction by prediction: holds or fails, skeptic's case, conclusion, decision
### Next           hypotheses for the next cycle, each with a test and what would refute it
```

- The hypothesis and its predictions come before the methods and are stated as they were posed. Do not dress a post-hoc finding as an a-priori prediction; label exploratory results as exploratory.
- When one analysis maps to one prediction, interleave method and result under `### Methods and results`, one analysis at a time.
- Result cells state numbers with `mo.md(f"...")` from live values so a claim cannot drift from the data. The Discussion may quote numbers as of the cycle's date.
- Check every claim in the Discussion against the rendered output. A table you did not look at is not evidence; add the cell that shows it.
- A new cycle is a new `## Cycle n (date)` section, or a new notebook when the question changes. Earlier cycles are not rewritten; a later cycle corrects an earlier one.
- Link across notebooks by name when one result bears on another's conclusion, and note it in both.
- Scientific history (what we predicted, found, and now think) belongs here. Code and debugging history goes in issues.

## Diagrams

When a definition compares two quantities or describes a structure (an aggregation, a graph motif, a pipeline), put a small schematic in the Methods next to it.

- Choose the tool by what the picture must get right. Use **mermaid** (`mo.mermaid`) for flow and process: pipelines, decision logic, data lineage, where automatic layout is fine and the text source is the point. Use **matplotlib** when geometry carries meaning (positions, ordering, magnitude as width or size) or when labels are computed; mermaid reorders nodes and routes edges on its own. Render once and look before keeping either.
- Build the toy input in the cell and compute the labels with the notebook's own functions, so the picture cannot disagree with the code. A single-use diagram is drawn inline in its cell, not in a function.
- Pick toy values that make the distinction visible: the case where two definitions disagree, or where excluded context would change the answer.
- One color per role, gray for context the definition excludes. Colors are setup constants with their roles in a comment.
- Follow it with a one-line interpolated caption that says what the toy example shows.

## Math

Display math is a definition or a claim, never decoration. A reader who takes the notation seriously must not hit an undefined symbol, an unstated domain, or a claim with no hypotheses. Prose is the default; a display earns its place when the precision is the point.

- Introduce every symbol before its display, with its domain ("$x_i \in \mathbb{R}^d$ the feature vector of sample $i$", "$w(i \to j)$ the count of events from $i$ to $j$").
- Mark definitions as definitions ("define", "write ... for"). A bare equation is a claim: give its hypotheses and a justification, or drop it.
- No program notation in math (`s.pre`, `df.col`). Define a map, or say it in prose.
- One meaning per symbol across the project. A category label is not a set of members: write $\mathrm{members}(G)$, or define groups as sets once.
- Set-builder displays get a left-hand side.
- If the display only restates one line of pandas in worse notation, use prose.

Bad: $S(R) = \{\, s : s.\mathrm{src} \in R \,\}$. Good: each record $s$ has a source $\mathrm{src}(s) \in U$; for $R \subseteq U$ define $S(R) = \{\, s : \mathrm{src}(s) \in R \,\}$, the records that start in $R$.

## Issues

GitHub issues hold tasks, gotchas, decisions, and how a bug was found.

- Never cite an issue number in a notebook.
- Never narrate past wrong code or debugging history. State the rule the code enforces and, where there is a real choice, the options and why this one.
- A choice comment is present-tense rationale. If it reads like a postmortem, cut it or move it to an issue.

## Readability

- Explicit step-by-step code. No clever one-liners or deep helper chains.
- Names say what they hold (`measurements`, `label_of`), not abbreviations.
- Provenance lives in names, docstrings, and constants; let the dependency graph show data flow.
- Choice comments are short prose at the site of the choice: the real options and why this one; for open-ended knobs, what question the knob answers and a couple of concrete values; "arbitrary" when it is. No hard-wrapped comment lines.

```python
# Minimum count for a pair to be ranked. Twenty keeps the long tail from drowning the figure; raise it toward 50 if you only want strong pairs, or use a quantile if the distribution shifts.
MIN_COUNT = 20
```

## Tests

Tests guard what breaks silently and is cheap to check. They do not police style.

- Worth a test: the fetch boundary (only `collect.py` and `tool_*` import anything that opens a connection: HTTP, database, cloud storage), no `data/` paths or remote ids outside `config.py` / `collect.py`, no issue numbers in notebooks, and functions other notebooks import.
- Not worth a test: prose conventions, section order, single-use cells. Research needs room to try things; a rule that is annoying to satisfy and rarely catches a real mistake costs more than it saves.
- When unsure, state the rule here and add a test only after it has been broken in practice.

## Checklist before calling it done

1. `marimo check --strict notebooks/` is clean and the project's tests pass.
2. `python notebooks/<file>.py` runs headless without fetching. Open it in `marimo edit` and look at the rendered cells, or say you only ran it headless.
3. Each literal you touched (paths, ids, thresholds) has one definition.
4. Functions exist only where reused; single-use steps are cells.
5. Question notebook: question, hypothesis with predictions, methods, results, discussion, next, in that order; the discussion matches the rendered outputs.
6. Each `$$...$$` is research-grade; each definition that compares quantities or describes a structure has a diagram you have looked at.
7. No issue numbers and no code or debugging history in the notebook.

## Improving this skill

This skill grows from the user's edits to single notebooks.

- When the user suggests a meaningful change to one notebook (structure, prose, figures, math, naming, testing), make the change, then decide whether it applies to research notebooks in general.
- If it does, end the reply by offering a skill update: quote the exact text to add or change and name the section. Do not edit the skill until the user agrees, unless they asked for the skill change directly.
- Skip one-off preferences and data-specific fixes; say "already covered by <section>" when relevant.
- Keep the skill domain-neutral: examples use generic data, not one project's field.
- Edit the stow target `~/dotfiles/home/claude/.claude/skills/marimo-research/SKILL.md` (not the `~/.claude` symlink) and commit in `~/dotfiles` with only that file staged.
