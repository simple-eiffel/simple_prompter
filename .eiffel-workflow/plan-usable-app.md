# Plan: from verified library to a prompter Larry can use

Status: ACTIVE, started 2026-10-06 (Larry: "formalize those steps in a plan and let's do the plan").
Builds on approved decisions: spec 04 sections 1.4-1.7 (speech, runtime, app, worker clusters), spec 07
delivery phases P1, P2, T1-T4, the keymap defaults in spec 07 section 2.14, intent-v2 (ffmpeg captures the
mic in all modes, voice-gated until tracking is proven, sessions in Videos\simple_prompter, ffplay preview,
installer after T2), and the CQS-approved `PT_VAD` interface (`analyze`, `last_probability`, `reset`).

Every step ends at a **use gate**: Larry runs the app and uses it. A step is not done until he has.

## How each step runs

1. **Upstream first.** Missing capability goes into the simple_* library that owns it, with that library's
   own tests, CHANGELOG and version bump (rule: fix library gaps in the library). Clients then rebuild
   with `-clean` (incremental builds keep old library code).
2. **Spike** anything unproven before building on it; paste measured output into `evidence/`.
3. **Spec delta, contracts, implement, verify** for the simple_prompter classes of the step (the same
   Spec Kit discipline, scoped to the step; frozen library contracts stay frozen).
4. **Gates:** `ec.sh test` 0 errors / 0 warnings, all tests green in the contract-checked and lean builds,
   then the use gate.
5. **Commit** per step; push to GitHub when the step passes its use gate.

New ECF targets: `simple_prompter_app` (GUI exe: app/, runtime/, speech/ clusters) and, in Step 4,
`simple_prompter_worker` (analysis exe). The library target stays pure and its 183 tests keep passing.

## Inventory this plan starts from (survey 2026-10-06)

| Need | State | Where it gets done |
|---|---|---|
| Topmost, non-activating, capture-excluded, click-through-toggle panel | `SHELL_STRIP` is topmost and non-activating, but single-instance, body-dragged, not click-through; no capture exclusion | simple_shell (Step 1) |
| Global hotkeys (modifier required; bare keys only while recording) | missing | simple_shell (Step 1) |
| Monitor list (lens position is per monitor) | missing; DPI is system-aware only | simple_shell (Step 1) |
| Text measure and painting | `SW_PAINTER.advance`, fonts, cairo | simple_widgets (exists) |
| Fast timer, event pump, QPC clock | event 25, `SHELL_DESKTOP.now_ms` | simple_shell (exists) |
| SCOOP worker and non-blocking slot | `TM_FRAME_SLOT` / `TM_SAMPLING_WORKER` pattern | copy the pattern (Step 2) |
| Live mic to 16 kHz samples | ffmpeg on PATH; tee-file design built (`PT_CAPTURE_PLAN`, `PT_RECORDING_CLOCK`) | spike + `PT_TAIL_SOURCE` (Step 2) |
| Stop ffmpeg | no stdin writes in simple_process; kill only (MKV + PCM survives a kill, per the record spike) | accept kill for now |
| Voice activity (Silero) | no binding; `ggml-silero-v6.2.0.bin` present; whisper.cpp 1.8.2 has a VAD API | simple_speech (Step 2) |
| Whisper on the GPU with prompt, no_context, word timestamps | simple_speech wraps the CPU build, segment times only; CUDA build exists in whisper_cpp_build\build_cuda, unused | simple_speech (Step 3) |
| Camera/mic device names | no dshow listing in simple_ffmpeg | parse `ffmpeg -list_devices` (Step 4) |

## Step 1: The pill (constant speed, no audio)

**You get:** your script in a pill under the webcam, scrolling at a set speed, with every control live.
Invisible in screen shares and recordings.

1a. **simple_shell upstream**
   - `SHELL_PANEL`: borderless, topmost, non-activating, no taskbar button, any number of instances,
     capture exclusion (`SetWindowDisplayAffinity` with `WDA_EXCLUDEFROMCAPTURE`, falling back to
     `WDA_MONITOR` on older Windows and reporting which it got), click-through on/off, mouse events,
     painting through cairo.
   - `SHELL_HOTKEYS`: `RegisterHotKey` on the shell thread, `WM_HOTKEY` into the existing event queue;
     a modifier is required unless a binding is explicitly bare (and bare bindings are registered only
     while recording, the safety interlock `PT_KEYMAP` already enforces).
   - `SHELL_MONITORS`: monitor list (device name, bounds, work area) for the lens anchor.
   - Risks: ISE generated C targets Windows 2000 (`_WIN32_WINNT 0x0500`), so the newer affinity API
     needs the `0x0A00` cflag (known gotcha); new mutable C state must be `SHELL_SHARED` (selectany).
1b. **Spike S-2:** a demo panel with text; capture the screen with ffmpeg gdigrab and check the panel's
   pixels are absent; Larry confirms in OBS / Teams / Snipping Tool.
1c. **simple_prompter_app:** `PT_APP` (root, two-phase construction, 16 ms tick), `PT_PILL` (on
   `SHELL_PANEL`), `PT_PILL_RENDERER` (line strip, fade, caret, reading line), `PT_CAIRO_MEASURE`
   (`PT_TEXT_MEASURE` on `SW_PAINTER.advance`), `PT_INPUT_ROUTER` (hotkeys, mouse, clicker to
   `PT_CONTROL` / `PT_ACTION`), `PT_QPC_CLOCK`. Script from the command line (default: the read test).
   Settings from `settings.toml` (font, width, lines, opacity, speed); adjust keys for speed and size.
