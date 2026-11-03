---
name: slidecut
description: Understand a video (YouTube URL or local file) by picking one frame per distinct slide or scene and lining the transcript up against them, with the slidecut tool. Use when the user gives a video link or file and wants it summarised, quoted, or asked about, especially talks, lectures, explainers and screen recordings where what is on screen matters. Not for audio-only podcasts or music.
---

# Read a video with slidecut

`~/projects/slidecut/slidecut.py` is a uv script (`uv` installs its dependencies on first run, about 600 MB of CLIP weights). It cuts one frame per distinct picture and splits the transcript by the frame on screen, so you read the video as text plus a few images instead of sampling frames blind.

## Run it

```sh
~/projects/slidecut/slidecut.py "URL_OR_FILE" --out DIR --whisper small.en --ocr
```

- `DIR`: the scratchpad directory unless the user names one. A URL is downloaded into `DIR/source/` (720p at most); a video's own English captions replace the Whisper run.
- It takes about a minute per hour of video for the picking, plus Whisper, plus about 2 seconds per frame for `--ocr`: a 21-minute video took about 6 minutes in all. Start it with `run_in_background`, send its stderr to a log file next to `DIR` (it prints pages of model-loading warnings), end your turn, and wait for the completion notice; do not read `DIR` before it finishes and do not poll with `sleep`.
- `--ocr` is on by default here because it cut the frames agents opened by about a third. Leave it off only when the video has no on-screen text.
- Add `--cues` when the answer likely sits on screen but is only pointed at in speech (a promo code or URL read out, "as you can see here"). It asks a small model through `claude -p`, costs a few cents, and adds about 20% more frames on a slide talk.
- A slide talk with a speaker cutting in: add `--coverage 0` to keep room shots out.

## Read the result

All frame paths in `aligned.md` and `ocr.txt` are relative to `DIR`.

1. Read the notes at the top of `DIR/aligned.md` (`head -8`): no transcript, a looping transcript, or "Frame limit reached" (the video cuts faster than the frame budget, so some seconds have no close frame). The file can run to 800 lines of long paragraphs, so get the span map with `grep '^###' DIR/aligned.md` and read only the spans you need.
2. Each `###` heading is a time span and the frame on screen. A frame file name carries its time: `006_06-40.jpg` is the sixth frame, at 6:40. "seen again" means the slide returned. "speaker on camera" has no frame, so the transcript is all there is for that stretch; use `--at` if the question is about what was shown.
3. Open frames with Read only when the question needs the picture. A question about a number, name, chart or label on screen needs the frame.
4. To find what the video says and shows about X: `grep -i X DIR/ocr.txt` for text on screen (each line starts with the frame file) and `grep -i X DIR/aligned.md` for the speech, open the frames of those spans, then cut `--at` a few seconds after each spoken mention. Search the OCR first for a label or name: the lecturer in one test never said "Kenotron", which was printed on the slide. The picture often lags the speech: in a test the product slide came 8 seconds after the first mention. For a drawing or blackboard being built up, open the later frames too, since the first is partial.
5. OCR misreads small and stylised text (it turned `d_l l` into `d_c l` once). Open the frame before you quote a number, name or formula from OCR.
6. A short span, or a note "The picture at M:SS differs N% from frames/X", means that frame may not show what is said there; fast-cut videos have dozens of these, mostly cross-fades, so act only on moments the question is about. To cut a better frame, give the same URL and the same `--out` (it reuses `DIR/source/`, no new download), or `DIR/source/video.mkv`, plus `--at M:SS` (also `M:SS-M:SS`, one frame every 2 seconds, at most 12 frames per call). Frames land in `DIR/extra/`.

## Answer

Ground each claim in a frame or a transcript time, and cite it. Say what you could not read: a cartoon or caption can cover part of a chart. If neither the frames nor the transcript show it, say so rather than guess; the frames are chosen automatically and can miss a slide shown for under about 2 seconds.

## Limits

- Interviews and talking heads yield few frames (a 16-minute studio interview gave 4). That is correct, not a failure.
- A photo of a face inside a graphic can be read as speaker footage, so it may get no frame; use `--at`.
- Layouts with a webcam in the corner of a screen recording are untested.
- Automatic YouTube captions are not used; without manual captions it runs Whisper, which measured closer to human captions than the automatic ones.
