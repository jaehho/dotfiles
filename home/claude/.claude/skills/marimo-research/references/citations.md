# Citations

Read this before you cite a claim from the literature in a notebook.
SKILL.md has the rules that always apply.

Claims from the literature come from the user's Zotero library, checked
before any web search.
If nothing there supports a claim, say so and do not cite it.
Quote the work that established a fact. A paper is the source of its own
findings and definitions; a sentence that cites other work, or restates
textbook knowledge, points to the original. Find the original, add it to
Zotero (by script when it is open access, otherwise the user downloads
it), and quote it.
A claim that rests on a conversation is attributed to the person by
name as personal communication, without a date.
A claim with no source is computed from the data in the notebook or
left out.

- Find the item with `zotero_search_items`, its highlights with
  `zotero_get_annotations`, an unmarked passage with
  `zotero_read_pdf_pages`.
  Quote exactly; never paraphrase inside quotation marks.
- Quote as a blockquote of the highlight, then
  `> — Author year, p. N · [PDF p. N](zotero://open-pdf/library/items/<attachment key>?page=<PDF position>&annotation=<annotation key>) · [<doi>](https://doi.org/<doi>)`,
  on one line.
  N is the number printed on that page, in its header or footer; a first
  page that prints only the article's range ("Cell 189, 5552–5570") is
  the range's first number. Do not take Zotero's stored page label
  (`page` in `zotero_get_annotations`) on trust: some PDFs label every
  page 1, and pages that print no number, such as online Methods, get
  labels past the article's range. A page that prints no number is cited
  by its section (`Methods`, `Extended Data`), and a preprint, which has
  no pagination of its own, by its PDF page. Where the project has a
  citation check (a script that reads each quote's PDF page), run it.
  `page=` in the link is different: Zotero reads it as the PDF position,
  `pageIndex + 1` from the annotation's position.
  The user's annotation comment goes outside the quote, as complete
  sentences.
  No citekeys.
- A passage with no highlight gets one when you cite it:
  create the highlight (`zotero_create_annotation`, tag `claude`, no
  recoloring) and put its key in `annotation=`.
  No link is left with an empty `annotation=`.
- In running text, cite `[Author et al. year](https://doi.org/<doi>)`.
