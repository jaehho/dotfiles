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
### Question        what is asked, in one sentence, with no definitions or notation
### Background      only what bears on this question: what is known, why it matters, the reasoning behind the expected answer, and the design; expectations that could fail; a #### subheading per topic (a data quirk, a standard, why a threshold) so it scans
## Load data       the tables the analysis reads, named as in the code
(other methods, no header: definitions, diagrams, reused functions, each under its own ## section when it needs one)
## <one section per question the analyses answer, named for what it shows>
## Discussion        what the sections say, expectation by expectation
### Limitations      what else could produce the result and what it does not show
### Open questions  follow-up questions, each with a test and the outcome that would refute it
## Terms             a glossary, as a list of "term: definition" lines
```

- Terms is a glossary at the end, for any word a reader may need a reminder of or that is niche in the field. It is loose: it is not limited to words that clash with the literature. Each term is also defined in the prose where it first appears, so a reader never has to jump. Use the literature's word, say where this notebook departs from it, and give each term one meaning.
- Name an analysis section for what it shows ("Who the partners are", "Where the data put the cutoff"), not "Results": that word says the work is final, and the notebook is the current understanding. Give each analysis its own `##` heading; do not wrap them in a `## Results`. The order the work was done in lives in git and the issues.
- Do not label sections planned or exploratory: a question notebook is exploratory as a whole. An exploration that changed a decision gets its own section before the method it motivated, and states the decision.
- Write in any order. The cell graph does not depend on cell order, so jump between sections while developing, and reread the notebook top to bottom at each commit and reorder it for the reader.
- Background does not need a quote for every claim. Quote where a passage carries the claim, paraphrase with a link where none does, and leave out a general introduction to the system. A claim the notebook cannot fully test gets an open question.
- Each exclusion or data quirk the analysis handles gets one sentence in the Background saying where it comes from, with a source quote when the literature has one.
- Phrase expectations and plans plainly ("should give a smooth curve"), not as stacked hedges.
- An expectation says what the data would look like without the effect, and why. Do not assume a distribution family (power law, normal) without a reason.
- The expectations come before the methods and the analysis sections and are stated as they were posed. They are reasoning that warrants the experiments, not labeled hypotheses. Do not dress a post-hoc finding as an expectation; report it as found.
- Do not bake an exclusion into the definition of what is analyzed. Define the objects of study as broadly as the question allows, apply an exclusion after the first result, and show its effect beside the unfiltered version.
- A cutoff or parameter taken from a convention is named and commented as a standard the notebook tests. When the data could set it, add a section that derives it (a fitted breakpoint, marks spaced on a log scale) instead of marks picked by hand.
- When a filter decides which records count (quality, completeness, a proofread flag), run the main analysis on the records the question is about and show the unfiltered version beside it in the figures where it changes the conclusion.
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

- Choose the tool by what the picture must get right. Use **mermaid** (`mo.mermaid`) for flow and process: pipelines, decision logic, data lineage, where automatic layout is fine and the text source is the point. Use **manim** when the schematic should look designed and geometry carries meaning: nodes, arrows as wide as their weight, LaTeX labels, a legend. Use **matplotlib** when the picture is a plot with computed geometry. mermaid reorders nodes and routes edges on its own. Render once and look before keeping any of them.
- manim draws a still: render the scene inside `mn.tempconfig({... "save_last_frame": True, "output_file": "<name>", "media_dir": <temp dir>})` and show the PNG with `mo.image`. The scene class is an `@app.class_definition` that takes its data as constructor arguments and reads colors from the setup (a class defined inside a cell breaks the rule that cells define no functions), and needs a demo cell like any definition. It needs system LaTeX, cairo, and pango, and a cold render takes seconds. Use manim directly; video-oriented manim skills (scripts, `final.mp4`) are more than a still needs.
- Build the toy input in the cell and compute the labels with the notebook's own functions, so the picture cannot disagree with the code. A single-use diagram is drawn inline in its cell, not in a function.
- Pick toy values that make the distinction visible: the case where two definitions disagree, or where excluded context would change the answer.
- One color per role, gray for context the definition excludes. Colors are setup constants with their roles in a comment.
- Show the context the definition leaves out, not only what it counts: units of another class, contacts it ignores (dashed), and a unit that connects to several targets. Use the fewest units that can carry all of that.
- Follow it with a one-line interpolated caption that says what the toy example shows.

## Figures

Keep aesthetics at the defaults. Set one base look in the setup cell, and let a plot state a size, color, marker, or line width only when the data or the reader needs it, with a short comment saying why: one color per category, a figsize for a multi-panel grid, a marker area that encodes a count, a thick line so a fit stays visible over its curve.

```python
# Base look of every figure: one color per category, used everywhere, so a plot states only what its data needs.
CATEGORY_COLORS = {"a": "#D55E00", "b": "#E69F00", "c": "#0072B2", "d": "#009E73"}  # colorblind-safe

plt.rcParams.update(
    {
        "axes.prop_cycle": cycler(color=list(CATEGORY_COLORS.values())),
        "axes.spines.top": False,
        "axes.spines.right": False,
        "legend.frameon": False,
        "figure.constrained_layout.use": True,
    }
)


@alt.theme.register("lab", enable=True)
def lab_theme() -> alt.theme.ThemeConfig:
    return alt.theme.ThemeConfig(
        {
            "config": {
                "view": {"stroke": "transparent"},
                "range": {"category": list(CATEGORY_COLORS.values())},
            }
        }
    )


mn.Text.set_default(font="DejaVu Sans")  # only when the notebook uses manim
```

Move it to a shared module next to `config` when a second notebook needs it.

- Axis limits follow the data. Do not leave an empty decade because another panel reaches it, unless panels share an axis on purpose.
- Show the groups side by side. A dropdown that shows one group at a time hides the comparison the figure exists for.

### Interactive figures

When a reader would ask "which points are those?", make the figure selectable and show the selection in the next cell. Choose the widget by what the figure needs.

| need | use | notes |
|---|---|---|
| altair look, tooltips, legend clicks, one chart | `mo.ui.altair_chart(chart, chart_selection="interval")` (or `"point"`); `.value` is the selected rows | layered chart: put an explicit `alt.selection_interval` on one layer and read `chart.apply_selection(df)`. Faceted chart: a brush in one panel filters every panel's data, so use one widget per panel. Never enable the vegafusion transformer; it silently turns selection off. Ids above 2^53 go in chart data as strings |
| matplotlib look (shading, annotations, log axes), region selection | `mo.ui.matplotlib(ax)`: drag a box, shift-drag a lasso; `.value.get_mask(x, y)` on the arrays that were plotted | one axes per widget; no hover or click. Several panels: one figure per panel, collected in a `mo.ui.dictionary` and laid out with `mo.hstack` and `mo.vstack` |
| 3D, WebGL point clouds, click and box on subplots | `mo.ui.plotly(fig)`; `.value` lists points with `curveNumber` and `pointIndex` | the reader must pick the box-select tool before dragging |

```python
# One cell builds the widgets, one lays them out, and a later cell reads the selections.
_widgets = {}
for _group in groups:
    _fig, _ax = plt.subplots()
    _ax.scatter(data[_group]["x"], data[_group]["y"])
    _widgets[_group] = mo.ui.matplotlib(_ax)
    plt.close(_fig)
panels = mo.ui.dictionary(_widgets)
mo.hstack([panels[_group] for _group in groups])
```

- Build the mask from the same arrays the figure plotted; store jittered coordinates in the frame so the plotted and the selected positions agree.
- The selection cell starts with `mo.stop(not widget.value, mo.md("_Nothing selected._"))` and ends with the selected rows as a table.
- A drag cannot be simulated inside marimo. Run the notebook with `marimo run`, drive it with Playwright (the Python package only, `uv run --with playwright`, and the system Chrome through `executable_path`), and read the result cell. marimo's widgets sit in shadow DOM, so work from screenshot coordinates after scrolling the `#App` container. Otherwise say you only checked the filter.

## Libraries

Pick by scenario, not one library for everything. Each row is where the library is the best tool; leave it when its "not for" applies.

| library | use it for | not for |
|---|---|---|
| polars | every table you read, reshape, join, or aggregate; `scan_csv` and `scan_parquet` for files larger than memory. marimo displays it, and altair, matplotlib, and numpy accept it | |
| pandas | only at an edge where another library hands one back or demands one: `pl.from_pandas` on the way in, `.to_pandas()` on the way out. It stays a transitive dependency because many client libraries return it | pipelines you write |
| altair | charts that map columns to encodings: distributions, bars, small multiples, scatters up to a few thousand marks, with tooltips and legends | more than roughly 5,000 marks (aggregate in polars first), geometry you place by hand |
| matplotlib | figures you control mark by mark: shaded regions, annotations, chords drawn on a curve, shared-axis grids, rasters (`imshow`, `hexbin`), large point clouds, files written to `figures/` | hover tooltips |
| plotly | 3D, WebGL point clouds too large for altair, subplots that need click and box selection | figures that must match the base look |
| manim | explanatory schematics where layout is the point (see Diagrams) | data plots |
| mermaid | flow and process as text (see Diagrams) | geometry that carries meaning |

- Test polars membership with a list or a semi join; `is_in` with a Series is deprecated.
- Name the project's chart library for each figure kind in its `CLAUDE.md` only when the project departs from this table.

## Math

Display math is a definition or a claim, never decoration. A reader who takes the notation seriously must not hit an undefined symbol, an unstated domain, or a claim with no hypotheses. Prose is the default; a display earns its place when the precision is the point.

- Introduce every symbol before its display, with its domain ("$x_i \in \mathbb{R}^d$ the feature vector of sample $i$", "$w(i \to j)$ the count of events from $i$ to $j$").
- Mark definitions as definitions ("define", "write ... for"). A bare equation is a claim: give its hypotheses and a justification, or drop it.
- No program notation in math (`s.pre`, `df.col`). Define a map, or say it in prose.
- One meaning per symbol across the project. A category label is not a set of members: write $\mathrm{members}(G)$, or define groups as sets once.
- Set-builder displays get a left-hand side.
- If the display only restates one line of dataframe code in worse notation, use prose.

Bad: $S(R) = \{\, s : s.\mathrm{src} \in R \,\}$. Good: each record $s$ has a source $\mathrm{src}(s) \in U$; for $R \subseteq U$ define $S(R) = \{\, s : \mathrm{src}(s) \in R \,\}$, the records that start in $R$.

## Citations

Claims from the literature come from the user's Zotero library, not from memory (Zotero before web search).

- Find the item with `zotero_search_items`, its highlights with `zotero_get_annotations`, and an unmarked passage with `zotero_read_pdf_pages`. Quote exactly; never paraphrase inside quotation marks.
- Keep a citation line under the limit by giving the PDF link its own line (ruff exempts a line that ends in a URL): `> — Author year, p. N`, then `> · [PDF p. N](zotero://...)`, then `> · [doi](https://doi.org/...)`.
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
- Use the literature's words. Before naming a quantity, see what the papers you cite call it and use that word. Define each term once, where it first appears, and say there where you use it differently from the literature. Then keep one word per thing and one thing per word across prose, code names, column names, and figure labels.
- Introduce each table, function, and variable in prose by the name it has in the code (`census`, `connections`, `proofread_ids`), not by a descriptive name of its own.
- Load each table in one cell and pass the variable on. A later cell takes the variable; it does not call the loader again.
- marimo regenerates the file whenever it saves, so comments between cells and trailing comments on lines of `with app.setup:` and `@app.function` bodies are lost. Put a comment on its own line inside a cell, function, or setup block.
- Explanatory text is a markdown cell in complete sentences with transitions, not a comment at the top of a code cell. Introduce each definition, function, and figure with a markdown cell that says what it is for and what to look at. Comments stay for a choice at its site (a constant, a threshold) and stay short.
- Provenance lives in names, docstrings, and constants; let the dependency graph show data flow.
- A comment on a setup constant is one short line naming its role ("Colors by role.", "Standard cutoff for a strong partner, in synapses."). The options considered, the reasoning, and the concrete values go in the markdown where the reader meets the choice, not in the setup block. A choice comment at a call site is short prose: why this one; "arbitrary" when it is. Comments, docstrings, and markdown cells wrap at 72 characters (PEP 8), one thought per line.

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
5. Question notebook: introduction (question, background with expectations), methods, one section per analysis named for what it shows (no `## Results` wrapper), discussion (limitations, open questions), terms, in that order; each term is defined where it first appears; the discussion matches the rendered outputs.
6. Each `$$...$$` is research-grade; each definition that compares quantities or describes a structure has a diagram you have looked at.
7. No issue numbers and no code or debugging history in the notebook.
8. Each literature claim in the Background is quoted or linked as in Citations.
9. Figures use the base look, state aesthetics only with a reason, and use the library for their scenario; a selectable figure was dragged in a browser, or say you checked only the filter.

## Improving this skill

This skill grows from the user's edits to single notebooks.

- When the user leaves comments inside a notebook, treat each as an instruction: address it, apply the same fix to the rest of the notebook past the last comment, delete the comment, and add the general rule here.
- When the user suggests a meaningful change to one notebook (structure, prose, figures, math, naming, testing), make the change, then decide whether it applies to research notebooks in general.
- If it does, end the reply by offering a skill update: quote the exact text to add or change and name the section. Do not edit the skill until the user agrees, unless they asked for the skill change directly.
- Skip one-off preferences and data-specific fixes; say "already covered by <section>" when relevant.
- Keep the skill domain-neutral: examples use generic data, not one project's field.
- Edit the stow target `~/dotfiles/home/claude/.claude/skills/marimo-research/SKILL.md` (not the `~/.claude` symlink) and commit in `~/dotfiles` with only that file staged.