1d. **Use gate:** you read a script at constant speed: hold/go, Again, back/forward, pick a word, hide,
   click-through; the pill sits under the lens; it does not appear in your recording or meeting app.

## Step 2: Voice-gated following (live microphone)

**You get:** the text moves while you talk and stops when you stop.

2a. **Spike S-1 / T-0:** ffmpeg dshow audio-only into `tee.f32` (`PT_CAPTURE_PLAN.make_audio_only`);
   tail it; measure mic-to-sample latency and drift over 30 minutes.
2b. **simple_speech upstream: `SPEECH_VAD`** on whisper.cpp's Silero VAD (ggml model), frame by frame
   with carried state and reset. Spike first: does the 1.8.2 VAD API stream frame by frame? If not, an
   energy-based detector behind the same `PT_VAD` interface is the stand-in until it does.
2c. **Spike S-3 + speech worker:** `PT_SPEECH_WORKER` on its own SCOOP processor (tail source, VAD,
   `PT_SPEECH_PIPELINE`), `PT_SPEECH_SLOT` (non-blocking, the taskman pattern), records encoded with
   `PT_SPEECH_CODEC`; the GUI drains the slot every tick. `PT_TAIL_SOURCE`, `PT_SILERO_VAD`.
2d. **App:** voice-gated mode live; the glow follows your level; practice runs start ffmpeg audio-only.
2e. **Use gate:** a 5-minute read: it moves within about 150 ms of speech and stops within half a
   second of silence; the GUI stays at 60 frames a second.

## Step 3: Real tracking (whisper on the GPU)

**You get:** it follows the word you are reading, through skips, ad-libs and stumbles.

3a. **simple_speech upstream:** decode parameters (`no_context`, initial prompt, greedy), per-word
   timestamps, decoding a sample buffer (not just a file), and a CUDA variant linked against the
   existing build_cuda (sm_120). Re-measure the spike's 53-63 ms per 3 s window.
3b. **`PT_WHISPER_DECODER`** in the worker: 3 s window every 250 ms while speaking; the GUI sends the
   already-read prompt text (never upcoming text).
3c. **App:** tracking mode; a confidence cue on the pill; `PT_CALIBRATION_OVERLAY` to mark the lens.
3d. **Use gate:** a 5-minute live read stays within one line; then `mark_tracking_proven`, and tracking
   becomes the default when a GPU is present.

## Step 4: Take Studio (record, auto-edit, review, render)

**You get:** record with the camera, flub and retake without stopping, wrap, and get a cut video with
captions, plus a short list of things to check.

4a. **Recording:** `PT_RECORDER` (camera + mic per `PT_CAPTURE_PLAN`, kill-safe MKV), REC dot, session
   folder under Videos\simple_prompter, journal on disk, live marks (Again, Star, Reject, Marker),
   `PT_INLINE_EDITOR` for live script edits; device names from `ffmpeg -list_devices`.
4b. **Analysis:** `simple_prompter_worker --analyze <session>` (`PT_WORKER_APP`,
   `PT_WHISPER_TRANSCRIBER` full-file on the GPU), `PT_WORKER_LAUNCHER` polls its result.
4c. **Minimal Edit Floor (approved default):** cuts and flags, preview a cut or a joint with ffplay,
   star a different take, Render (`PT_RENDERER`) to final.mp4 with SRT/VTT captions and chapters.
4d. **Use gate:** the cough test plays right in VLC with review.srt; then you edit a real episode.

## Step 5: Installer (approved: after T2)

An Inno Setup installer for the app and worker with the whisper DLLs and models, once Step 4 has
produced a real episode.

## Open decisions (Larry)

- Keep headings that were read aloud in the final cut? (Phase 5 carry-over; affects Step 4.)
- Publish the Moody reel frames? (kept local for now)

## Progress

| Step | Part | State |
|---|---|---|
| 1 | 1a simple_shell 1.11.0: SHELL_PANEL, SHELL_HOTKEYS, SHELL_MONITORS, display scale | done on branch feature/panel-hotkeys-monitors (28/28, SCOOP 4/4); merge + push at the use gate |
| 1 | 1b S-2 capture exclusion | automated part done: affinity 0x11; screen grab and PrintWindow both see nothing; Larry to confirm in OBS / Teams / Snipping Tool |
| 1 | 1c simple_prompter_app (PT_APP, PT_PILL, PT_PILL_RENDERER, PT_CAIRO_MEASURE, PT_INPUT_ROUTER, PT_QPC_CLOCK; library: PT_PILL_GEOMETRY, pill position in settings, Hold offers the passage start) | done: app builds 0/0; library 190/190; scripted run by posted hotkeys: play, count-in, scroll, hold, forward, go all work |
| 1 | 1d use gate | waiting for Larry: `run_prompter.cmd` |
| 2-5 | | pending |

Notes from 1c:
- The pill is DPI-scaled (settings stay in design pixels; 150% display = 1.5x).
- `--capturable` lets screenshots see the pill (for docs/demos); default is hidden.
- simple_widgets fix/locale-unused-local: one unused local removed (every client build warned).
