# SCOPE: simple_prompter

Date: 2026-10-05. Source idea: `evidence/video-analysis.md` (Moody reel, moody.mjarosz.com).

## Problem Statement
In one sentence: when Larry records a video or speaks on a call, reading a script pulls his eyes
away from the webcam, and a fixed-speed prompter either runs ahead of him or falls behind.

What's wrong today: no prompter exists in the simple_* ecosystem. The Windows options are
Electron/Python/C# apps, paid closed apps, or browser tools. Most "voice-follow" prompters gate a
constant scroll on mic volume (Moody admits noise "might be interpreted as speech"), so they drift and
don't know where you are in the script.
Who experiences this: anyone presenting to a camera: creators, remote workers, presenters, and
Larry himself (Vault/_Hermeneutic videos, explainer videos, demos of simple_* tools).
Impact of not solving: eyes on the wrong spot on camera, lost place, re-takes.

## Target Users
| User Type | Needs | Pain Level |
|-----------|-------|------------|
| Larry (primary) | Read a script while recording explainer and demo videos; keep eye contact; no cloud | HIGH |
| Video creator | Prompter that keeps pace with natural speech, stays out of the recording | HIGH |
| Remote worker / presenter | Notes near the camera during Zoom/Teams; invisible to the audience | MED |
| Eiffel developers | A worked example of SCOOP + live audio + GPU ASR + overlay in simple_* | MED |

## Success Criteria
| Level | Criterion | Measure |
|-------|-----------|---------|
| MVP | Dark pill pinned under the webcam, always on top, centered monospace script, fade-out of read lines | Visual check against `evidence/video_frames` |
| MVP | Scrolls while speaking, stops within ~250 ms of silence, resumes on speech | Stopwatch test on recorded speech |
| MVP | Invisible to screen capture (OBS, Teams, Snipping Tool) | Capture screenshot shows desktop behind it |
| MVP | Speed, text size, position, opacity adjustable and remembered | Settings round-trip |
| Full | True word tracking: highlighted position follows the spoken word, survives pauses, skips and ad-libs | Position error <= 1 line on a 5-minute read with deliberate skips |
| Full | Runs fully local on the RTX 5070 Ti, CPU fallback | No network calls; works with GPU disabled |
| Full | Installer, hotkeys, script editor, import .txt/.md (.docx later) | Clean install on a fresh user |

## Scope Boundaries
### In Scope (MUST)
- Borderless, topmost, non-activating, no-taskbar overlay positioned at the camera.
- Exclude from screen capture (`SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)`).
- Live microphone capture (WASAPI shared mode), 16 kHz mono float pipeline.
- Voice activity detection gating the scroll (pause/resume).
- Smooth sub-pixel scrolling at display rate; current-line emphasis; fade of read text.
- Adjustable speed, font size, width, lines visible, position; persisted settings.
- Load script from .txt / .md; minimal built-in editor or "open in editor + reload".
- Global hotkeys (play/pause, faster/slower, back/forward, hide).

### In Scope (SHOULD)
- Word-tracking mode: GPU streaming ASR + forward-only fuzzy alignment to the script.
- Audio-reactive glow (voice level), countdown, elapsed/remaining time.
- Camera calibration step ("put the dot on your camera").
- Hover-to-pause, mouse-wheel manual scroll, click-through toggle.

### Out of Scope
- macOS/Linux: the ecosystem is Windows-first (simple_shell, WASAPI, inline C Win32).
- Cloud ASR / any network service: on-device is a core promise (privacy, latency).
- Video recording itself: OBS/Camera do that; we only prompt.
- Mirror/flip mode for beam-splitter hardware prompters: different user, cheap to add later.

### Deferred to Future
- DOCX / PDF import (simple_archive+simple_xml; simple_pdf exists): after MVP.
- LLM script tidy-up / "shorten this" via local Ollama: nice-to-have, not core.
- Remote control from phone (simple_web): later.
- Multi-language beyond English: whisper is multilingual, alignment is language-neutral but untested.

## Constraints
| Type | Constraint |
|------|------------|
| Technical | Eiffel, SCOOP (`concurrency=scoop`), void-safe, DBC, inline C for Win32 |
| Technical | simple_* libraries first; fix library bugs in the library, not the client |
| Technical | No Python in the product (Larry rule, see ocr_capture memory) |
| Technical | F_code via `ec.sh`; CUDA 13.0 toolkit present; GPU = RTX 5070 Ti (Blackwell, sm_120), 16 GB |
| Resource | Single developer + Claude; reuse simple_speech / simple_audio / simple_shell / simple_cairo |

## Assumptions to Validate
| ID | Assumption | Risk if False |
|----|------------|---------------|
| A-1 | whisper.cpp builds with CUDA for sm_120 with the installed CUDA 13.0 | Word tracking on CPU only, or switch engine |
| A-2 | A rolling 2-4 s whisper window decodes in well under 300 ms on the 5070 Ti | Tracking lags; need true streaming engine (sherpa-onnx) |
| A-3 | WDA_EXCLUDEFROMCAPTURE works on an opaque WS_POPUP topmost window | "Invisible" promise fails |
| A-4 | simple_audio's WASAPI can deliver 16 kHz mono (AUTOCONVERTPCM) | Must add resampler |
| A-5 | WM_TIMER at ~16 ms gives visibly smooth scrolling | Need DwmFlush/vsync-paced render |
| A-6 | Forward-only fuzzy alignment holds position with whisper's word errors | Tracking jumps; fall back to VAD mode |

## Research Questions
- How do existing prompters follow voice: volume, VAD, or word recognition? (02-LANDSCAPE)
- What ASR latency is achievable locally on this GPU? (spike, 04-DECISIONS)
- Which window techniques survive screen-capture exclusion? (02, 06)
- How close to the lens must text sit for eye contact? (02 §Eye contact)
