---
name: read-article
description: Read one paper completely alongside the user (usually from Zotero) and stay ready for questions. Use when the user is reading an article/paper and wants it loaded for co-reading or Q&A, or says to read something with them. Not for library-wide literature search, citation export, or writing a lit review.
---

# Read an article alongside the user

Load the paper from Zotero, read it all the way through, give a short orientation, then stop and answer questions. Do not write a full summary, notes file, or review unless asked. The user is reading the paper; you are the second pair of eyes.

## Resolve the item

Prefer, in order: the citation key or item key they name; a DOI/URL; the paper they have open (ask only if it is ambiguous). Use `zotero_search_by_citation_key` or `zotero_search_items`. Check Zotero before the web for any cited work.

Get `zotero_get_item_metadata` first (title, authors, year, abstract). Then `zotero_get_pdf_outline` if the attachment has one. Those two are cheap and orient both of you.

## Read the whole paper

1. `zotero_get_item_fulltext`. If it returns a saved path because the body is too large, extract the text and read that file in sequential chunks until 100% is covered. Do not stop early and do not claim a full read if you skipped methods or references.
2. If fulltext is missing or garbled, fall back to `zotero_read_pdf_pages` in page ranges (use the outline).
3. Figure legends in extracted text are often jumbled (panel labels become bare lines). Read the body carefully; treat legend text as figure captions, not prose. Open the figure as an image (`format='image'`) only when a question needs the figure.

## After the read

Give a short orientation: what the paper is, section map, main claims, and the caveats the authors themselves state. Under ~20 lines. Then wait for questions.

When answering:
- Ground every claim in the paper. Distinguish what the authors show from what they speculate.
- Quote or paraphrase tightly when the wording matters.
- If a question needs a figure or a specific page, read that page/figure then answer. Do not pad answers with unrelated sections.
- If you are not sure, say what the paper does not cover.

## Highlights and annotations

Tag every annotation `claude` so it is filterable.

- Find the PDF attachment key with `zotero_get_item_children` (parent key works for fulltext/outline; annotation tools want the attachment key).
- Text highlights: `zotero_create_annotation(text=..., comment=..., tags=['claude'])`.
- Figures/tables: `zotero_get_page_layout` first, then `zotero_create_annotation(rect=..., tags=['claude'])`.

## Boundaries

- One paper at a time. A second paper is a new read (or an explicit compare).
- Do not reorganize the Zotero library, retag items, or edit metadata as a side effect.
- Notes into Zotero (`zotero_manage_note`) only when asked.
