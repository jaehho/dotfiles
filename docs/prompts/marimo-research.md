# Research marimo notebooks: style and architecture

You are about to define how my research marimo notebooks should be written, then apply that to `~/projects/champalimaud/`. Treat every rule and every layout idea below as a hypothesis. Check it against marimo's actual model, against what is already in the repo, and against what keeps code readable. If something is wrong, over-strict, or a layer I do not need, say so and propose the smaller alternative. Do not implement on faith.

## What I want

Marimo notebooks for research. The artifact is the code. Cell outputs are secondary. I need to know exactly what is going on; nothing should be a black box. When I ask you to create or edit a marimo notebook, the result should be readable as a lab record of the analysis.

## Where this should live (check this)

My working answer is a **skill**, not memory and not a hook:

- A skill auto-invokes when I ask for marimo work and can hold a real checklist.
- Auto-memory is project-local background; it already drifted once. Keep at most a one-line pointer if something is not in the skill.
- A blocking hook would fight "no blocking hooks" and would freeze rules I am still revising.

Disagree if a skill is the wrong tool. Say why, and pick the better vehicle.

Suggested skill path (yours to revise): `~/dotfiles/home/claude/.claude/skills/marimo-research/SKILL.md`. Keep the skill to rules and checklist. Repo-specific constants belong in that repo's `CLAUDE.md`.

## Prior session

Read `~/dotfiles/2026-09-28-233521-leadertp-in-a-marimo-notebook-toggles-preview.txt`. That session produced most of the current notebooks and the first version of these ideas. Do not assume what it did was correct. It was already wrong in places: it claimed `collect_data` is the only network path (other scripts still fetch), it claimed constants are single-sourced (they are not), and it left `module_graph.py` as a 2k-line HTML blob inside a marimo `Cfg`. Use it as context and as a list of debts, not as truth.

## Architecture hypothesis (verify this)

The dataflow DAG should show up in the file tree. Stage-numbered flat notebooks:

| stage | role | network | writes |
|---|---|---|---|
| `00_` | constants and source ids (`Cfg`, `Sources`) | no | nothing |
| `01_` | collection | yes, alone | `data/` |
| `10_` | pure load / transform | no | nothing |
| `20_` | one scientific question per file | no | nothing |
| `30_` | figures / presentation | no | `figures/` |
| `90_` | tools, debug, graphs | only if the tool is about the API | `figures/` or `data/` |

Working rules that follow:

- Filenames encode order. `ls notebooks/` is the index. No nested folders until a stage has about five files.
- `data/` is written only by `01_`. Everything else reads files.
- One home for shared constants (`00_`). Analysis-only knobs stay in the analysis notebook. Never restate a path, product id, or threshold as a literal in a second place.
- Prefer `@app.function` / `@app.class_definition` in the owning notebook; downstream notebooks and `tests/` import them. Promote to a plain `.py` module only if a file would exceed roughly 400 lines or a non-notebook consumer needs it. Large templates (HTML, CSS, JS) go in `assets/` and load by path from `Cfg`.
- Wrap loops in a `def`. Marimo raises `MultipleDefinitionError` on shared loop variables. Do not redeclare a public name across cells.

What to pressure-test:

- Is stage-numbering better than naming by question alone? Does it fight marimo or help it?
- Is "library + tour in one file" still right for small modules, and wrong for large tools? Where is the line?
- Is `@app.function`-in-notebook the right default versus a real `src/` package? I care about greppability and "cannot drift" more than elegance.
- What is the smallest layout that kills duplicate `Cfg` and the fake "only one network path" rule?

## Cell shape (reference, not a template)

The unit that keeps working is:

1. a markdown cell saying what this step is (math in `$$...$$` when it clarifies),
2. the real API as `@app.function` or `@app.class_definition`,
3. a small demo that just calls it.

Use that as a base. Merge or split when the content wants it. Two cells that show one idea are fine; a markdown cell that only titles a function is noise. Python code cells stay visible. Markdown explanation cells may use `hide_code=True`.

Do not pack several facts into one cell with `mo.vstack` / `mo.plain`. Prefer real displays: a DataFrame as the last expression, `mo.ui.table`, matplotlib/plotly figures, `mo.md` for stats.

## Readability of the code

- Explicit step-by-step code. No clever one-liners, no deep helper indirection.
- Declare each constant or path once. Elsewhere, reference the symbol.
- Provenance lives in function names, docstrings, and constants. Do not pack URLs, issue numbers, and product ids into markdown. Let the dependency graph show data flow.
- Network demos use `mo.ui.run_button`. Opening a notebook must not fetch. Secrets stay in the environment.

### Choice comments

Write them as short prose at the site of the choice, so they read like the rest of the file. Name the real options and the reason, without a label or a list format. If the option set is open-ended, say what question the knob is answering and give a couple of concrete values. Mark arbitrary values as arbitrary.

Better:

```python
# Ranking cutoff in synapses, not a biological threshold. Twenty keeps the
# long tail from drowning the figure; raise it toward 50 or 100 if you only
# want strong partners, or swap in a quantile if the distribution shifts.
MIN_SYN = 20
```

Worse:

```python
# Partner cutoff. Alternatives: 1 (all contacts), 50-100 (strong only), or a
# quantile. Not biological.
MIN_SYN = 20
```

## Marimo mechanics to respect

- `marimo edit --watch` is the editor view (code cells visible). `marimo run` is app mode.
- `hide_code=True` is per-cell. `hideAllMarkdownCode` is a one-shot UI action that writes the flag into the file. There is no global default for hiding markdown code.
- Cells see only other cells' definitions. Put imports in an `app.setup` block or an import-only cell.
- Batch entry: `if __name__ == "__main__": app.run()`, and a `main()` for `make` targets.

## First application

`~/projects/champalimaud/`. Notebooks are currently in `scripts/` (`notebooks/` is empty). Move toward whatever layout you settle on after checking the architecture. Debts to fix while moving:

- Duplicate `Cfg` / `STACK` / `CENSUS` / `MIN_SYN` / `SEED_TYPES` in `show_raw.py`, `demo_jaccard.py`, `viz_network.py`, `viz_3d.py`, `lc_pathways.py`.
- Network outside collection: `lc_pathways.py`, `lc16_lc6_inputs.py`, `show_raw.py`, `viz_3d.py`.
- `module_graph.py` HTML/CSS/JS should not live in a `Cfg` string.
- `lc_pathways.py` is a plain script; give it a stage and the same cell shape.

Run `make test` and `make nb` after each move. Small WIP commits. Before changing broken behavior, search GitHub issues labeled `gotcha` and `decision`.

## How to respond

Lead with the skeptic's case: what is wrong with the hypothesis, what I should drop, what remains unverified. Then the plan. Then implement once the direction is clear. Push back on my ideas; do not flatter the layout.
