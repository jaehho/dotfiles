export const meta = {
  name: 'primer-outline',
  description: 'Read the papers behind a subject in parallel and draft a primer outline: sections, the figure for each, the quotes, how the papers connect',
  whenToUse: 'Before writing a primer (marimo-research references/primer-notebook.md) on a subject drawn from several papers. args: {subject: "...", papers: ["Zotero item key, DOI, or Author year", ...], notes: "optional: what the primer is for"}',
  phases: [
    { title: 'Read', detail: 'one agent per paper' },
    { title: 'Outline', detail: 'one agent drafts the primer from all papers' },
    { title: 'Check', detail: 'every quote against its PDF page' },
  ],
}

const subject = (args && args.subject) || ''
const papers = (args && args.papers) || []
const notes = (args && args.notes) || ''
if (!subject || !papers.length) {
  throw new Error('args needs {subject: string, papers: [string, ...]}')
}

const FIND_PDF = `Find the paper's PDF without the Zotero MCP, so the user's Zotero stays responsive: copy ~/Zotero/zotero.sqlite and, if present, ~/Zotero/zotero.sqlite-wal into a temporary folder and query the copy with python3's sqlite3. Titles and DOIs are in itemData joined to fields (fieldName 'title', 'DOI', 'date') and itemDataValues; authors in itemCreators joined to creators (lastName); a PDF is a row of itemAttachments with parentItemID the paper's itemID and contentType 'application/pdf', whose items.key is the attachment key; the file is ~/Zotero/storage/<attachment key>/. Read it with pdftotext (-f N -l N for one page, -layout to see headers and footers), or \`uv run --with pymupdf python -I\`. Use the Zotero MCP only if the paper has no PDF on disk, and then only to look it up. Create no annotations: highlights are made when a section is written.`

const CITE_RULES = `Quote exactly, from the PDF text. Read ~/.claude/skills/marimo-research/references/citations.md for which page number a quote carries and for what counts as secondhand (a paper is the source of its own methods, definitions and results); for a secondhand claim, name its original from the paper's reference list, with its DOI, and say whether it is in the user's Zotero (the same database copy). Give each quote's PDF page as well. Do not call the Zotero MCP and create no highlights or items: the session makes them after the user approves the outline.`

const PAPER = {
  type: 'object',
  properties: {
    reference: { type: 'string' },
    doi: { type: 'string' },
    item_key: { type: 'string' },
    attachment_key: { type: 'string' },
    what_it_did: { type: 'string', description: 'two or three sentences: the question, the data, the method' },
    contributions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          claim: { type: 'string' },
          kind: { type: 'string', enum: ['dataset', 'method', 'definition', 'result', 'limit', 'background'] },
          quote: { type: 'string' },
          page: { type: 'string', description: 'as printed, or the section' },
          pdf_page: { type: 'integer' },
          secondhand_original: { type: 'string', description: 'for a secondhand claim: the original, its DOI, and whether it is in Zotero; else ""' },
        },
        required: ['claim', 'kind', 'quote', 'page', 'pdf_page', 'secondhand_original'],
      },
    },
    figures: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          figure: { type: 'string', description: 'e.g. Fig. 3a,b' },
          shows: { type: 'string' },
          pdf_page: { type: 'integer' },
          best_copy: { type: 'string', description: 'per marimo-research references/figures.md: whether the PDF embeds the panels at high resolution or as vectors (pdfimages -list), or the publisher figure page URL' },
          license: { type: 'string' },
        },
        required: ['figure', 'shows', 'pdf_page', 'best_copy', 'license'],
      },
    },
    builds_on: { type: 'string', description: 'which of the other papers in this set it uses, and for what' },
    gaps: { type: 'string', description: 'steps the paper does not describe, limits it states, data it did not have' },
  },
  required: ['reference', 'doi', 'item_key', 'attachment_key', 'what_it_did', 'contributions', 'figures', 'builds_on', 'gaps'],
}

