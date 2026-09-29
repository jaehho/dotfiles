---
name: marimo-research
description: Rules and checklist for writing or editing marimo notebooks used for research analysis (data collection, analysis, figures), where the code is the lab record. Use whenever creating, restructuring, or editing a research marimo notebook or a project's notebooks/ folder. Not for driving a live kernel (that is marimo-pair).
---

# Research marimo notebooks

The code is the lab record, and every number must trace to a function, a file, and a stated choice. Question notebooks are also the research log: they say what the results mean and what to test next. Repo-specific constants (stacks, product ids, seed lists) belong in that repo's `CLAUDE.md` and its `config.py`, not here.

## Layout

Flat `notebooks/`, files named by role so they stay importable (`from load import load_census`). No stage numbers: a module name cannot start with a digit, and the import graph already shows order without drifting.

| file | role | network | writes |
|---|---|---|---|
| `config.py` | shared constants (`Cfg`): paths, dataset ids, knobs shared by more than one notebook | no | nothing |
| `collect.py` | every fetch; the only writer of `data/`; owns remote ids (`Sources`) | yes | `data/` |
| `load.py` | pure readers and transforms of `data/` | no | nothing |
| `<question>.py` | one scientific question each; a research log (see below) | no | nothing |
| `fig_<name>.py` | figures | no | `figures/` |
| `tool_<name>.py` | debug and API tools | only when the tool is about the API | `figures/` or nothing |

- Two registers. `config`, `collect`, `load`, `fig_*`, and `tool_*` are polished references: present tense, no results discussion, no log. Question notebooks read as a research log.
- Enforce the boundaries with a test, not a comment: an AST test in `tests/` that only `collect.py` and `tool_*` import network clients, that `data/` paths and remote ids appear as literals only in `config.py` / `collect.py`, and that every `@app.function` / `@app.class_definition` is used by some cell in its own notebook (`main` exempt). A rule without a test drifts.
- Shared constants live once in `config.py`. Knobs used by one notebook stay in that notebook as plain setup constants, not a second class named `Cfg`. Never restate a path, id, or threshold as a literal; reference the symbol, including in default args, button labels, and docstrings.
- Reusable code is `@app.function` / `@app.class_definition` in the notebook that owns the concept; other notebooks and `tests/` import it. Split a notebook that grows past roughly 400 lines by concern, into another notebook. Use a plain `.py` module only for code no notebook tour explains (vendored helpers). Large HTML/CSS/JS templates go in `assets/` and load by a path from `Cfg`.
- Tests import notebooks through pytest `pythonpath = ["notebooks"]`, not `sys.path` hacks. marimo already puts the notebook's directory on `sys.path`.

## Structure of a notebook

- Imports, including cross-notebook imports, go in `with app.setup:`. Setup names are visible to every cell and every `@app.function`.
- Reusable-function unit: a markdown cell saying what the step is (research-grade math in `$$...$$` only when it earns its place; see Math), the `@app.function`, then a small demo cell that calls it on real local data. Merge or split when the content wants it; a markdown cell that only titles the function is noise.
- Every function gets a demo, no exceptions but `main`. A network function demos on one small input behind a run button; a function that writes demos to a scratch path; a guard demos its failure path by catching the error and showing the message; a constants class shows its values as a table. Writing the demo is how a reader learns why the function exists, so a function whose demo would be pointless is a sign to inline it.
- One fact per cell. Do not pack results with `mo.vstack`, `mo.plain`, or dicts. Use real displays: a DataFrame as the last expression, `mo.ui.table`, a matplotlib or plotly figure, `mo.md` with numbers interpolated.
- Cell-local temporaries, including loop variables, are `_`-prefixed (`for _t in types:`); marimo keeps those local, so there is no `MultipleDefinitionError`. Never define the same public name in two cells.
- Never mutate an object another cell defined (`df["x"] = ...`); marimo does not rerun dependents on mutation. Build a new value (`df.assign(x=...)`) under a new name.
- Python cells keep code visible. Markdown explanation cells may be `hide_code=True` (per cell; there is no global default).
- Network cells sit behind `mo.ui.run_button`. Opening or batch-running a notebook must not fetch. Secrets come from the environment, never a cell.
- Batch entry is `if __name__ == "__main__": app.run()` in every notebook, collectors included; `python notebooks/x.py` runs every cell headless with run buttons off, so it never fetches. Do not add a `main()` that re-implements the tour. The exception is a collector or API check whose batch job is to fetch: its `main()` calls the same `@app.function`s, and the Makefile calls it directly (`cd notebooks && python -c 'import collect; collect.main()'`).

## Question notebooks are research logs

A question notebook does more than lay out tools. It says what the numbers show, what they mean, and which hypotheses they raise, and later work builds on those hypotheses.

- After each result that matters, add a short markdown cell that states the result with the numbers interpolated from live values (`mo.md(f"...")`). Such a claim cannot drift from the data.
- End the notebook with a `## Log` section: one hidden markdown cell that states the convention, then one cell per dated entry `### YYYY-MM-DD`, oldest first. Numbers in an entry are as of its date. Entries are append-only; a later entry corrects an earlier one instead of editing it.
- Each entry has three parts. **Seen**: what the notebook showed, with the scope (hemisphere, cutoff, dataset version). **Reading**: the skeptic's case first, then what the result does and does not establish. **Hypotheses**: numbered, each with a concrete test and the outcome that would refute it.
- Before writing an entry, check every claim against the rendered output. A table you did not look at is not evidence; add the cell that shows it.
- Link across notebooks by name (`lc_output_clusters`) when one result bears on another's conclusion, and log that in the affected notebook too.
- Scientific history (what we found, what we now think, what changed our mind) goes in the log. Code and debugging history still goes in issues (see Issues).
- Enforce the register split with a test: each question notebook has exactly one `## Log`, as its last section, with dated entries in order; polished notebooks have none.

