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
- The demo displays the return. It does not display or describe the input; the call shows what goes in, and when an input needs inspecting, probe the notebook with a cell that displays it.
- Demo on real project data when that is clearest; a small sample is fine, and often clearer, for a pure transform or a metric. A function that fetches remote data runs on one small input behind a run button.
- When a function stops being reused, inline it.

## Structure of a notebook

- Imports, including cross-notebook imports, go in `with app.setup:`. The setup cell may not reference any other cell's variables.
- One fact per cell. Use real displays: a DataFrame as the last expression, a figure, `mo.md` with numbers interpolated. Do not pack results with `mo.vstack` or dicts.
- Prefer a figure to a table. Use a table for exact values a reader will look up; show distributions, comparisons, and fits (a slope, a cutoff) drawn on the data.
- Do not truncate a display with `.head()` or `.tail()`: marimo pages a DataFrame and adds column summaries, which say more than the first rows. Sort or filter only when the selection is itself the result.
- Cell-local temporaries, including loop variables, are `_`-prefixed; never define the same public name in two cells.
- Never mutate an object another cell defined; marimo does not rerun dependents on mutation. Build a new value under a new name.
- Markdown cells may be `hide_code=True`; Python cells keep code visible.
- Cells that fetch sit behind `mo.ui.run_button`. Opening or batch-running a notebook must not fetch. Secrets come from the environment.
- Batch entry is `if __name__ == "__main__": app.run()`. A collector whose batch job is to fetch also has a `main()` that calls the same functions; the Makefile calls it directly.

## Question notebooks follow the scientific method

The notebook is the log. A question notebook covers one question, two at most, in this order:

```
# Title
## Introduction
### Question        what is asked and the terms it uses
### Background      what is known, why the question matters, the reasoning behind the expected answer, and the design; expectations that could fail
(methods, no header: data, definitions, diagrams, reused functions, each under its own ## section when it needs one)
## Results
## Discussion        what the results say, expectation by expectation
### Limitations      what else could produce the result and what it does not show
### Open questions  follow-up questions, each with a test and the outcome that would refute it
```

- The expectations come before the methods and results and are stated as they were posed. They are reasoning that warrants the experiments, not labeled hypotheses. Do not dress a post-hoc finding as an expectation; label exploratory results as exploratory.
- Headings are plain and undated. No "Hypothesis", "Skeptic's case", "Decision", or "Next".
- What follows the Introduction is methods, with no header. When one analysis maps to one expectation, interleave method and result.
- Result cells state numbers with `mo.md(f"...")` from live values so a claim cannot drift from the data. The Discussion may quote numbers as of writing.
- Check every claim in the Discussion against the rendered output. A table or figure you did not look at is not evidence; add the cell that shows it.
- A new question is a new notebook. Earlier conclusions are not rewritten; a later notebook corrects an earlier one and says so in both.
- Link across notebooks by name when one result bears on another's conclusion.
- Claims from the literature in the Background are cited as in Citations.
- Scientific history (what we expected, found, and now think) belongs here. Code and debugging history goes in issues.

## Diagrams

When a definition compares two quantities or describes a structure (an aggregation, a graph motif, a pipeline), put a small schematic in the Methods next to it.

- Choose the tool by what the picture must get right. Use **mermaid** (`mo.mermaid`) for flow and process: pipelines, decision logic, data lineage, where automatic layout is fine and the text source is the point. Use **matplotlib** when geometry carries meaning (positions, ordering, magnitude as width or size) or when labels are computed; mermaid reorders nodes and routes edges on its own. Render once and look before keeping either.
- Build the toy input in the cell and compute the labels with the notebook's own functions, so the picture cannot disagree with the code. A single-use diagram is drawn inline in its cell, not in a function.
- Pick toy values that make the distinction visible: the case where two definitions disagree, or where excluded context would change the answer.
- One color per role, gray for context the definition excludes. Colors are setup constants with their roles in a comment.
- Show the context the definition leaves out, not only what it counts: units of another class, contacts it ignores (dashed), and a unit that connects to several targets. Use the fewest units that can carry all of that.
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

## Citations

Claims from the literature come from the user's Zotero library, not from memory (Zotero before web search).

- Find the item with `zotero_search_items`, its highlights with `zotero_get_annotations`, and an unmarked passage with `zotero_read_pdf_pages`. Quote exactly; never paraphrase inside quotation marks.
- Quote a source the way the user's `<leader>zq` does: a blockquote of the highlight, then `> — Author year, p. N · [PDF p. N](zotero://open-pdf/library/items/<attachment key>?page=N&annotation=<annotation key>) · [<doi>](https://doi.org/<doi>)`, then the user's annotation comment outside the quote, rewritten as complete sentences. No citekeys (Better BibTeX can rewrite them).
- A passage with no highlight gets the same block with `?page=N` and no `annotation=`; offer to highlight it in Zotero. Creating or changing annotations is a write to the user's library: ask first, and tag them `claude`.
- In running text cite as `[Author et al. year](https://doi.org/<doi>)`. Put each quote beside the one claim it supports, in the Background.
- If nothing in Zotero supports a claim, say so and do not cite it.

## Issues

GitHub issues hold tasks, gotchas, decisions, and how a bug was found.

- Never cite an issue number in a notebook.
- Never narrate past wrong code or debugging history. State the rule the code enforces and, where there is a real choice, the options and why this one.
- A choice comment is present-tense rationale. If it reads like a postmortem, cut it or move it to an issue.

## Readability

- Explicit step-by-step code. No clever one-liners or deep helper chains.
- Names say what they hold (`measurements`, `label_of`), not abbreviations.
- Explanatory text is a markdown cell in complete sentences with transitions, not a comment at the top of a code cell. Introduce each definition, function, and figure with a markdown cell that says what it is for and what to look at. Comments stay for a choice at its site (a constant, a threshold) and stay short.
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
5. Question notebook: introduction (question, background with expectations), methods, results, discussion (limitations, open questions), in that order; the discussion matches the rendered outputs.
6. Each `$$...$$` is research-grade; each definition that compares quantities or describes a structure has a diagram you have looked at.
7. No issue numbers and no code or debugging history in the notebook.
8. Each literature claim in the Background is quoted or linked as in Citations.

## Improving this skill

This skill grows from the user's edits to single notebooks.

- When the user suggests a meaningful change to one notebook (structure, prose, figures, math, naming, testing), make the change, then decide whether it applies to research notebooks in general.
- If it does, end the reply by offering a skill update: quote the exact text to add or change and name the section. Do not edit the skill until the user agrees, unless they asked for the skill change directly.
- Skip one-off preferences and data-specific fixes; say "already covered by <section>" when relevant.
- Keep the skill domain-neutral: examples use generic data, not one project's field.
- Edit the stow target `~/dotfiles/home/claude/.claude/skills/marimo-research/SKILL.md` (not the `~/.claude` symlink) and commit in `~/dotfiles` with only that file staged.
