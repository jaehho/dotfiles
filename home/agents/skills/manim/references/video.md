# Videos

Read this for a multi-scene animation. SKILL.md has the rules that always apply.

## Layout

One folder per video, in the working directory (not the skill's):

```text
<name>/
├── plan.md        # the plan
├── script.py      # one class per scene
├── concat.txt     # scene list for ffmpeg
├── final.mp4
└── media/         # written by manim
```

Run every command from that folder.

## Plan first

If the user gave a plan, or used plan mode, write it to `plan.md` and go on. Otherwise write the beats (the Beats step of `workflow.md`) in `plan.md`, adding:

- The audience and what they already know.
- The scenes, each a run of beats, with its length and any narration with the animation it syncs to.
- The shared elements (objects that return across scenes) and the palette.

## Scenes and subtitles

- Name scenes in order: `Scene1_Intro`, `Scene2_DerivePDE`.
- Add a subtitle with `self.add_subcaption("text", duration=2)`, or pass `subcaption="text", subcaption_duration=2` to `self.play`. Manim writes a `.srt` next to each scene's video.

## Narration

- Write the narration before the animation, one line per beat, and time the beats to it: make or record the audio first, then give each `play` an explicit `run_time` and each subtitle its line's `duration`.
- manim-voiceover syncs animations to marks in the narration (`<bookmark mark='A'/>`, `wait_until_bookmark`); it is untested with 0.22.
- Or render silent section clips and lay them against the audio in a video editor.

## Render

```bash
uv run manim -ql --progress_bar none script.py Scene1_Intro Scene2_Main
```

If a scene fails, read the error, fix it, and render only that scene. Videos land in `media/videos/script/480p15/<Scene>.mp4` (`1080p60` for `-qh`, `720p30` for `-qm`).

## Stitch

```bash
cat > concat.txt <<'EOF'
file 'media/videos/script/480p15/Scene1_Intro.mp4'
file 'media/videos/script/480p15/Scene2_Main.mp4'
EOF
ffmpeg -y -f concat -safe 0 -i concat.txt -c copy final.mp4
```

`-c copy` needs every scene rendered at the same quality. `-o` is refused when rendering several scenes at once. Render the whole set again at `-qh` when the user asks for the final.

## Feedback

Find the scenes the feedback touches, change them, render only those, and stitch again.
