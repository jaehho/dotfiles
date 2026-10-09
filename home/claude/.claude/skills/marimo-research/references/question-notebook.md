# Question notebooks

Read this when you write or restructure a question notebook.
SKILL.md has the rules that always apply.

A question notebook is the log of one question, two at most.
The usual order: Introduction (the question, then the background with the
expectations), Load data, one section per analysis, Discussion (with
Limitations and Open questions), Terms.

- **Question**: one sentence, no definitions or notation.
- **Background**: only what bears on the question.
  Each exclusion or data quirk the analysis handles gets one sentence
  saying where it comes from.
  Quote where a passage carries the claim, link where none does.
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
  disagree"), not "Results", and headings are plain: no dates, "Hypothesis",
  or planned/exploratory labels.
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
- **Terms** is a glossary of words a reader may need a reminder of.
  Each is also defined in the prose where it first appears.
- A new question is a new notebook.
  Earlier conclusions are not rewritten; a later notebook corrects an earlier
  one and says so in both.
- Write in any order while developing; reread top to bottom at each commit
  and reorder for the reader.
