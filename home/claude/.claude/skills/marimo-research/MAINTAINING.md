# Maintaining the marimo-research skill

Claude does not load this file: SKILL.md does not link it.

Size: keep SKILL.md under 500 lines; the core aims for about 200. Move
detail into `references/`, link each file from SKILL.md with a line that
says when to read it, and keep references one level deep.

A rule earns a place here only if a research notebook on any topic is
better for it, not merely different.
A one-off preference, a data-specific fix, a tool or palette choice, and a
shape (a heading, a file name, a size) stay in the notebook or the
project's `CLAUDE.md` or `.claude/rules/`.
Before adding a rule, look for one to merge it into, or to remove.

- When the user leaves a comment inside a notebook, treat it as an
  instruction: address it, apply the same fix to the rest of the notebook
  past the last comment, and delete the comment.
- When the user suggests a change to one notebook, make it, then decide
  whether it passes the test above.
  If it does, end the reply by offering the skill change as exact text,
  naming the section.
  Do not edit the skill until the user agrees, unless they asked for the
  skill change directly.
- Keep the skill domain-neutral: examples use generic data.
- Edit the stow target `~/dotfiles/home/claude/.claude/skills/marimo-research/`
  (not the `~/.claude` symlink) and commit in `~/dotfiles` with only the
  skill's files staged.
