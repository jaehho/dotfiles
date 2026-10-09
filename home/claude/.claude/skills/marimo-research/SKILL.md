---
name: marimo-research
description: Rules for writing or editing marimo notebooks used for scientific or data-science research (data collection, analysis, figures), where the notebooks are the lab record. Use whenever creating, restructuring, or editing a research marimo notebook, a project's notebooks/ folder, or a function in a package that notebooks import. Not for driving a live kernel (that is marimo-pair).
---

# Research marimo notebooks

Notebooks are the lab record.
Every number traces to code, a data file, and a stated choice.
Project facts (layout, datasets, ids, thresholds, palette) belong to the
project. Read its `CLAUDE.md` and `.claude/rules/` first. Where they differ
from this skill, follow the project.

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
- Every role except the question notebooks is a reference: present tense,
  no discussion of results.

## Functions or cells

A step used once is a cell.
Make it an `@app.function` only when it is used from more than one place:
two cells, another function, another notebook, or a test that guards it.
Loop over cases inside one cell rather than writing a function to call once
per case, and inline a function that stops being reused.

Before writing a function, look for a similar one in the project and extend
it. Where a shared function lives follows the project's rules. A function
written for one notebook stays in it and calls the package.
A package function takes columns, thresholds, and labels as arguments,
so its signature says what it does.
Docstrings and doctests follow the project's rules.

Each `@app.function` defined in a notebook is followed at once by a cell
that calls it and displays the return, so the reader sees what it does
before the next definition.
A small sample is fine as input.
A function that fetches runs on one small input behind a run button.

### Writing a function

A reader, and a test, should be able to reason about a body without the rest
of the code (after Logan Smith, "How to write the perfect function").

- **Honest.**
  Everything the result depends on is a parameter: a cutoff, a column name,
  a seed, the current time.
  A default is fine (`cutoff: int = MIN_COUNT`);
  reading a setup constant, the project's config module, a global, or the clock in the body is not.
  Files, the network, and writes belong to the shell
  (the loaders, the fetch code, a notebook's top cells), which calls honest
  functions.
  If a test would need a mock or a fixture file, look for what the body reads
  that is not a parameter.
  A figure function may read the base look set once in setup.
- **Clear to the caller.**
  The name is a noun phrase for what it returns (`fit_summary`) or a verb
  phrase for what it does (`add_legend`), reads well at the call site
  (`rows_between(table, start, stop)`), and promises neither less nor more
  than the function does.
  No catch-all words (`output`, `process`, `get`, `data`).
  Parameters are named for their role (`window_size`, not `n`), options are
  keyword-only, and a function asks for no more than its body uses.
  It returns a `NamedTuple`, a dataclass, or a frame whose columns the
  docstring lists, not a dict with string keys, and never `None` or a
  sentinel for failure.
  A precondition the types cannot state raises a `ValueError` that says which.
- **One level of abstraction.**
  A body calls smaller named functions instead of mixing levels;
  a comment that labels a section of the body marks a piece to name.
  Reuse what the notebook already computes (a CCDF, an overlap index);
  a second copy drifts.
  Producing data and acting on it (plotting, writing) are two functions.

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
- Load each table in one cell and pass the variable on.
- Show each fact as itself: a DataFrame as the last expression (not
  `.head()`; marimo pages it), a figure, or `mo.md` with numbers
  interpolated.
- A cell with a display equation has braces, so keep it a raw
  `mo.md(r"...")` and put interpolated sentences in their own
  `mo.md(rf"...")` cell.
## Question notebooks

For a question notebook (its question, background, expectations, analysis
sections, discussion, and terms), read `references/question-notebook.md`
before you write or restructure it.

## Prose and names

- Prose does not type a number the code defines or computes, the Discussion
  included.
  Name the constant (`MIN_COUNT`) or interpolate it with `mo.md(f"...")`, so
  the text follows the data.
  A count of items ("four groups"), an adjective that carries a number
  ("thousands"), and a verdict that depends on counts are numbers.
  A sentence that gives a value per group, or the smallest and largest,
  comes from a small function over the table, used by every such sentence.
  Numbers stay typed only where they are not the notebook's: a quote, a
  cited threshold, the rows of a toy example.
- Use the literature's word for a quantity.
  Define each term once, where it first appears, and say there where this
  notebook departs from the literature.
  Within a notebook keep one word per thing and one thing per word, across
  prose, code names, column names, and figure labels.
  Before coining a name, check the terms already defined.
- Introduce each table, function, and variable in prose by the name it has
  in the code.
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
- The chart library, selectable figures, schematics, and the base-look code:
  read `references/figures.md`.

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
