# Writing CLAUDE.md, rules, skills, and READMEs

Checked 2026-10-09 against the sources at the end. These tools change, so
recheck the sources before you rely on a number here.

Terms: Claude Code is the terminal program that runs Claude. The
frontmatter is the block at the top of a SKILL.md file, between `---`
lines. Compaction is Claude Code's summary of a long session, which frees
context.

## Principles

These are working rules we derived from the sources below.

- One owner per rule. State it in one file. Other files point to it.
- A test or linter owns any rule it can check. Prose states only what no
  check can see.
- Put a rule where it loads at the right time:
  - `~/.claude/CLAUDE.md` (global) and a project's `CLAUDE.md`: every session.
  - `.claude/rules/*.md` with `paths:`: when Claude opens a matching file.
  - A skill: when Claude judges that a task matches the skill's description.
  - A test, linter, or hook: each time it runs.
- Keep a rule at its scope. Preferences for every project go in the global
  file. Facts about one project go in that project. A method that applies to
  several projects is a skill.

## CLAUDE.md

- Claude Code loads it at the start of every session as context. It is not
  enforced configuration. Specific, concise instructions are followed more
  consistently.
- Target under 200 lines. `@path` imports load at launch, so they save no
  context.
- Keep facts Claude cannot infer, rules Claude would break without, and
  pointers to other files.
- Drop file-by-file descriptions, anything Claude can read in the code, long
  procedures (move those to a skill), and facts that change often.
- Cut test: "Would removing this cause Claude to make mistakes? If not, cut
  it."
- If Claude skips one rule, emphasize that line alone. Emphasis on many lines
  leaves none of them standing out.
- Run `/doctor prompt-audit` in a Claude Code session (version 2.1.283 or
  later). It reports stale references and conflicting files, and it changes
  nothing until you approve.

## Path-scoped rules (`.claude/rules/`)

- Each file covers one topic.
- A file without `paths:` loads at launch, like CLAUDE.md.
- A file with `paths:` (a list of globs) loads when Claude opens a matching
  file:

  ```
  ---
  paths:
    - "src/**"
  ---
  ```

- A `CLAUDE.md` in a subdirectory loads when Claude reads, writes, or edits a
  file there.

## Skills

- The frontmatter has `name` and `description`. Claude uses the description to
  decide when to load the skill. Say what the skill does and when to use it,
  in the third person, with key terms first. The API caps the description at
  1,024 characters. Claude Code cuts the description plus `when_to_use` at
  1,536 characters in the skill listing.
- Claude consults a skill only for tasks it cannot easily do alone. A short,
  one-step request may not trigger a skill that matches it.
- Each skill's description sits in context every session. The body loads when
  the skill is invoked and stays in context. Compaction keeps the first 5,000
  tokens of each invoked skill.
- Keep SKILL.md under 500 lines. Move detail into files it links, one level
  deep: no reference file should link to another. Start a reference file
  longer than 100 lines with a table of contents. (The skill-creator guide
  says 300 lines.)
- Give each link a line that says what the file holds and when to read it.
- Keep the body concise. State what to do. Add a short reason where a rule
  could be applied wrongly. The Claude Code docs say to state what to do
  rather than narrate why; the skill-creator guide says to explain why. This
  line is our reconciliation of the two, not a quote.
- Match the detail to the risk. Give exact commands for fragile steps. Give a
  direction where judgment is needed.
- Test with the models you use. A skill written for one model may need more
  detail for another. Before and after each change, run three realistic
  requests and check the results against the skill's checklist.

## READMEs

- GitHub's guidance: a README "should only contain information necessary for
  developers to get started using and contributing to your project." Longer
  documentation goes to a wiki.
- standard-readme is a community spec written for libraries. Its required
  sections are Title, Short Description, Install, Usage, Contributing, and
  License. Sections must appear in the spec's order. Keep a Long Description
  to a few paragraphs and move the rest to Background. A Table of Contents is
  required only in READMEs of 100 lines or more.
- Give a contact line and a license if other people will use the repository.
- Test the README commands that a test can run, such as an import and a call
  to an entry point, so they do not drift.

## Sources

- Claude Code, memory (CLAUDE.md, rules, imports): https://code.claude.com/docs/en/memory
- Claude Code, best practices: https://code.claude.com/docs/en/best-practices
- Claude Code, skills: https://code.claude.com/docs/en/skills
- Agent skills, authoring best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- skill-creator guide (Anthropic plugin; local copy at `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/skills/skill-creator/SKILL.md`)
- GitHub, About READMEs: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes
- standard-readme spec: https://github.com/RichardLitt/standard-readme/blob/main/spec.md
- IFScale, "How Many Instructions Can LLMs Follow at Once?": https://arxiv.org/abs/2507.11538. The abstract reports that even the best frontier models reach 68% accuracy at 500 keyword-inclusion instructions in a business report task. It gives no values below 500. Read it as support for fewer rules per file, not as a threshold.

## Not verified

- Whether a path-scoped rule loads when Claude creates a new file. The docs
  say the rule loads when a matching file is opened.
- Whether a shorter skill helps a smaller model. Test it with the model you
  use.
