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

Decide for each statement from a source, in this order:

1. Leave it out unless the reader needs it for what the notebook
   teaches or answers: to read a figure that follows, to follow a later
   step, or to know a limit of the result. What a source says about
   itself (how its sample was prepared, counts the notebook never uses)
   is left out.
2. Quote it when the exact words carry the point: a definition or a
   method step the notebook relies on, a number it uses, a limit the
   authors state, or a claim a reader may doubt. Quote only the sentence
   that carries it.
3. Otherwise say it in your own sentence and cite the source in running
   text (below); the sentence claims no more than the source does.

A figure from the paper that shows the point takes the place of a quote.

- Find the item with `zotero_search_items`, its highlights with
  `zotero_get_annotations`, an unmarked passage with
  `zotero_read_pdf_pages`.
  Quote exactly; never paraphrase inside quotation marks. A quote leaves
  out the paper's reference numbers ("connectome39" is quoted as
  "connectome"), and the Zotero highlight's text is edited to match
  (`zotero_update_annotation`).
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