## Diagrams

When a definition compares two quantities or describes a structure (an aggregation over cells, a graph motif, a pipeline), put a small schematic next to the math. A picture of the definition catches misreadings that the formula does not.

- Draw it with an `@app.function` that takes a toy input and computes every label with the notebook's own functions, so the picture cannot disagree with the code. The demo cell builds the toy input and draws it.
- Pick toy values that make the distinction visible: the case where the two definitions disagree, or where excluded context would change the answer if it were counted.
- Color the objects the definition is about, one color per role, and gray out the context it excludes. Encode magnitude (edge width, size) as well as labeling it. Put the computed values on the figure.
- Colors are setup constants; state their roles in a comment. Use matplotlib, no external assets.
- Follow the diagram with a one-line interpolated caption that says what the toy example shows.

## Math

Display math is a definition or a claim, never decoration. Write research-grade statements: a reader who takes the notation seriously must not hit an undefined symbol, an unstated domain, or a claim with no hypotheses. Prose is the default; a display earns its place only when the precision of the notation is the point.

- Introduce every symbol in a display before that display, with its domain and the ambient universe stated once at first use ("a synapse $s$ at materialization 783", "$R \subseteq \mathrm{RootId}$ a set of root ids", "$w(i \to j)$ the synapse count from cell $i$ to cell $j$"). Later displays reuse the same meaning or say they do not.
- Mark definitions as definitions ("define $S(R)$ to be", "write $W(A \to B)$ for"). A bare equation is a claim: give its hypotheses and a short justification in prose, or drop it.
- No program notation in math. $s.\mathrm{pre}$ is an attribute access; either define $\mathrm{pre}$ as a map on synapses or write the fact in prose.
- One meaning per symbol across the project. Do not overload a letter for two roles (a seed set and a synapse set). A type name is not a set of cells: write $\mathrm{cells}(T)$, or define types as the sets once and say so.
- Types of the objects match the operations. Do not sum over a type name, take cardinality of a string, or use $A \in S$ when $S$ holds type names and $A$ is a set of cells.
- Set-builder displays get a left-hand side. A bare $\{\, \ldots \,\}$ is not a definition of anything.
- If the display only restates one line of pandas in worse notation, use prose instead.

Bad (undefined constructor, unmarked definition, silent universe):

$$S(R) = \{\, s : s.\mathrm{pre} \in R \ \lor\ s.\mathrm{post} \in R \,\}$$

Good: a synapse is a contact $s$ with pre- and post-synaptic root ids $\mathrm{pre}(s), \mathrm{post}(s) \in \mathrm{RootId}$. For $R \subseteq \mathrm{RootId}$, define

$$S(R) = \{\, s : \mathrm{pre}(s) \in R \ \lor\ \mathrm{post}(s) \in R \,\}$$

to be the synapses that touch $R$.

## Issues

GitHub issues hold tasks, gotchas, decisions, and how a bug was found. Code in a notebook is a polished account of the method as it stands, not a design log; the scientific log lives in a question notebook's `## Log`.

- Never cite an issue number in a notebook: markdown, comments, docstrings, or strings all count.
- Never narrate past wrong versions or debugging history ("counting before that dedup doubled every weight", "this caught that twice"). State the rule the code enforces and, where there is a real choice, the options and why this one. The story goes in an issue; the code and its comment keep only the current decision.
- A choice comment is present-tense design rationale. If it reads like a postmortem, cut it to the rationale or move it to an issue.
- Enforce the issue-number ban with a test in `tests/`, not a reminder comment. Hex color literals (`#0b0b0b`) are not issue refs; the test must not flag them.

## Readability

- Explicit step-by-step code. No clever one-liners or deep helper chains.
- Parameters and variables are named for what they hold (`census`, `type_of`), not abbreviations (`ct`). A lookup's docstring says what it is used for, not only its shape.
- Provenance lives in function names, docstrings, and constants. Do not pack URLs or product ids into markdown; let the dependency graph show data flow. Issue numbers never appear in a notebook (see Issues).
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
6. Every `$$...$$` is research-grade: symbols introduced with domains first, definitions marked, one meaning per symbol, no program notation.
7. No issue numbers and no code or debugging history anywhere in the notebook.
8. Question notebook: results cells interpolate live numbers, and a new dated `## Log` entry (Seen, Reading with the skeptic's case first, Hypotheses with tests) matches the rendered outputs.
9. Every definition that compares quantities or describes a structure has a toy diagram drawn by the notebook's own functions.

## Improving this skill

This skill grows from the user's edits to single notebooks.

- When the user suggests a meaningful change to one notebook (structure, prose, figures, math, naming, testing), make the change, then decide whether it would apply to research notebooks in general.
- If it would, end the reply by offering a skill update: quote the exact text to add or change and name the section. Do not edit the skill until the user agrees.
- Skip one-off preferences, data-specific fixes, and anything a section here already covers; say "already covered by <section>" instead when relevant.
- On approval, edit the stow target `~/dotfiles/home/claude/.claude/skills/marimo-research/SKILL.md` (not the `~/.claude` symlink), keep rules short and testable, add a checklist item when the rule can be checked, and commit in `~/dotfiles` with only that file staged.
