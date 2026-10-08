# Figures: base look, selectable figures, schematics

Read the section you need; `SKILL.md` has the rules that always apply.

## Base look

Set it once in the setup cell, so a plot states only what its data needs.
Take the colors from the project's palette.

```python
CATEGORY_COLORS = {"a": "#rrggbb", "b": "#rrggbb"}

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
```

## Selectable figures

When a reader would ask "which points are those?", make the figure
selectable and show the selection in the next cell.

| need | use | notes |
|---|---|---|
| altair look, tooltips, legend clicks, one chart | `mo.ui.altair_chart(chart, chart_selection="interval")` (or `"point"`); `.value` is the selected rows | layered chart: put an explicit `alt.selection_interval` on one layer and read `chart.apply_selection(df)`. Faceted chart: a brush in one panel filters every panel's data, so use one widget per panel. Never enable the vegafusion transformer; it silently turns selection off. Ids above 2^53 go in chart data as strings |
| matplotlib look (shading, annotations, log axes), region selection | `mo.ui.matplotlib(ax)`: drag a box, shift-drag a lasso; `.value.get_mask(x, y)` on the arrays that were plotted | one axes per widget; no hover or click. Several panels: one figure per panel, collected in a `mo.ui.dictionary` and laid out with `mo.hstack` and `mo.vstack` |
| 3D, WebGL point clouds, click and box on subplots | `mo.ui.plotly(fig)`; `.value` lists points with `curveNumber` and `pointIndex` | the reader must pick the box-select tool before dragging |

```python
# One cell builds the widgets, one lays them out,
# and a later cell reads the selections.
_widgets = {}
for _group in groups:
    _fig, _ax = plt.subplots()
    _ax.scatter(data[_group]["x"], data[_group]["y"])
    _widgets[_group] = mo.ui.matplotlib(_ax)
    plt.close(_fig)
panels = mo.ui.dictionary(_widgets)
mo.hstack([panels[_group] for _group in groups])
```

- Build the mask from the same arrays the figure plotted; store jittered
  coordinates in the frame so the plotted and the selected positions agree.
- The selection cell starts with
  `mo.stop(not widget.value, mo.md("_Nothing selected._"))`
  and ends with the selected rows as a table.
- A drag cannot be simulated inside marimo.
  Run the notebook with `marimo run`, drive it with Playwright
  (the Python package only, `uv run --with playwright`,
  and the system Chrome through `executable_path`),
  and read the result cell.
  marimo's widgets sit in shadow DOM,
  so work from screenshot coordinates after scrolling the `#App` container.
  Otherwise say you only checked the filter.

## Schematics

A definition that compares two quantities or describes a structure
(an aggregation, a graph motif, a pipeline) is easier with a small
schematic next to it.

- Choose the tool by what the picture must get right.
  **mermaid** (`mo.mermaid`) for flow and process, where automatic layout is
  fine and the text source is the point.
  **manim** when the schematic should look designed and geometry carries
  meaning: nodes, arrows as wide as their weight, LaTeX labels, a legend.
  **matplotlib** when the picture is a plot with computed geometry.
  mermaid reorders nodes and routes edges on its own.
  Render once and look before keeping any of them.
- Build the toy input in the cell and compute the labels with the notebook's
  own functions, so the picture cannot disagree with the code.
  Pick toy values that make the distinction visible: the case where two
  definitions disagree, or where excluded context would change the answer.
- Show the context the definition leaves out, not only what it counts:
  units of another class, contacts it ignores (dashed), a unit that
  connects to several targets.
  Use the fewest units that can carry all of that.
  One color per role, gray for context the definition excludes.
- Follow it with a one-line interpolated caption that says what the toy
  example shows.
- manim draws a still.
  Build the mobjects in the cell and show them through a shared helper that
  renders a PNG for `mo.image`.
  manim compiles LaTeX when a mobject is made, so set
  `manim.config.media_dir` once at import;
  a `tempconfig` around the render is too late and writes `media/` into the
  working directory.
  Dim with a helper that touches only the strokes and fills that exist,
  because `set_opacity` fills an open arc into a D.
  It needs system LaTeX, cairo, and pango.
  Use manim directly; video-oriented manim skills are more than a still needs.
