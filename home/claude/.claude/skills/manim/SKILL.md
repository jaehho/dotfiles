---
name: manim
description: Writes and renders Manim Community Edition scenes (the `manim` package, not 3Blue1Brown's `manimlib`): still diagrams for notebooks and figures, animations, and explainer videos. Use for any task that imports `manim`, defines a `Scene`, uses `MathTex` or `Tex`, or runs the `manim` command.
---

# Manim

## Which manim

Community Edition: `import manim as mn` or `from manim import *`, and the
`manim` command.
ManimGL is a different package (`manimlib`, `manimgl`); tutorials and
memory mix the two.

These names do not exist in 0.21; use the right-hand side.

| ManimGL or old | Community Edition |
|---|---|
| `ShowCreation` | `Create` |
| `TexMobject`, `TextMobject` | `MathTex`, `Tex` |
| `FadeInFromDown`, `FadeInFrom`, `FadeOutAndShift` | `FadeIn(m, shift=UP)`, `FadeOut(m, shift=...)` |
| `GraphScene`, `Axes.get_graph` | `Axes` in a `Scene`, `Axes.plot` |
| `CONFIG` dict, `InteractiveScene` | constructor arguments, `Scene` |

The version is pinned by the project.
Check it (`uv run python -c "import manim; print(manim.__version__)"`)
before you rely on a name you are unsure of.

## Commands

- Run it through the project's environment: `uv run manim ...`.
- The default quality is 1080p60. Iterate with `-ql` (854x480, 15 fps)
  and use `-qh` only for a final the user asked for.
- `-s` writes the last frame as a PNG without rendering the animation.
  `-r W,H` sets the size.
- Output goes to `media/` in the current directory
  (`--media_dir` moves it). Do not commit it.
- If `Text` or `MathTex` fails, run `manim checkhealth`.
  `Text` needs Pango. `Tex` and `MathTex` need a LaTeX install and
  `dvisvgm`.

## Stills

For a diagram in a notebook or a figure, look for a helper the project
already has (`render_still`, a `draw` module) and use it.
Otherwise:

- Build the mobjects, add them in a `Scene.construct` that only calls
  `self.add`, and render under `tempconfig` with `save_last_frame`,
  `background_color`, `frame_width` and `frame_height` (manim units),
  and `pixel_width` and `pixel_height` (units times pixels per unit).
  Read the PNG that manim writes under `media_dir/images`.
- Set `config.media_dir` to a fixed temp directory, not the working
  directory, so LaTeX compiles once and a notebook run leaves no files
  in the repository.
- `MathTex` and `Tex` compile LaTeX when the mobject is built, not at
  render. A LaTeX error surfaces there, and that is where time goes.

## Code

- One class per scene, named for what it shows. Keep colors and sizes
  in one place and take colors from the project's palette, not from
  manim's `RED` and `BLUE`, unless asked.
- Lay out with `VGroup`, `arrange`, `next_to`, and `to_edge`. Use
  coordinates for anchors only.
- `Text` is for words (any font, no LaTeX). `MathTex` is for math.
  `MarkupText` needs `&amp;`, `&lt;`, and `&gt;` escapes.
- `Transform(a, b)` changes `a` into a copy of `b`; `b` is not in the
  scene. Use `ReplacementTransform` when you keep using `b`.
- A scene that renders can still clip or overlap. Render with `-ql` or
  `-s`, then open the image or a frame of the video and look at it
  before you report the result.

## Videos

For several scenes, subtitles, or a stitched `final.mp4`, read
[references/video.md](references/video.md).
