# Source Video Analysis

Source: `C:\Users\LJR19\Videos\simple_prompter.mp4`, analyzed 2026-10-05.

## Media facts (ffprobe)
- H.264 806x506 @ 30 fps, AAC 48 kHz stereo, duration 73.8 s, 16.8 MB.

## Audio
- Transcribed with our own `speech_cli` (simple_speech v1.1.0, ggml-base.en, CPU):
  three segments, all `(keyboard clicking)`. **No narration.** All content is visual.

## What the video shows
A screen recording of an Instagram/Facebook reel (opening overlay: "Resume reel",
"See details moody.mjarosz.com"). A camera close-up of a MacBook notch: a black pill
extends down from the notch (green camera LED visible) and shows a scrolling script.

Frames: `video_frames/` (every 3 s; `contact_sheet.png` = all 25 tiles).

### Visual design (observed)
- Black rounded panel that merges with the bezel and drops down from the camera notch.
- Monospace font, center-aligned, ~25-30 characters per line, 3-4 lines visible.
- Top line is dimmed and clipped (already-read text fades up and out); the lines below it are bright.
- A soft blue/violet radial glow sits behind the lower text, changes shape across frames
  (looks audio-reactive, likely tied to voice level).
- Text moves upward smoothly, a pixel at a time rather than a line at a time (frames catch lines half-clipped at the top).
- Last frame (f_025): app pulls back to show the macOS menu bar, panel sitting under the notch.

### Script shown on the prompter (reconstructed across frames, 144 words)
> This is Moody. Moody is a notch teleprompter for Mac. It helps you speak clearly
> during video recordings, online meetings, presentations and live demos. The main
> idea is simple: your script stays right next to your camera, in the notch. So when
> you read your text, you still keep natural eye contact and Moody can follow your
> voice. So when you stop speaking, it pauses, and when you continue, it scrolls
> again. That makes it feel very natural. Moody is useful for creators, remote workers
> and presenters because you can follow your script, stay calm and deliver your
> message smoothly. You can control the scrolling speed, adjust the text size and
> place it exactly where you want. Moody is basically an invisible presentation
> assistant, always near your camera, helping you stay focused and speak with
> confidence. You can try Moody on Mac. That's it.

### Feature list claimed by the script
1. Script sits next to the camera, so you keep eye contact.
2. Follows your voice: pauses when you stop speaking, scrolls again when you continue.
3. Controllable scroll speed.
4. Adjustable text size.
5. Placement "exactly where you want".
6. "Invisible presentation assistant".

### Pacing measurement
- 144 words scrolled between ~3 s and ~71 s, about **127 wpm** (a typical speaking pace).
