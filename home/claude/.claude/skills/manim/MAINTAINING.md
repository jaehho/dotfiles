# Maintaining the manim skill

Not linked from SKILL.md, so it is not loaded with the skill.

## Provenance

Written 2026-10-09 from two MIT-licensed skills, read and reduced
rather than copied:

- Yusuke710/manim-skill (commit efb82d2): the video workflow (plan,
  one class per scene, subtitles, render, ffmpeg concat).
  Left out: its viewer tool, the long plan template, and the hard
  dependency on the second skill.
- adithya-s-k/manim_skill, `manimce-best-practices` (commit cef0450):
  the Community Edition versus ManimGL distinction.
  Left out: the 22 rule files and examples. They restate the Manim
  documentation, which current models know.

The still-diagram section comes from the champalimaud project's
`champalimaud.draw` module.

## Verified against manim 0.21.0 (2026-10-09)

- The missing names in the SKILL.md table: checked with `hasattr` on
  the installed package.
- Default quality is `high_quality`; the quality table is in
  `manim.constants.QUALITIES`.
- A two-scene render at `-ql`, the `.srt`, the `concat` command, and
  the `-s` output path were run end to end.

## Recheck when manim updates

Manim 0.22.0 was available on 2026-10-09; the project pins 0.21.
Recheck the name table and the output paths after upgrading.
