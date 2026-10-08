---
name: marimo-research
description: Rules for writing or editing marimo notebooks used for scientific or data-science research (data collection, analysis, figures), where the notebooks are the lab record. Use whenever creating, restructuring, or editing a research marimo notebook or a project's notebooks/ folder. Not for driving a live kernel (that is marimo-pair).
---

# Research marimo notebooks

Notebooks are the lab record.
Every number traces to code, a data file, and a stated choice.
Project-specific constants (datasets, ids, thresholds) belong in the
project's `CLAUDE.md` and shared config, not here.
Where a project's `CLAUDE.md` sets a layout, follow it.

## Layout

One flat `notebooks/`, files named by role so they import by name
(`from load import load_measurements`).
Without stage numbers, since a module name cannot start with a digit.
The roles: a `config` module for constants shared by more than one
notebook; a `collect` notebook that makes every fetch and is the only
writer of `data/`; a `load` module of pure readers; one notebook per
question; `fig_*` notebooks that write `figures/`; `tool_*` for debugging.

- A constant is defined once; reference the symbol, never restate a path,
  id, or threshold. A knob used by one notebook stays in that notebook.
- Opening or batch-running a notebook never fetches.
  A cell that fetches sits behind `mo.ui.run_button`;
  secrets come from the environment.
- Every role except the question notebooks is a reference:
  present tense, no discussion of results.
  A question notebook is the research record.
- Tests import notebooks through pytest `pythonpath = ["notebooks"]`.
  Batch entry is `if __name__ == "__main__": app.run()`.

## Functions or cells

A step used once is a cell.
Make it an `@app.function` only when it is used from more than one place:
two cells, another function, another notebook, or a test that guards it.
Loop over cases inside one cell rather than writing a function to call once
per case, and inline a function that stops being reused.

- Reusable code lives in the notebook that owns the concept;
  others import it.
- Each `@app.function` is followed at once by a cell that calls it and
  displays the return, so the reader sees what it does before the next
  definition.
  A small sample is fine as input.
  A function that fetches runs on one small input behind a run button.

### Writing a function

A reader, and a test, should be able to reason about a body without the rest
of the code (after Logan Smith, "How to write the perfect function").

