# Workflow

Read this for an animation of more than a few steps, or for feedback on a render. SKILL.md has the rules that always apply.

Contents: [Keyframes](#keyframes), [Data apart from drawing](#data-apart-from-drawing), [Stills](#stills), [Motion](#motion), [Review](#review), [Feedback](#feedback), [Timing and the final](#timing-and-the-final), [By hand](#by-hand).

The order matters because each pass costs more to render than the one before: a still takes seconds, a low-quality video minutes, a final much longer. Settle what a later pass cannot change before you start it.

## Keyframes

- Write what the viewer should know at the end that they did not know at the start, in one sentence.
- List the keyframes in order: the held states the viewer stops on. A keyframe is one idea, so its caption needs no "and"; give it no caption where the picture says it alone. For each, write its caption, what is on screen, the transition into it (what moves), and its notes (what is drawn, its source, and the detail too dense to show). A run of keyframes under one camera framing is a shot.
- Write this where the project keeps plans: the scene module's docstring, or `plan.md` beside a multi-scene video.
- Settle the order, the content and the framing of each keyframe with the user before writing code. A question costs less now than after a render.

## Data apart from drawing

- A function or script gathers the data, puts it in scene units, and writes it to a file (parquet, npz). The scene reads only that file. A render then costs only drawing, and a still of one keyframe does not fetch or join anything again.
- Keep the style in one place: colors, widths, font sizes, run times, and the camera pose of each keyframe, named for what it shows (`WHOLE_BRAIN`, `LOBULA`).
- In 3D, compute a pose from the bounds of what it should frame, as neuVid's `frameCamera(bound=...)` does, rather than tuning angles and zoom by eye. A pose then still fits when the data changes.

## Stills

- Render each keyframe and look at it: `uv run manim -ql -s -n 0,K -o key_K scene.py Scene </dev/null`, where K is the index of the last `play` or `wait` of its transition, counted from 0.
- Fix layout here: overlap, clipping, text too small to read, an object off frame, a camera that frames the wrong thing.
- Show the user the stills of a new animation before rendering its motion.

## Motion

- Keep one scene and give each keyframe's transition a section: `self.next_section("lobula-pins")`. `self.next_section("intro", skip_animations=True)` builds a finished keyframe's state without rendering it, so a render covers only the transitions being worked on.
- When a player steps through keyframes, a transition holds no still time at its end: the player holds the keyframe until the next key press.
- `--save_sections` also writes a clip per section; take each file's name from the `video` field of the sections JSON.
- Render at `-ql` until the motion is right.

### Stepping through keyframes

- manim-slides plays one transition per key press: subclass `Slide` (`ThreeDSlide` in 3D), call `self.next_slide()` at each keyframe (`loop=True` loops a transition until the key), render with `manim-slides render`, and show it with `manim-slides present` or `manim-slides convert --to html --one-file` (a reveal.js page).
- Going back in manim-slides' HTML page jumps to the start of the previous transition; its presenter's `V` plays the reversed clip once at a fixed rate. For back as a sped-up reverse that speeds up with repeated presses, with a timeline, notes and review comments, use the user's app cel (`~/projects/cel`) on a cel storyboard; the lab's `lab.connectome.animate.write_player` makes a stand-in HTML page from the same folder.
- A `Slide` fails under `-s`. Keep the scene in a mixin and render stills from a plain-scene twin whose `next_slide` does nothing.
- A cel storyboard is a folder whose `storyboard.json` (`"format": "cel/storyboard"`, version 1) lists shots and keyframes, each with a still and a transition (forward and reversed clip), paths relative to the folder. cel's `samples/storyboard/` is the reference and `cel check FOLDER` the checker. The storyboard `id` (`lab:<name>`) and each keyframe id (a slug of its title) must stay the same across re-renders, since comments hang on them; the still is the forward clip's last frame; write `storyboard.json` last, through a temporary file and a rename. The lab's `still_storyboard` and `cut_storyboard` write it, both through `link_storyboard`, which lists whatever stills and clips the folder holds.
- To put manim text over a full-frame clip, render the manim layer transparent (`-t --format mov`) and lay it on with ffmpeg (`[0][1]overlay=format=auto`). manim-videos draws its clip over all manim content.

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

- Keep the notes in a Markdown file in the project, not in code: each keyframe's notes follow a line `## <keyframe id>` (the lab's movies keep `<module>.notes.md` beside the module, read with `animate.read_notes`). The storyboard names it as `notes_file`, and the comments' file beside it as `comments_file`, both relative to the folder (they may climb out with `..`), so both are under git; cel shows the notes, writes edits back to their section and writes the comments file itself. The renderer copies the notes into `storyboard.json` too; after notes change, relink without a render (lobula_columns' `notes` mode). The user writes `@claude, …` lines in the notes as questions for agents: they are his uncommitted changes, so commit them alone before editing the file. cel opens on stills and plays the clips on `a`, so a stills-only storyboard can be reviewed; render clips when motion is what is being judged.
- When the user reviews in cel, read the comments with `cel comments FOLDER --json`: each has `anchor.keyframe` (the id), `anchor.point` (`[x, y]` from 0 to 1, from the top-left) or `anchor.quote` (a passage of the notes), with its replies and whether it is resolved. Answer in the thread with `cel reply FOLDER ID "…" --author claude` once the change is rendered, saying what changed; leave resolving to the user, who checks it. The open window shows replies at once and reloads on a re-render. Keep a keyframe's id (its `slug`) when you retitle or split it, so its threads stay with it.
- Map each note to the keyframe and the constant it touches, and say which before changing anything.
- Change it, render only the keyframes and transitions it touches (skip the others, or `-n A,B`), and look at the same frames as before.
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
