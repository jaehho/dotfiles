# Workflow

Read this for an animation of more than a few steps, or for feedback on a render. SKILL.md has the rules that always apply.

Contents: [Beats](#beats), [Data apart from drawing](#data-apart-from-drawing), [Stills](#stills), [Motion](#motion), [Review](#review), [Feedback](#feedback), [Timing and the final](#timing-and-the-final), [By hand](#by-hand).

The order matters because each pass costs more to render than the one before: a still takes seconds, a low-quality video minutes, a final much longer. Settle what a later pass cannot change before you start it.

## Beats

- Write what the viewer should know at the end that they did not know at the start, in one sentence.
- List the beats in order. A beat is one idea, so its caption needs no "and". For each, write its caption, what is on screen at its end, and what moves during it.
- Write this where the project keeps plans: the scene module's docstring, or `plan.md` beside a multi-scene video.
- Settle the order, the content and the framing of each beat with the user before writing code. A question costs less now than after a render.

## Data apart from drawing

- A function or script gathers the data, puts it in scene units, and writes it to a file (parquet, npz). The scene reads only that file. A render then costs only drawing, and a still of one beat does not fetch or join anything again.
- Keep the style in one place: colors, widths, font sizes, run times, and the camera pose of each beat, named for what it shows (`WHOLE_BRAIN`, `LOBULA`).
- In 3D, compute a pose from the bounds of what it should frame, as neuVid's `frameCamera(bound=...)` does, rather than tuning angles and zoom by eye. A pose then still fits when the data changes.

## Stills

- Render the end frame of each beat and look at it: `uv run manim -ql -s -n 0,K -o beat_K scene.py Scene </dev/null`, where K is the index of the beat's last `play` or `wait`, counted from 0.
- Fix layout here: overlap, clipping, text too small to read, an object off frame, a camera that frames the wrong thing.
- Show the user the stills of a new animation before rendering its motion.

## Motion

- Keep one scene and give each beat a section: `self.next_section("lobula-pins")`. `self.next_section("intro", skip_animations=True)` builds a finished beat's state without rendering it, so a render covers only the beats being worked on.
- `--save_sections` also writes a clip per section; take each file's name from the `video` field of the sections JSON.
- Render at `-ql` until the motion is right.

## Review

A video that renders can still clip, flash, freeze or go blank. Look at it before reporting, with these (run from the folder that holds the video):

- A contact sheet of the whole video, one frame a second, twelve to a sheet:

  ```bash
  ffmpeg -v error -y -i video.mp4 -vf "fps=1,scale=480:-1,tile=4x3" sheet_%02d.png
  ```

- The width people will watch it at: if it will sit in a notebook cell or a slide, make a sheet at that width as well (`scale=360:-1`). Text that reads at 1080p can be illegible there, and rendering at a higher resolution does not change that.
- Mid-transition: a fade, a transform or a camera move can look wrong only halfway (a flash, a jump, a pop). Take frames on both sides and in the middle of each one: `ffmpeg -v error -y -ss 12.4 -i video.mp4 -frames:v 1 at_12.4.png`.
- Dead air: `ffmpeg -hide_banner -nostats -i video.mp4 -vf freezedetect=n=0.0005:d=3 -map 0:v -f null - 2>&1 | grep freeze` lists stretches of at least 3 s where nothing moves. Each should be a hold the viewer needs (to read a caption, to see a result), not a gap.
- The final, too: 480p blurs away gaps of a pixel or two that a 1080p render shows.

## Feedback

- Map each note to the beat and the constant it touches, and say which before changing anything.
- Change it, render only the beats it touches (skip the others, or `-n A,B`), and look at the same frames as before.
- Show the user the new frames next to the old ones.

## Timing and the final

- Time last: `run_time`, `rate_func` (`smooth` is the default; use `linear` where the motion is itself time), `lag_ratio`, and the holds.
- Hold each caption long enough to read: about 1 s plus 0.4 s a word.
- In 3D, a slow camera drift (`begin_ambient_camera_rotation`) keeps the depth readable through a long hold.
- Render the final at the quality the user asked for, and review it as above.

## By hand

The same order works without an agent; what changes is that a person looks at a live window instead of PNGs.

- A live window: in CE, `--renderer=opengl -l` with `self.interactive_embed()` at the point to inspect (an IPython shell next to a window that rotates with the mouse); in ManimGL, `manimgl file.py Scene -se <line>` drops into a shell at that line, and `checkpoint_paste()` reruns the clipboard from a saved state. Copy a camera pose found with the mouse into the constants.
- Rerun on save: the VS Code extension Manim Sideview (`runOnSave`); Jupyter's `%%manim` magic in a notebook.
- Timing: lay the `-ql` section clips against the narration in a video editor (Kdenlive), change only run times, then render the final.
- These need a window on the user's screen, so they are for the user, not an agent.
