# APPROACH: simple_prompter implementation sketch

Date: 2026-10-05 (Phase 2). Inputs: src/ (84 classes), testing/ (78 tests), spec 01-10.

## 1. Architecture

```
                    ┌─────────────── app target (GUI processor) ───────────────┐
 hotkeys/mouse ──►  PT_INPUT_ROUTER ──► SIMPLE_PROMPTER (facade) ──► PT_TAKE_CONTROLLER ──► PT_JOURNAL (JSONL)
                    │                       │  tick 16 ms                │
                    │                       ▼                            ▼
                    │                  PT_SCROLL_MODEL ◄── PT_FOLLOWER* ◄── PT_ALIGNER ◄── heard words
                    │                       │ y_offset                   ▲
                    │                  PT_PILL_RENDERER                  │ voice frames
                    └───────────────────────────────────────────────────┼──────────────────────────
                         speech worker processor (separate):  PT_TAIL_SOURCE ─► PT_SPEECH_PIPELINE
                                                              (tee.f32)          (PT_VAD, PT_DECODER)
                                                                        └─► PT_SPEECH_SLOT (encoded records)
   ffmpeg child: dshow → raw.mkv + tee.f32          worker exe: PT_SESSION_ANALYZER → analysis/*.json
```

## 2. Data flow

**Practice (Q4):**
1. ffmpeg runs audio-only and writes `tee.f32`.
2. The worker reads the appended bytes and runs the pipeline, emitting frames and heard words into the slot.
3. On each GUI tick: drain the slot → `feed_voice` / `feed_heard` → `tick` → render. No journal.

**Recording:**
1. Same speech path, but ffmpeg also writes `raw.mkv`.
2. Every action gets an rt from `PT_RECORDING_CLOCK` (tee bytes / 64,000) and goes to the journal (one flushed line each).
3. On Wrap, ffmpeg stops (`q`); the worker exe runs analysis; the Edit Floor loads `analysis/*.json`.
4. The solver and snapper produce the cut list; the render plan builds the ffmpeg filter script; the writers produce SRT/VTT, chapters, EDL and review.srt.

## 3. Implementation order (Phase 4), dependency-driven
1. **Script:** PT_NORMALIZER, PT_SCRIPT_PARSER (on simple_text_structure + simple_markdown once U-0 lands; until then a local whitespace/sentence split behind the same contracts), PT_SCRIPT_HISTORY.apply_edit (LCS).
2. **Follow core:** PT_SPRING, PT_LAYOUT (greedy wrap, y_of), PT_SCROLL_MODEL.tick, PT_VOICE_GATED_FOLLOWER, PT_TRACKING_FOLLOWER.
3. **Matching:** PT_WORD_MATCHER (bounded Levenshtein, stem variants), PT_ALIGNER (window LCS, anchors, jump/backward evidence, rate).
4. **Speech:** PT_SPEECH_PIPELINE (frames, hangover, step decode), PT_SPEECH_CODEC.
5. **Take:** PT_RESTART_POLICY, controller event mapping, PT_JOURNAL persistence (simple_file append + flush: verify, Q6), PT_JOURNAL_CODEC (simple_json), replay.
6. **Assembly:** PT_ATTEMPT_BUILDER, PT_TAKE_SOLVER (DP), PT_SILENCE_SNAPPER, PT_FLAGGER, PT_ATTEMPT_ALIGNER, PT_SESSION_ANALYZER, PT_CUT_LIST.floor_spans.
7. **Output:** PT_CAPTION_BUILDER, PT_REVIEW_SRT_WRITER, PT_CHAPTER_WRITER, PT_EDL_WRITER, codecs, PT_RENDER_PLAN.
8. **Settings:** TOML load/save.
9. **App/runtime/speech/worker clusters,** after U-0 (simple_shell panel/monitors/hotkeys, simple_speech VAD/decode/CUDA).

## 4. Key design decisions (in force)
- Pure library; effects behind PT_CLOCK, PT_TEXT_MEASURE, PT_VAD, PT_DECODER, PT_TRANSCRIBER.
- Single choice: transitions table, capture arguments, bytes→rt, file names.
- Values cross processors as strings; the worker builds its own pipeline on its own processor.
- Journal = truth; SRT = view; raw never modified.

## 5. Dependencies
- **Now:** base, simple_mml (+ testing, simple_testing).
- **Phase 4 library:** simple_text_structure (new), simple_markdown (+to_plain_text), simple_json, simple_toml, simple_file, simple_encoding, simple_datetime.
- **App:** simple_shell (+deltas), simple_widgets, simple_cairo, simple_speech (+deltas, CUDA variant), simple_process, simple_ffmpeg (+listing).

## 6. Risk areas
- The index conventions between caret, aligner and follower (review H1).
- Caret changes reaching the scroll model (H2).
- Stale decodes after restarts (H3).
- Rewiring after live edits (H4).
- State-dependent clicker keys (H5).
- dshow audio latency (H6).
- Unverified: capture exclusion (S-2), live dshow + drift (T-0), simple_file append/flush (Q6), analysis time.
