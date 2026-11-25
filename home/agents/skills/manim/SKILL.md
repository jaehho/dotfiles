---
name: manim
description: Writes and renders Manim Community Edition scenes (the `manim` package, not 3Blue1Brown's `manimlib`): still diagrams for notebooks and figures, animations, 3D scenes of data, and explainer videos. Use for any task that imports `manim`, defines a `Scene`, uses `MathTex` or `Tex`, or runs the `manim` command.
---

# Manim

## Which manim

Community Edition (CE): `import manim as mn` or `from manim import *`, and the `manim` command. ManimGL is 3Blue1Brown's own package (`manimlib`, `manimgl`); tutorials, other skills and memory mix the two.

These names do not exist in CE (checked in 0.22.0); use the right-hand side.

| ManimGL or old | Community Edition |
| --- | --- |
| `ShowCreation` | `Create` |
| `TexMobject`, `TextMobject` | `MathTex`, `Tex` |
| `FadeInFromDown`, `FadeInFrom`, `FadeOutAndShift` | `FadeIn(m, shift=UP)`, `FadeOut(m, shift=...)` |
| `GraphScene`, `Axes.get_graph` | `Axes` in a `Scene`, `Axes.plot` |
| `CONFIG` dict, `InteractiveScene` | constructor arguments, `Scene` |

The project pins the version. Check it (`uv run python -c "import manim; print(manim.__version__)"`) before you rely on a name you are unsure of.

0.22 (October 2026) reworked output, so code and advice from before then get these wrong:

- `--format` picks the output: `png` (the last frame, as `-s`), `png-sequence` (every frame), `gif`, `mp4`, `webm`, `mov`, or `none`. `-g`, `-i`, `--write_to_movie`, `--custom_folders` and `save_last_frame` in a config file are gone; `-s` and `config.save_last_frame` still work.
- `-l` alone is `--live-preview`, an OpenGL window. Low quality is `-ql`.
- `manim cache clear` replaces `--flush_cache`.
- Read output paths rather than building them: `scene.renderer.file_writer.final_file_path` after `render()`, and each section's file from the `video` field of the sections JSON.
- Output settings are read when the `Scene` is constructed, so construct it inside the `tempconfig` block.
- ManimPango 0.7 fixed `Text` kerning; advice to set words in `Tex` or a monospace font for that reason is stale.

## Commands

- Run it through the project's environment: `uv run manim ...`, with `</dev/null`: given an unknown scene name in a file of several scenes, manim waits for a choice on stdin (with none, it exits 1).
- The default quality is 1080p60. Iterate with `-ql` (854x480, 15 fps) and use `-qh` only for a final the user asked for.
- `-s` writes the last frame as a PNG without rendering motion. `-s -n 0,K` writes the frame after animation K, counting each `play` and each `wait` from 0. `-n A,B` renders animations A to B only. `--dry_run` runs the scene and writes nothing, to catch errors.
- Output goes to `media/` in the current directory (`--media_dir` moves it). Do not commit it.
- If `Text` or `MathTex` fails, run `manim checkhealth`. `Text` needs Pango. `Tex` and `MathTex` need a LaTeX install and `dvisvgm`.

## Stills

For a diagram in a notebook or a figure, look for a helper the project already has (`render_still`, a `draw` module) and use it. Otherwise:

- Build the mobjects, add them in a `Scene.construct` that only calls `self.add`, and construct and render the scene inside `tempconfig` with `save_last_frame`, `background_color`, `frame_width` and `frame_height` (manim units), and `pixel_width` and `pixel_height` (units times pixels per unit). Read the PNG at `scene.renderer.file_writer.final_file_path`.
- Set `config.media_dir` to a fixed temp directory, not the working directory, so LaTeX compiles once and a notebook run leaves no files in the repository.
- `MathTex` and `Tex` compile LaTeX when the mobject is built, not at render. A LaTeX error surfaces there, and that is where time goes.

## Code

- One class per scene, named for what it shows. Keep colors, sizes, run times and camera poses as named constants in one place, and take colors from the project's palette, not from manim's `RED` and `BLUE`, unless asked.
- Lay out with `VGroup`, `arrange`, `next_to`, and `to_edge`. Use coordinates for anchors only.
- `Text` is for words (any font, no LaTeX). `MathTex` is for math. `MarkupText` needs `&amp;`, `&lt;`, and `&gt;` escapes. `Text(width=...)` scales the text to that width; it does not wrap it.
- `Transform(a, b)` changes `a` into a copy of `b`; `b` is not in the scene. Use `ReplacementTransform` when you keep using `b`.
- A scene that ends on `FadeOut` has a blank last frame, so `-s` shows nothing.
- In a `ThreeDScene`, add captions and other overlays with `add_fixed_in_frame_mobjects`, or they move with the camera.
- A scene that renders can still clip, overlap, flash or go blank. Render with `-ql` or `-s`, then open the image or frames of the video and look at them before you report the result.

## Videos

For several scenes, subtitles, narration, or a stitched `final.mp4`, read [references/video.md](references/video.md).
