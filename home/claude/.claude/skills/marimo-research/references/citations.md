# Citations

Read this before you cite a claim from the literature in a notebook.
SKILL.md has the rules that always apply.

Claims from the literature come from the user's Zotero library, checked
before any web search.
If nothing there supports a claim, say so and do not cite it.
A claim that rests on a conversation is attributed to the person by
name as personal communication.
A claim with no source is computed from the data in the notebook or
left out.

- Find the item with `zotero_search_items`, its highlights with
  `zotero_get_annotations`, an unmarked passage with
  `zotero_read_pdf_pages`.
  Quote exactly; never paraphrase inside quotation marks.
- Quote as a blockquote of the highlight, then
  `> — Author year, p. N · [PDF p. N](zotero://open-pdf/library/items/<attachment key>?page=N&annotation=<annotation key>) · [<doi>](https://doi.org/<doi>)`,
  split at the `·` so no line passes the limit.
  N is the page label Zotero stores on the annotation (`page` in
  `zotero_get_annotations`, often the journal page), not the PDF index.
  The user's annotation comment goes outside the quote, as complete
  sentences.
  No citekeys.
- A passage with no highlight gets one when you cite it:
  create the highlight (`zotero_create_annotation`, tag `claude`, no
  recoloring) and put its key in `annotation=`.
  No `annotation=` is left in a notebook.
- In running text, cite `[Author et al. year](https://doi.org/<doi>)`.
