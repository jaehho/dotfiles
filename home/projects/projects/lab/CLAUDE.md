# lab

Fly visual system and locomotion.

- Run `make test` before you report work done.
- Paths live in `src/lab/connectome/config.py`, remote ids in `src/lab/connectome/fetch.py`, and network imports in `fetch.py`. `tests/test_boundaries.py` enforces those three. Only `fetch.py` writes `data/`.
- A new cell type needs no fetch: `data/connections.parquet` holds the connections of every proofread neuron. A notebook filters it with `load.load_connections_of`.
- Do not hand-edit what `docs/gen_site.py` writes (`docs/book.yml`, the home page). Book settings live in `book_config` there. `make docs` regenerates them.
- Search `gotcha` issues before you debug CAVE, fafbseg, or marimo.
- Paper notes live in Zotero.

## Notebooks

- One notebook per question (for example `lc_pathways`), and every notebook is published as one: the site has no sections. A figure is a function in `lab.connectome.plots` that its question notebook calls and saves to `config.FIGURES`.
- A new notebook also gets a symlink in `docs/content/notebooks/`, made with `ln -s ../../../notebooks/<file>.py` from that folder. Without it the table-of-contents entry that `docs/gen_site.py` writes points at nothing.
- A notebook opens with `# Title`, `## Introduction`, `### Question`. The home page card shows the paragraph under `### Question`, so a notebook without one has an empty card.
- `pyproject.toml` ignores `E501` in `notebooks/` (markdown cells are one line per paragraph), so keep code lines under 79 by hand or with `ruff format`. `W505` runs only under `src/`.
- Name another notebook in prose as a link, `` [`stem`](?file=stem.py) ``. `uv run python tools/link_notebooks.py --fix` rewrites bare names and warns about links to notebooks that no longer exist. Links may be cyclic.
- A follow-up of one notebook carries its parent's stem as a prefix (`lc_output_strength_definitions`) and links to it. A notebook that builds on two notebooks is a new root and takes no prefix. Listing the notebooks in name order puts each parent before its children.

## Package (`src/lab/connectome`)

- A function moves into the package when another current notebook can use it. Otherwise it stays in its notebook.
- Docstrings are numpydoc. Name no callers or notebooks (they go stale) and tell no project history (it goes in an issue).
- Every public function has an example: a doctest on a small input with generic names. pytest runs it (`--doctest-modules`), so the example is the function's test, and `make docs` shows it in the API reference. A function that reads a file takes its path as an argument (default: the `config` path), and its example writes a toy file to a temp folder. A function that calls the network or needs the real `data/` is listed in its module's `__doctest_skip__` (`conftest.py` skips those doctests), and its example shows real output from a run. Its logic is tested in `tests/` with `monkeypatch`, not by extra arguments.
- A function that returns a figure (matplotlib, plotly, PNG bytes, or an HTML string) ends its example by binding it to `figure`, on an input that looks like data. `docs/api_figures.py` runs the example and embeds the result; it runs only examples that bind `figure`, so a `+SKIP` example that fetches is shown and never executed. Do not assert on the figure.
- `lab.connectome.strength.CLASSIFIERS` holds the ways to call a partner strong, all with one signature. `config.CLASSIFIER` names the one notebooks use.

## Notes

- A note names another note, a meeting summary, or a cell type that has a note with an Obsidian link, never a path in a code span: `[[connectomics]]` by filename, a path suffix only where the name is not unique (`[[types/README]]`), an alias for a date-stamped name (`[[2026-10-20-1014-lc-connectome-analysis-review|2026-10-20 meeting]]`). The vault is `~/Obsidian`, where `lab/` is a symlink to `notes/`.
- Link a type at its first mention in each heading section (the intro before the first heading is one) and not again in that section. Repeat the link in a table or a list that works as data. Do not link in a heading, a code span, a quotation, or frontmatter.
- A type with no note yet gets the same link once a notebook or a meeting talks about it: a dangling link is a note still to write. Other cell types stay plain text.
- A type note has no "See also" section; the first-mention links carry the edges.
