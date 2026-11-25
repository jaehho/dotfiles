---
name: zotero
description: Works in the user's Zotero library through the Zotero MCP. Reads one paper completely alongside the user and stays ready for questions, highlights passages (tagged `claude`), and adds items or attaches PDFs so the files actually sync (WebDAV, open-access routes, blocked hosts, PMC's proof-of-work). Use when the user is reading a paper or says to read one with them, when a reply or notebook cites a paper, or when adding, attaching or annotating Zotero items. Not for Zotero plugin development (~/projects/zotero).
---

# Zotero

The MCP runs hybrid: reads come from the local Zotero, writes go through the web API, because local writes need Zotero 10 and the running Zotero is older. `zotero_write_capabilities` reports the mode. Gotchas are issues: `gh issue list -R jaehho/zotero --label gotcha --state all --search <term>`.

## Read a paper with the user

Load the paper, read all of it, give a short orientation, then stop and answer questions. No summary, notes file or review unless asked: the user is reading, you are the second pair of eyes.

In a tutor session (the `tutor` skill), its reading order replaces the orientation: nothing about the paper before the learner's own first pass, and the tutor decides what gets written into the primer.

1. Resolve the item, in order: the citation key or item key they name, a DOI or URL, the paper they have open (ask only if that is ambiguous). Use `zotero_search_by_citation_key` or `zotero_search_items`.
2. `zotero_get_item_metadata`, then `zotero_get_pdf_outline` if the attachment has one.
3. `zotero_get_item_fulltext`. If it returns a saved path because the body is too large, read that file in sequential chunks to the end. Never claim a full read after skipping the methods or references. If the fulltext is missing or garbled, use `zotero_read_pdf_pages` in page ranges from the outline.
4. If the MCP fails on the attachment ("Only local paths are allowed", WebDAV 401, "requires local mode"), the file is still on disk: get the attachment key from `zotero_get_item_children`, then `pdftotext -layout ~/Zotero/storage/<key>/<file>.pdf` into the scratchpad. Go straight there; don't ask the user to fix Zotero.
5. Figure legends come out of extraction jumbled (panel labels on bare lines): read them as captions, not prose. Open a figure as an image (`format='image'`) only when a question needs it.

The orientation is under about 20 lines: what the paper is, a section map, the main claims, and the caveats the authors state. Then wait.

When answering, ground every claim in the paper and separate what the authors show from what they speculate. Quote tightly when the wording matters. Read the page or figure a question needs before answering it. When unsure, say what the paper doesn't cover. One paper at a time: a second paper is a new read or an explicit comparison.

## Highlights and annotations

- Tag every annotation you make `claude` (`tags=['claude']` on create, `add_tags=['claude']` on update) and leave its color alone unless the user names one: they filter by the tag and keep colors for their own coding.
- When a reply or notebook cites a passage that has no highlight, create the highlight without asking and link its annotation key (standing permission, 2026-10-08). Changing or deleting an annotation the user made is a write: ask first.
- Annotation tools take the PDF attachment key (`zotero_get_item_children`); fulltext and outline take the parent. Text: `zotero_create_annotation(text=..., comment=..., tags=['claude'])`. A figure or table: `zotero_get_page_layout`, then `rect=...`.
- The notebook citation format is in the marimo-research skill (`references/citations.md`).
- Don't reorganize the library, retag items, edit metadata or write notes (`zotero_manage_note`) unless asked.

## Adding items and attaching PDFs

Files sync through WebDAV (Nextcloud), not Zotero File Storage. A web-API attach reaches WebDAV only while the WebDAV credentials are in `~/.config/zotero-mcp/config.json`; without them the file lands in Zotero File Storage, which the desktop never downloads (jaehho/zotero#18). Metadata (`zotero_get_item_children`) can't show a missing file, so check `~/Zotero/storage/<attachment key>/`.

Before fetching a PDF yourself, read [references/finding-pdfs.md](references/finding-pdfs.md): the attach call that works, the open-access routes in order, the hosts that block scripts, and PMC's proof-of-work.