- **Honest.**
  Everything the result depends on is a parameter: a cutoff, a column name,
  a seed, the current time.
  A default is fine (`cutoff: int = MIN_COUNT`);
  reading a setup constant, `Cfg`, a global, or the clock in the body is not.
  Files, the network, and writes to `figures/` belong to the shell
  (`load`, `collect`, `fig_*`, a notebook's top cells), which calls honest
  functions.
  If a test would need a mock or a fixture file, look for what the body reads
  that is not a parameter.
  A figure function may read the base look set once in setup.
- **Clear to the caller.**
  The name is a noun phrase for what it returns (`fit_summary`) or a verb
  phrase for what it does (`add_legend`), reads well at the call site
  (`rows_between(table, start, stop)`), and promises neither less nor more
  than the function does.
  Avoid words that fit anything (`output`, `process`, `get`, `data`).
  Name a parameter for its role (`window_size`, not `n`).
  Options are keyword-only, so no call has a bare `True`.
  Ask for no more than the body uses (a sequence of numbers, not one
  library's Series).
  Return a `NamedTuple`, a dataclass, or a frame whose columns the docstring
  lists, not a dict with string keys, and never `None` or a sentinel for
  failure.
  A precondition the types cannot state is checked and raises a `ValueError`
  that says which.
- **One level of abstraction.**
  A body calls smaller named functions instead of mixing levels.
  A comment that labels a section of the body, or an index trick
  (`x[::-1].cumsum()[::-1]`), marks a piece to name.
  Look first for the piece the notebook already computes (a CCDF, an overlap
  index); a second copy drifts.
  Producing data and acting on it (plotting, writing) are two functions.
  Stop where a piece has no name in the domain; it is then a line.

## marimo mechanics

- Imports, including cross-notebook imports, go in `with app.setup:`, which
  may not reference any other cell's variables.
- Cell-local temporaries, loop variables included, are `_`-prefixed.
  Never define the same public name in two cells.
- Never mutate an object another cell defined; marimo does not rerun
  dependents on mutation.
  Build a new value under a new name.
- marimo regenerates the file on save, so comments between cells and
  trailing comments in `with app.setup:` and `@app.function` bodies are lost.
  Put a comment on its own line inside a cell or function.
- Load each table in one cell and pass the variable on.
- Show each fact as itself: a DataFrame as the last expression, a figure, or
  `mo.md` with numbers interpolated.
  Do not pack results into `mo.vstack` or dicts.
  Do not cut a DataFrame with `.head()`; marimo pages it and adds column
  summaries.
- A cell with a display equation has braces, so keep it a raw
  `mo.md(r"...")` and put interpolated sentences in their own
  `mo.md(rf"...")` cell.

## Question notebooks

A question notebook is the log of one question, two at most.
The usual order: Introduction (the question, then the background with the
expectations), Load data, one section per analysis, Discussion (with
Limitations and Open questions), Terms.

- **Question**: one sentence, no definitions or notation.
- **Background**: only what bears on the question.
  What is known, why it matters, the reasoning behind the expected answer,
  and the design.
  Each exclusion or data quirk the analysis handles gets one sentence
  saying where it comes from.
  Quote where a passage carries the claim, link where none does, and skip a
  general introduction to the system.
  A claim the notebook cannot test becomes an open question.
- **Expectations** come before the methods and are stated as posed.
  An expectation says what the data would look like without the effect, and
  why; do not assume a distribution family without a reason.
  A post-hoc finding is reported as found, not dressed as an expectation.
- **Exclusions.**
  Define the objects of study as broadly as the question allows.
  Apply an exclusion after the first result and show its effect beside the
  unfiltered version.
  Where a filter decides which records count (quality, completeness, a
  validated flag), run the main analysis on the records the question is
  about, and show the unfiltered version beside it where it changes the
  conclusion.
- **Analysis sections** are named for what they show ("Which runs
  disagree"), not "Results", and each gets its own `##`.
  Headings are plain: no dates, "Hypothesis", "Next", or planned/exploratory
  labels.
  An exploration that changed a decision gets its own section before the
  method it motivated.
- **Discussion** goes expectation by expectation.
  It states each pattern qualitatively and links to the section that shows it
  (`[Section title](#section-title)`; the slug is the heading lowercased
  with hyphens).
  Check each claim against the rendered output: a table or figure you did
  not look at is not evidence.
  **Limitations** say once what else could produce the result and what it
  does not show.
  **Open questions** each carry a test and the outcome that would refute it.
- **Terms** is a glossary of words a reader may need a reminder of or that
  are niche in the field.
  Each is also defined in the prose where it first appears.
- A new question is a new notebook.
  Earlier conclusions are not rewritten; a later notebook corrects an earlier
  one and says so in both.
  Link across notebooks by name.
- Write in any order while developing; reread top to bottom at each commit
  and reorder for the reader.

## Prose and names

- Prose does not type a number the code defines or computes.
  Name the constant (`MIN_COUNT`) or interpolate it with `mo.md(f"...")`, so
  the text follows the data; this holds for the Discussion too.
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
  Introduce each definition, function, and figure with a cell that says what
  it is for and what to look at.
  Comments stay for a choice at its site and stay short; a setup constant's
  comment is one line naming its role, and the options considered go in the
  markdown where the reader meets the choice.
- Say each thing once, where it is used.
  A figure's intro says what is drawn and what to look at, not what the
  legend and axis labels already say.
- Explicit step-by-step code, no clever one-liners or deep helper chains.
  Names say what they hold (`measurements`, `label_of`).

## Figures

- Keep aesthetics at the defaults.
  Set one base look in the setup cell (a shared module once a second
  notebook needs it); a plot states a size, color, marker, or line width
  only when the data or the reader needs it, with a short comment why.
  One color per category, the same in every figure.
- Draw distributions, comparisons, and fits on the data;
  keep tables for exact values a reader will look up.
- Axis limits follow the data: no empty decade because another panel reaches
  it, unless panels share an axis on purpose.
  Show groups side by side; a dropdown that shows one group at a time hides
  the comparison.
- Pick the library by scenario.
  altair for charts that map columns to encodings, up to a few thousand
  marks (aggregate first beyond that).
  matplotlib for figures placed mark by mark, large point clouds, and files
  in `figures/`.
  plotly for 3D and WebGL.
  polars for every table; pandas only where a library demands it.
- A selectable figure, a schematic diagram, or the base-look code:
  read `references/figures.md`.

## Math

Display math is a definition or a claim, never decoration.

- Introduce every symbol with its domain before the display.
- Mark a definition as one ("define", "write ... for").
  A bare equation is a claim: give its hypotheses and a justification, or
  drop it.
- No program notation in math (`s.pre`, `df.col`).
  One meaning per symbol across the project.
  A set-builder display gets a left-hand side.
- If the display only restates a line of dataframe code, use prose.

## Citations

Claims from the literature come from the user's Zotero library, checked
before any web search.
If nothing there supports a claim, say so and do not cite it.

- Find the item with `zotero_search_items`, its highlights with
  `zotero_get_annotations`, an unmarked passage with
  `zotero_read_pdf_pages`.
  Quote exactly; never paraphrase inside quotation marks.
- Quote as a blockquote of the highlight, then
  `> — Author year, p. N · [PDF p. N](zotero://open-pdf/library/items/<attachment key>?page=N&annotation=<annotation key>) · [<doi>](https://doi.org/<doi>)`,
  split at the `·` so no line passes the limit (a line ending in a URL is
  exempt).
  N is the page label Zotero stores on the annotation (`page` in
  `zotero_get_annotations`, often the journal page), not the PDF index.
  The user's annotation comment goes outside the quote, as complete
  sentences.
  No citekeys.
- A passage with no highlight gets the same block with `?page=N` and no
  `annotation=`; offer to highlight it.
  Creating or changing an annotation writes to the user's library:
  ask first, tag it `claude`, and do not recolor.
- In running text, cite `[Author et al. year](https://doi.org/<doi>)`.
  Put each quote beside the one claim it supports.

## History

Scientific history (what was expected, found, and now thought) belongs in
the notebook.
Code and debugging history goes in GitHub issues, which hold tasks,
gotchas, and decisions.

- Never cite an issue number in a notebook.
- Never narrate past wrong code.
  State the rule the code enforces and, where there is a real choice, the
  options and why this one.
  A choice comment is present-tense rationale; if it reads like a
  postmortem, cut it or move it to an issue.

## Tests

Test what breaks silently and is cheap to check: the fetch boundary (only
`collect.py` and `tool_*` import anything that opens a connection), no
`data/` paths or remote ids outside `config.py` and `collect.py`, no issue
numbers in notebooks, and functions other notebooks import.
Do not test prose, section order, or single-use cells.
Add a test for a rule after it has been broken in practice.

## Before calling it done

1. `marimo check --strict notebooks/` is clean and the project's tests pass.
2. `python notebooks/<file>.py` runs headless without fetching.
   Look at the rendered cells (`marimo edit`, or `marimo export html`), or
   say you only ran it headless.
3. The Discussion matches the rendered outputs and types no number the code
   computes.

## Improving this skill

A rule earns a place here only if a research notebook on any topic is
better for it, not merely different.
A one-off preference, a data-specific fix, a tool or palette choice, and a
shape (a heading, a file name, a size) stay in the notebook or the
project's `CLAUDE.md`.
Before adding a rule, look for one to merge it into, or to remove.

- When the user leaves a comment inside a notebook, treat it as an
  instruction: address it, apply the same fix to the rest of the notebook
  past the last comment, and delete the comment.
- When the user suggests a change to one notebook, make it, then decide
  whether it passes the test above.
  If it does, end the reply by offering the skill change as exact text,
  naming the section.
  Do not edit the skill until the user agrees, unless they asked for the
  skill change directly.
- Keep the skill domain-neutral: examples use generic data.
- Edit the stow target `~/dotfiles/home/claude/.claude/skills/marimo-research/`
  (not the `~/.claude` symlink) and commit in `~/dotfiles` with only the
  skill's files staged.
