# Maintaining the manim skill

Not linked from SKILL.md, so it is not loaded with the skill.

## Provenance

Written 2026-10-09 from two MIT-licensed skills, read and reduced rather than copied:

- Yusuke710/manim-skill (commit efb82d2): the video workflow (plan, one class per scene, subtitles, render, ffmpeg concat). Left out: its viewer tool, the long plan template, and the hard dependency on the second skill.
- adithya-s-k/manim_skill, `manimce-best-practices` (commit cef0450): the Community Edition versus ManimGL distinction. Left out: the 22 rule files and examples. They restate the Manim documentation, which current models know.

The still-diagram section comes from the lab project's `lab.connectome.draw` module (`src/lab/connectome/draw.py`). It began as `champalimaud.draw`, when the project was named champalimaud.

Revised 2026-11-25 for manim 0.22.0, which the lab now pins, and to add the workflow (`references/workflow.md`). The user asked: "can you look at all the already existing manim skills that must exist and help me create our own manim skill, I also want to think about an optimal workflow for building manim animations or diagrams in general even if I weren't using AI." Sources read that day:

- The 0.22.0 changelog (`docs/source/changelog/0.22.0-changelog.md`, clone at `~/projects/upstream/manim`, tag v0.22.0): the output rework in SKILL.md.
- awesome-skills/manim-skill (f8479fa): reviewing at the watching width, and frames on both sides of a transition.
- logan-gatlin/manim-skill (2900a5e, no licence, ideas only): `-s -n 0,K` keyframes, `</dev/null`, a reading-time hold.
- thomasahle/tensorgrad `paper/animations/SKILL.md` (c1696c8): review the final too, since 480p hides small gaps.
- ApliroAI/manim-video-lab (6219393): `freezedetect` for dead air.
- Yusuke710/manim-skill (a0048d9): narration first, durations into `run_time` and subtitles.
- 3b1b/videos `CLAUDE.md` (3a3b934) and README, and 3b1b/manim's `scene_embed.py`: the ManimGL interactive workflow in "By hand".
- neuVid (connectome-neuprint/neuVid): camera poses from the bounds of what they frame.
- D. A. Barceló Nieves, 2023 blog post (dabnciencias.github.io): a section per phrase, `-ql` clips against narration in Kdenlive.

Left out, because they are wrong for 0.22 or restate the docs: "`Text` is not a VMobject", "never animate mobjects not yet added", "use monospace, Pango kerning is broken", "updaters freeze during `wait`", "`Table` of strings makes `MathTex`" (0.22's default is `Paragraph`), and the Hermes-agent skill family's API lists.

## Verified against manim 0.22.0 (2026-11-25)

- The names in the SKILL.md table are missing (`hasattr` on the installed package); their replacements exist.
- Qualities from `manim.constants.QUALITIES`; the default is `high_quality`.
- `-l` is `--live-preview` (`manim render --help`); `-ql` is still low quality.
- `-s -n 0,K` saves the frame after animation K, counting plays and waits from 0 and across sections; `-n A,B`, `--dry_run`, `--format png-sequence`, `--save_sections` with `skip_animations=True` (the skipped section writes no clip), checked on a three-section scene.
- An unknown scene name in a file of two scenes prompts on stdin; with `</dev/null` manim exits 1. A file of one scene renders it whatever the name.
- `scene.renderer.file_writer.final_file_path` is the PNG after a still render under `tempconfig`.
- `Text(width=2)` scales one line to width 2 (no wrap).
- The ffmpeg contact sheet (`tile`, `sheet_%02d.png` for several) and `freezedetect` commands run as written.
- 2026-11-26, from the lab's lobula columns opening test: the doubled `frame_center` (a standalone `ThreeDCamera` matched the scene's own projection only with the world shifted; refresh it with `reset_rotation_matrix()` after setting angles), unblended `PMobject` colours (`Camera.display_point_cloud` writes RGBA into the pixel array), `-s` failing on a `ThreeDSlide`, a hand-written deck JSON converting and stepping in headless Chrome, and manim-videos covering manim text placed over its clip.
- manim-slides 5.7.0 fails on 0.22 (`ManimConfig has no attribute write_to_movie`); the lab pins the branch of jeertmans/manim-slides PR #713 (commit 3b31cde) until a release has it. Recheck then.

Not verified: `interactive_embed()` with `--renderer=opengl -l` (read in the source only; it needs a window), Manim Sideview and manim-voiceover with 0.22, and the reading-time figure (150 words a minute, from logan-gatlin).

## Recheck when manim updates

0.22.1 (2026-10-27, an `ImageMobject` fix) was out on 2026-11-25. 0.30.0a1 (pre-release, 2026-11-22) gives every camera an animatable `camera.frame`, deprecates `MovingCameraScene`, and adds `--timeline-output` (play and wait times as JSON, which could replace the contact sheet for timing checks); recheck the camera notes and the review commands when the project moves to it.

## Tested (2026-11-25)

One request run by a fresh Opus 5.5 agent with the skill ("a three-step animation of a point rotated by 90 degrees, at low quality, and be confident it looks right"). It read SKILL.md and workflow.md, rendered a still per beat with `-s -n 0,K`, fixed four layout faults there, and caught captions that crossfaded unreadably only through the mid-transition frames (the one-a-second sheet missed them). It skipped asking about beats and showing stills, as the request gave the beats and asked for a finished result.

## Blender (2026-11-26)

`references/blender.md` comes from the lab's lobula columns movie, where the user chose Blender over manim's point clouds after seeing both versions of the opening. Its gotchas were each hit and fixed there (Blender 5.3, EEVEE, the distro package); the timing is from a 6 GB RTX 4050 laptop.
