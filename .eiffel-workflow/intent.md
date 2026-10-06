# Intent: simple_prompter

Date: 2026-10-05. Pre-populated from spec/01-08, spec/F-01-TAKE-STUDIO.md (decided), research/01-07.
F-02 voice commands are DEFERRED.

## What
A Windows teleprompter written in Eiffel on the simple_* ecosystem:
- **The pill:** a dark, borderless, always-on-top, non-activating panel pinned under the webcam, invisible to
  screen capture. It shows the script in a centered monospace column and fades read lines.
- **Voice following:** three modes, Constant, Voice-gated (Silero VAD) and Tracking (CUDA whisper +
  a forward-only, contract-specified script aligner).
- **Take Studio:**
  - continuous ffmpeg webcam recording, with every action stamped in recording time;
  - one-press retakes from the current sentence or any chosen word;
  - live script revisions;
  - a GPU analysis pass that snaps cuts into silence;
  - a take solver;
  - a minimal **Edit Floor** that renders the final video plus captions, chapters and an EDL, while the
    bad takes "hit the floor".

## Why
- Larry records explainer and demo videos and speaks on calls. Reading a script pulls his eyes off the
  lens, and fixed-speed prompters run ahead or fall behind.
- Flubs force re-takes and manual editing.
- No Windows-native, camera-calibrated, capture-invisible prompter with local GPU word tracking exists, and none
  with retake-aware recording and automatic assembly.
- The work also lifts the ecosystem (speech streaming, capture-excluded windows, monitors and DPI, multi-hotkeys,
  a shared text-structure library).

## Users
- **Larry (primary):** reads scripts while recording with the FHD Camera; uses hotkeys, the mouse on the pill, and
  optionally a clicker or pedal.
- **Presenters on calls:** pill visible only to them.
- **Eiffel developers:** a worked example of SCOOP + live audio + GPU ASR + overlay + DBC assembly logic.

## Acceptance Criteria
- [ ] Pill opens top-center (or at the calibrated camera point), stays on top, never takes focus, has no taskbar entry
- [ ] Pill is absent from OBS display capture, Teams share and Snipping Tool (or shows a visible "not excluded" warning)
- [ ] Voice-gated: scrolling stops ≤ 250 ms after speech ends and resumes ≤ 150 ms after it starts; keyboard clicking alone never scrolls
- [ ] Tracking: position error ≤ 1 line over a 5-minute read with skips and ad-libs
- [ ] GUI frame time p99 ≤ 16.7 ms while ASR runs; no stall > 50 ms
- [ ] Again: one press holds within 50 ms, places the caret at the sentence start, counts in; recording never stops
- [ ] Hold → browse → click any word → Go restarts from that word
- [ ] Inline edit creates a new revision; untouched word ids preserved; final captions use the edited words
- [ ] Raw recording (MKV) survives killing the app mid-take; journal replays after a crash
- [ ] Every mark in review.srt lines up with the audible event within 100 ms
- [ ] Solver: every spoken word of the final revision appears exactly once, in order; no rejected or stale takes; starred takes win
- [ ] Cuts lie in silences or are flagged tight; no clipped words in a 10-joint listening test
- [ ] One-pass NVENC render with frame-accurate joints and click-free audio
- [ ] Captions drift ≤ 150 ms from speech
- [ ] Raw recording and journal are never modified; outputs reproducible from raw + journal + cut.json
- [ ] Zero network calls

## Out of Scope
- Voice commands (F-02 deferred); macOS/Linux; cloud services; screen recording; multi-camera; titles/B-roll/music
  (EDL to Resolve instead).
- Mirror mode; phone remote; DOCX/PDF import; LLM helpers; embedded video player (ffplay in v1).
- OBS backend; pickups across files; blooper reel (COULD, later).

## Dependencies (simple_* First Policy)

| Need | Library | Justification |
|------|---------|---------------|
| Kernel collections | ISE base | No simple_* equivalent |
| Tests | ISE testing + simple_testing | House testing standard (TEST_SET_BASE) |
| Models | simple_mml | Frame/collection postconditions |
| Tokenizing, sentence/paragraph/section, navigation | **simple_text_structure (NEW)** | Extracted from simple_speed_reader's tested tokenizer |
| Markdown → plain text | simple_markdown (+ to_plain_text) | Scripts are .md |
| Journal, cut.json, analysis | simple_json | JSONL / JSON |
| Settings | simple_toml | Nested tables, hand-editable |
| Files, UTF-8 | simple_file, simple_encoding | |
| Wall-clock timestamps (journal session_start) | simple_datetime | Instead of ISE time |
| Panel, monitors/DPI, hotkeys, fast timer, QPC clock | simple_shell (+ U-0 deltas) | |
| Views, painting, text measure | simple_widgets, simple_cairo | |
| VAD, rolling decode, word timestamps, CUDA | simple_speech (+ U-0 deltas) | whisper.cpp 1.8.2 CUDA build verified |
| Practice-mode mic capture | simple_audio (+ U-0 fixes), see intent-v2 Q4 | |
| ffmpeg / ffplay / worker children | simple_process | |
| dshow device listing | simple_ffmpeg (+ U-0 delta) | |

## MML Decision
**Decision:** YES-Required (library core)
**Rationale:**
- Script history, journal, cut list, word timeline, speech map, layout and keymap have collection laws (append-only,
  exact cover, id preservation, frame conditions) that only model postconditions can state.
- Invariants stay O(1) (oracle rule).
- App/runtime classes: optional.
