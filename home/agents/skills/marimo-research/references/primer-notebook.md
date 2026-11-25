# Primers

Read this when you write or extend a primer, or when a question
notebook's background runs long. SKILL.md has the rules that always
apply; this file has only what is specific to primers. The tutor skill
builds its teaching notebook as a primer and adds what a session needs.

A primer explains one subject from the literature: a method, a dataset,
or the papers a question builds on. It lets a question notebook keep its
background to a few sentences, and it lets someone new to the subject
follow it without a session. It is a reference notebook: present tense,
no question, no new analysis. Name it `primer_<subject>.py`. It goes in
the closest common folder above the notebooks that link to it; until one
links to it, in the area folder of its subject (ask when that is
unclear), moving down when its readers appear. Like a data notebook, it
names none of the notebooks that link to it. A primer needs no
exploration first.

## Shape

- Open with `# <Subject>` and a paragraph saying what the primer covers
  and which papers it draws on, linked.
- Then one section per concept or step, in the order a reader needs them.
  For a body of papers, follow the order the work was built (the data,
  then the methods on it) and say in each section how this paper builds
  on the ones before.
- A section opens with what it explains and why the subject needs it.
  Before each figure, one sentence says what to look at; after it, one
  sentence says what it showed. Between figures, two or three sentences
  at most.
- Every idea comes as a figure, a diagram, or a display equation. A
  display equation is worked once on numbers shown beside it, from the
  paper, the lab's data, or the section's toy where it has one.

## Figures

- The papers' own figures come first, from their best copy and credited
  (SKILL.md, Figures).
- Draw a figure only where no paper has one, or where another view of
  the same thing helps: the lab's data through the paper's method, two
  papers' figures side by side, a quantity a paper gives only in a table.
- A diagram follows the schematics rules (SKILL.md, Figures). Its few
  made-up units are a diagram, not a toy example.

## Toy examples

A toy is for a general method that a small example shows whole (PCA,
kernel regression, a convolution): built so the answer is known, small
enough to see whole, and then run through the project's code, or the
library the method is usually computed with, to show it agrees. A primer
on papers teaches through their figures and data and has no toy.

## Claims

- Every claim is quoted from the work that established it (SKILL.md,
  Citations): a paper's own methods, definitions and results from that
  paper, background from its original. Where the original is not in
  Zotero, add it before quoting.
- Say where a paper's account stops: a step it does not describe, a limit
  it states, data it did not have.
- The lab's data enters only to show a paper's method on it, read as the
  Data rules say. A result about the lab's data belongs in a question
  notebook.

## Building it

- A primer written in one go, for a subject drawn from several papers,
  starts with the `primer-outline` workflow: it reads each paper in
  parallel and drafts the sections, the figure for each, the quotes, and
  how the papers connect. The user approves the outline before any
  section is written. To add papers to a primer, run it on the new
  papers with the primer's headings in `notes`. One paper needs no
  workflow.
- A primer built in a tutor session has no outline first: it grows one
  section at a time as the learner works through the material (the tutor
  skill says when).
- Before calling it done, run the project's citation check where it has
  one, and check each claim against its original.