const OUTLINE = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    opening: { type: 'string', description: 'the paragraph under the title: what the primer covers and which papers' },
    sections: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          heading: { type: 'string' },
          explains: { type: 'string' },
          why_needed: { type: 'string' },
          figure: { type: 'string', description: 'the paper figure and panels to show, with its source; or, only where no paper has one or another view of the same thing helps, the figure to draw and why' },
          toy: { type: 'string', description: 'a toy example only for a general method a small example shows whole; else ""' },
          quotes: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                text: { type: 'string' },
                reference: { type: 'string' },
                page: { type: 'string' },
                attachment_key: { type: 'string' },
                pdf_page: { type: 'integer' },
              },
              required: ['text', 'reference', 'page', 'attachment_key', 'pdf_page'],
            },
          },
        },
        required: ['heading', 'explains', 'why_needed', 'figure', 'toy', 'quotes'],
      },
    },
    connections: { type: 'string', description: 'how the papers build on each other' },
    gaps: { type: 'array', items: { type: 'string' } },
    originals_to_add: { type: 'array', items: { type: 'string' }, description: 'originals of secondhand claims that are not in Zotero, with DOI and open-access status' },
  },
  required: ['title', 'opening', 'sections', 'connections', 'gaps', 'originals_to_add'],
}

const CHECK = {
  type: 'object',
  properties: {
    problems: {
      type: 'array',
      items: {
        type: 'object',
        properties: { where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } },
        required: ['where', 'problem', 'fix'],
      },
    },
    checked: { type: 'string' },
  },
  required: ['problems', 'checked'],
}

phase('Read')
const read = await parallel(papers.map((paper, i) => () => agent(
  `Read one paper for a primer on "${subject}"${notes ? ` (${notes})` : ''}. The paper: ${paper}. The other papers in the set: ${papers.filter((_, j) => j !== i).join('; ')}.

${FIND_PDF}

Read the whole paper, methods and figure legends included. Return what it contributes to the subject: its datasets, methods, definitions, results and stated limits, each with an exact quote; the figures that show them, each with how to get its best copy and its license; how it builds on the other papers in the set; and the steps it leaves undescribed. Leave out what does not bear on the subject.

${CITE_RULES}`,
  { label: `read ${paper}`, phase: 'Read', schema: PAPER },
)))
const extracts = read.filter(Boolean)
if (extracts.length < papers.length) {
  log(`${papers.length - extracts.length} paper(s) returned nothing; the outline covers ${extracts.length}`)
}

phase('Outline')
const outline = await agent(
  `Draft the outline of a primer on "${subject}"${notes ? ` (${notes})` : ''}, from these per-paper extracts:
${JSON.stringify(extracts, null, 1)}

Read the primer rules first: ~/.claude/skills/marimo-research/references/primer-notebook.md, and its figures.md and citations.md beside it. Then order the sections the way a reader needs them (for a body of papers, the order the work was built), give each one idea, the paper figure that shows it (draw one only where none exists or another view helps), and the quotes that carry its claims, using only quotes from the extracts. A toy only for a general method. Say how the papers connect, list the gaps, and list the originals of secondhand claims that are not in Zotero. Write nothing to disk, do not call the Zotero MCP, and add no items or highlights: the session adds them after the user approves the outline.`,
  { label: 'outline', phase: 'Outline', schema: OUTLINE },
)

phase('Check')
const check = outline && await agent(
  `Check a primer outline's quotes against their PDFs, adversarially. For every quote in the outline below, open the PDF (~/Zotero/storage/<attachment_key>/*.pdf, with pdftotext -f N -l N) and confirm the quote is word for word on that PDF page (allowing for line-break hyphens and ligatures), that its page follows the rules below, and that the quote supports what its section uses it for. Also flag a quote that is secondhand.\n\n${CITE_RULES}\n\nReport only real problems.
${JSON.stringify(outline, null, 1)}`,
  { label: 'check quotes', phase: 'Check', schema: CHECK },
)

return { subject, outline, check, extracts }
