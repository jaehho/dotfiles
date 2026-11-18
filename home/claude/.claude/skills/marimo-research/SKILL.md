---
name: marimo-research
description: Rules for writing or editing marimo notebooks used for scientific or data-science research (data collection, analysis, figures), where the notebooks are the lab record. Use whenever starting a new research question, or creating, restructuring, or editing a research marimo notebook, a project's notebooks/ folder, or a function in a package that notebooks import. Not for driving a live kernel (that is marimo-pair).
---

# Research marimo notebooks

Notebooks are the lab record.
Every number traces to code, a data file, and a stated choice.
Project facts (layout, datasets, ids, thresholds, palette) belong to the
project. Read its `CLAUDE.md` and `.claude/rules/` first. Where they differ
from this skill, follow the project.

## A new question: explore, then build

A new question starts as an exploration, not a notebook.

1. Explore in plain scripts in a dated folder,
   `explorations/YYYY-MM-DD-<slug>/`, as Noble (2009) dates a project's
   computational experiments (doi:10.1371/journal.pcbi.1000424).
   It holds the scripts, a `README.md` report, and the figures the report
   shows, committed on the question's topic branch. A script may import
   the package; nothing imports a script, and no exploration code moves
   into the package.
2. Run it to complete results. The report gives the answer first, then
   every choice (data, filters, cutoffs, definitions, methods) with the
   alternatives tried and what each changes, then the dead ends, so the
   build revisits each choice instead of inheriting the first cut.
   The user reads the report before any notebook exists. The folder is
   merged when they say so and is not edited after: a later look at the
   question is a new folder.
3. Build the notebook a section at a time: write one section, show its
   rendered output, and wait for the user before the next, unless they
   ask for the whole notebook. Restructure an existing notebook the same
   way. A function moves into the package when a notebook cell needs it.

## Layout

Shared code is an installable package of regular Python modules, one per
concern and named for it, never a catch-all `helpers`.
Notebooks import the package and never each other.
Name notebooks by role, one per question, without stage numbers. A prefix
per role is fine (`fig_` for notebooks that write figures, `tool_` for
debugging).
Keep every network fetch in one module, the only writer of data files, and
keep the loaders in another module as pure readers.

- A constant is defined once; reference the symbol, never restate a path,
  id, or threshold. A knob used by one notebook stays in that notebook.
- Opening or batch-running a notebook never fetches.
  A cell that fetches sits behind `mo.ui.run_button`;
  secrets come from the environment.
- A step that takes more than about a minute runs outside the notebook:
  package code, run by a make target, writes its results to files, and
  the notebook reads them to show and explore. Make reruns the step when
  the code or data it read change; the notebook names the command that
  makes missing results.
- A cell that takes more than a few seconds, but not the minute that
  calls for such a step, wraps its slow part in
  `with mo.persistent_cache(name="..."):`, so reopening the notebook
  restores the result from disk instead of computing it again
  (`__marimo__/cache/` beside the notebook, or under
  `PYTHONPYCACHEPREFIX` when that is set; `marimo cache dir` prints it). The cache key covers the block's code, its inputs,
  and the cells above it, but not the source of imported modules: after
  changing a package function the block calls, rename the cache (or
  delete the folder `marimo cache dir` prints). A hit skips the block's
  side effects, so saving a figure or printing stays outside it.
  The cache folder is not committed.
- Every role except the question notebooks is a reference: present tense,
  no discussion of results.

## Data

- Every notebook shows each data file as shipped before it uses it.
  Name the source as a link (the data release, the page, or the
  repository at its commit) with the file's name there, and show the raw
  table: whole when small, its schema and first rows from a lazy scan
  when large.
  Then call the function that makes the format the analysis uses, and
  show its result.
- A reader function returns a file as shipped, under the file's own
  column names. Each transform is a separate function named for what it
  makes; no function both reads and reshapes.
- A fetched file keeps the name and folder path its source gives it.

## Functions or cells

A step used once is a cell.
Make it an `@app.function` only when it is used from more than one place:
two cells, another function, another notebook, or a test that guards it.
Loop over cases inside one cell rather than writing a function to call once
per case, and inline a function that stops being reused.

Where a shared function lives follows the project's rules.
A function written for one notebook stays in it and calls the package.
A package function takes columns, thresholds, and labels as arguments,
so its signature says what it does.
Docstrings and doctests follow the project's rules.

A function that fetches runs on one small input behind a run button.

How to write the function itself (parameters, names, returns, levels of
abstraction) is the writing-functions skill.

## marimo mechanics

- Imports go in `with app.setup:`, which may not reference any other
  cell's variables.
- Cell-local temporaries, loop variables included, are `_`-prefixed.
  Never define the same public name in two cells.
- Never mutate an object another cell defined; marimo does not rerun
  dependents on mutation.
  Build a new value under a new name.
