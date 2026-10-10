# Videos

Read this for a multi-scene animation. SKILL.md has the rules that
always apply.

## Layout

One folder per video, in the working directory (not the skill's):

```
<name>/
├── plan.md        # the plan
├── script.py      # one class per scene
├── concat.txt     # scene list for ffmpeg
├── final.mp4
└── media/         # written by manim
```

Run every command from that folder.

## Plan first

If the user gave a plan, or used plan mode, write it to `plan.md` and
go on.
Otherwise write a short plan before any code:

- The topic, the audience and what they already know, and the one
  insight the video is for.
- The scenes, in order. For each: its purpose, its length, the
  mobjects and animations, and any voiceover text with the animation
  it syncs to.
- The shared elements (objects that return across scenes) and the
  palette.

## Scenes and subtitles

- Name scenes in order: `Scene1_Intro`, `Scene2_DerivePDE`.
- Add a subtitle with `self.add_subcaption("text", duration=2)`, or
  pass `subcaption="text", subcaption_duration=2` to `self.play`.
  Manim writes a `.srt` next to each scene's video.

## Render

```bash
uv run manim -ql --progress_bar none script.py Scene1_Intro Scene2_Main
```

If a scene fails, read the error, fix it, and render only that scene.
Videos land in `media/videos/script/480p15/<Scene>.mp4`
(`1080p60` for `-qh`, `720p30` for `-qm`).

## Stitch

```bash
cat > concat.txt <<'EOF'
file 'media/videos/script/480p15/Scene1_Intro.mp4'
file 'media/videos/script/480p15/Scene2_Main.mp4'
EOF
ffmpeg -y -f concat -safe 0 -i concat.txt -c copy final.mp4
```

`-c copy` needs every scene rendered at the same quality.
Render the whole set again at `-qh` when the user asks for the final.

## Feedback

Find the scenes the feedback touches, change them, render only those,
and stitch again.
