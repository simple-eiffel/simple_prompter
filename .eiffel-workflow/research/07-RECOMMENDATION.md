# RECOMMENDATION: simple_prompter

## Executive Summary
Build simple_prompter in Eiffel: a capture-invisible pill pinned under the webcam that follows your
voice. A fast VAD loop drives start/stop; a GPU whisper + forward-only alignment loop tells it
which word you're on. The GPU risk is retired: whisper.cpp built with CUDA for the RTX 5070 Ti
decodes a 3 s window in 53-63 ms warm. The remaining unknowns are the live mic path and capture
exclusion; one short spike each.

## Recommendation
**Action:** BUILD
**Confidence:** HIGH for the product shape and ASR performance (measured); MEDIUM for live audio
and capture exclusion (unproven in our stack until the spikes run).

## Rationale
- Moody-class apps are volume-gated and drift. Word trackers exist but none is a Windows-native,
  camera-calibrated, capture-invisible overlay with local GPU ASR. That combination is open.
- About 70% of the parts exist in simple_* (speech, audio, shell, cairo, toml, SCOOP slot pattern,
  installers). The gaps are well-bounded and belong upstream, where they also help SW_DICTATION,
  simple_narrate and simple_speech's planned streaming phase.
- The hard, interesting core (aligner + follower) is pure Eiffel and contract-testable without
  audio or GPU. DBC is a real advantage here, not decoration.

## Proposed Approach

### Spikes first (each ends in a runnable proof plus pasted output)
1. **S-1 Live mic to 16 kHz:** simple_audio captures 10 s from the default mic, writes a WAV, and
   whisper (CUDA) transcribes it. Fix simple_audio format/packet/selectany issues in the library.
2. **S-2 Invisible pill:** simple_shell popup with WDA_EXCLUDEFROMCAPTURE, rounded and topmost,
   drawing Cairo text. Verify against OBS, Teams, Snipping Tool, Game Bar.
3. **S-3 Rolling decode in-process:** simple_speech `SPEECH_STREAM` on a SCOOP worker: VAD frames +
   3 s/250 ms windows, no_context, prior-text prompt, word timestamps. GUI tick stays under 16 ms.

### Phase 1 (MVP: "Moody on Windows")
- Pill under the camera, monospace centered text, fade, smooth time-based scroll.
- Voice-gated and Constant modes (Silero VAD).
- Speed / size / width / lines / position / opacity; TOML settings; .txt/.md load.
- Global hotkeys; hover-to-pause; capture-invisible.

### Phase 2 (the differentiator)
- Tracking mode: rolling CUDA whisper, `SCRIPT_ALIGNER`, `PROMPTER_FOLLOWER` spring/coast.
- Audio-reactive glow, countdown, time remaining.
- Camera calibration per monitor; per-monitor DPI.

### Later
- Editor window, DOCX import, Ollama helpers (port 11435), installer with optional GPU pack, phone remote.

## Key Features
1. **Hybrid follower:** VAD for motion, ASR for position (I-001).
2. **DBC-specified aligner:** forward-biased, jump-evidence, stop-word-immune (I-002, D-009).
3. **Capture-invisible pill:** opaque popup + display affinity (I-005, D-007).
4. **Camera calibration:** sits ~2 deg below *your* lens, not a guess (I-004).
5. **Fully local on the GPU:** large-v3-turbo on CUDA, base.en CPU fallback (D-002, D-013).

## Success Criteria
- Pause latency <= 250 ms; resume <= 150 ms (NFR-001, FR-021).
- Tracking error <= 1 line over a 5-minute read with skips and ad-libs (FR-023).
- GUI frame time p99 <= 16.7 ms while decoding (NFR-003).
- Not visible in OBS/Teams/Snipping Tool captures (FR-003).
- Keyboard clicking alone never scrolls (FR-026; the reel's own audio is a ready test clip).

## Dependencies
| Library | Purpose | simple_* Preferred |
|---------|---------|-------------------|
| simple_speech (extended: CUDA, VAD, stream, word timestamps) | ASR | YES |
| simple_audio (hardened) | WASAPI mic capture | YES |
| simple_shell (extended: affinity, panel, DPI, monitors, hotkeys) | Overlay window, timer | YES |
| simple_cairo / simple_widgets SW_PAINTER | Text, gradients, masks | YES |
| simple_toml, simple_file, simple_markdown | Settings, scripts | YES |
| simple_testing (TEST_SET_BASE) | Tests | YES |
| simple_ai_client (optional) | Ollama helpers | YES |
| whisper.cpp 1.8.2 + ggml-cuda (vendored DLLs) | Inference | n/a (C library, as today) |
| ISE base, time, testing | Core | allowed |

## Next Steps
1. Larry reviews this research (especially D-001, D-002, D-007, D-013).
2. Run `/eiffel.spec d:/prod/simple_prompter` to turn it into a class-level specification.
3. Then `/eiffel.intent`, `/eiffel.contracts`. Run spikes S-1..S-3 in parallel with spec work, since they
   validate upstream library changes rather than simple_prompter classes.

## Open Questions
1. Default mode when a GPU is present: Tracking (recommended) or Voice-gated?
2. Primary camera: laptop bezel, or an external webcam on a monitor? (Sets the calibration default.)
3. Public release (installer + GPU pack) or Larry-only tool first?
4. Should simple_narrate's read-along reuse the follower? That affects how general the library API is.
5. Hotkey defaults: any clashes with OBS/Teams shortcuts Larry uses?