- marimo regenerates the file on save, so comments between cells and
  trailing comments in `with app.setup:` and `@app.function` bodies are lost.
  Put a comment on its own line inside a cell or function.
- Read each file in one cell and pass the variable on.
- Show each fact as itself: a table, a figure, or `mo.md` with numbers
  interpolated.
- Show a table as `mo.ui.table(df, label="...")` with
  `selection=None`, never as a bare DataFrame at the end of a cell, so it
  carries a title wherever it is seen.
  Show it whole, not `.head()` (marimo pages it), except the first rows
  of a lazy scan of a large file (Data).
  The label is Markdown and names what the rows are, as a figure title
  does.
  Where the variable name already says that, use it as the label
  (`label="lc10a_partners"`).
- A cell with a display equation has braces, so keep it a raw
  `mo.md(r"...")` and put interpolated sentences in their own
  `mo.md(rf"...")` cell.
## Question notebooks

For a question notebook (its question, background, expectations, analysis
sections, and discussion), read `references/question-notebook.md`
before you write or restructure it.

## Prose and names

- Prose does not type a value the code defines or computes, the Discussion
  included.
  Name the constant (`MIN_COUNT`) or interpolate it with `mo.md(f"...")`, so
  the text follows the data.
  A count or share the code measures, an adjective that carries a value
  ("thousands"), and a verdict that depends on them are values.
  A sentence that gives a value per group, or the smallest and largest,
  comes from a small function over the table, used by every such sentence.
  Values stay typed where they are not the notebook's (a quote, a cited
  threshold, the rows of a toy example) or where they count a fixed list
  the notebook itself states ("the three strengths").
- Use the literature's word for a quantity.
  Define each term once, where it first appears, and say there where this
  notebook departs from the literature.
  Within a notebook keep one word per thing and one thing per word, across
  prose, code names, column names, and figure labels.
  Before coining a name, check the terms already defined.
- When prose refers to a table, function, or variable, use the name it has
  in the code.
- Define a variable in the cell where the prose first needs it, and say in
  the prose what each package function that cell calls does.
  A filter or reshape that the code shows plainly needs no sentence.
- Explanatory text is a markdown cell in complete sentences, not a comment
  at the top of a code cell.
  Comments stay for a choice at its site and stay short; a setup constant's
  comment is one line naming its role, and the options considered go in the
  markdown where the reader meets the choice.
- Say each thing once, where it is used.
  A figure's intro says what is drawn and what to look at, not what the
  legend and axis labels already say.
- Scientific history (what was expected, found, and now thought) belongs in
  the notebook.
  Code and debugging history goes in GitHub issues, and a notebook never
  cites an issue number.
  Where there is a real choice, state the options and why this one, in
  present tense; a comment that reads like a postmortem is cut or moved to
  an issue.

## Figures

- Keep aesthetics at the defaults.
  Set one base look in the setup cell; a plot states a size, color, marker,
  or line width only when the data or the reader needs it, with a short
  comment why.
  One color per category, the same in every figure.
- Draw distributions, comparisons, and fits on the data;
  keep tables for exact values a reader will look up.
- Axis limits follow the data.
  Show groups side by side; a dropdown that shows one group at a time hides
  the comparison.
- Before drawing a schematic or describing a published result, look for
  the paper's own figure, and show it where it serves the point and its
  license allows.
- The chart library, selectable figures, schematics, figures from papers,
  and the base-look code: read `references/figures.md`.

## Effects and uncertainty

Lead with effect sizes in the result's own units, each with an interval
(a bootstrap over the units that were sampled), and use replication on an
independent set as the test of whether a pattern is real.
No p-values, q-values, significance flags or "beyond chance" unless the
user asks: when the data are one sample (one connectome, two surgeons),
they only say a pattern exceeds an assumed null.
Where a comparison with noise helps, name it ("steeper than in 99% of
shuffles") or draw the null distribution beside the data.

## Math

Display math is a definition or a claim, never decoration.
Define every symbol, with its domain, before the display.
A bare equation gets its hypotheses and a justification, or is dropped.
No program notation (`s.pre`) and one meaning per symbol across the project.
If a display only restates a line of dataframe code, use prose.

## Citations

Before you cite a claim from the literature, read `references/citations.md`.

## Tests

Doctests on package functions are the main test; pytest runs them.
Before you write a rule in prose, check the project's test file. A rule that
a test already checks needs only a pointer to the test.

## Before calling it done

1. `marimo check --strict notebooks/` is clean and the project's tests pass.
2. `uv run python notebooks/<file>.py` runs headless without fetching.
   Look at the rendered cells (`marimo edit`, or `marimo export html`), or
   say you only ran it headless.
3. The Discussion matches the rendered outputs and types no number the code
   computes.
