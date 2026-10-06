# INNOVATIONS: simple_prompter

## What Makes This Different

### I-001: "VAD for motion, ASR for position" (hybrid follower)
**Problem Solved:** volume-gated prompters (Moody class) react instantly but drift and don't know
where you are. Pure ASR trackers know where you are but update in jumps every 0.5-3 s.
**Approach:** two signals at two speeds feed one controller.
- Fast loop (~30 ms frames): Silero VAD says *speaking / not speaking*, so the scroll starts and stops at once.
- Slow loop (~250-500 ms): GPU ASR over a rolling window, then forward-only alignment gives
  *the word index you are on* plus your *speaking rate*.
- The controller scrolls at the measured rate while VAD = speech and steers position toward the
  aligned word with a critically-damped spring, so there are no visible jumps.
- When ASR has no match but VAD = speech (ad-lib), it coasts briefly, then holds.

**Novelty:** existing apps pick one mechanism. followspot coasts, but has no fast VAD gating of motion.
**Design Impact:** `PROMPTER_FOLLOWER` is a pure-Eiffel state machine with two inputs
(`on_voice_activity`, `on_alignment`) and one output (`target_offset`, `velocity`). It is fully
unit-testable without audio or GPU.

### I-002: The alignment engine is pure Eiffel with contracts
**Problem Solved:** the alignment heuristics (window, stop words, jump evidence, LCS over recent
words) are where trackers succeed or fail, and they are usually buried in app code.
**Approach:** `SCRIPT_ALIGNER` over a tokenized `PROMPT_SCRIPT` (normalized words with char
offsets). Invariants:
- position never moves backward without strong evidence;
- jumps of N words need f(N) matched words;
- stop words never move the position.
It runs in microseconds, so the full test matrix runs (skips, repeats, ad-libs, mis-hearings).
**Novelty:** first DBC-specified script follower; the contracts *are* the behavior spec.
**Design Impact:** library/app split; the library has no GUI or audio dependency at its core.

### I-003: Script-biased decoding
**Problem Solved:** ASR mis-hears names and jargon ("SCOOP", "Eiffel", "Heiser").
**Approach:** feed whisper's `initial_prompt` with the script words *already read*, the ~40 words
ending at the current aligned position. This primes vocabulary and spelling ("Eiffel", "SCOOP")
without telling the model what comes next.
**Spike correction (evidence/spike-cuda-whisper.md):** prompting with the words *ahead* made
whisper hallucinate (" and that we can also do a lot of things..."), because the prompt means "already
spoken". Prior-text prompting was stable. For true look-ahead biasing, sherpa-onnx hotwords are the
mechanism, not whisper prompts.
**Novelty:** most trackers decode blind and align afterward; we feed the recognizer the script it has already passed.
**Design Impact:** the ASR worker takes a per-decode prompt from the follower (a message that
crosses the SCOOP boundary).

### I-004: Camera calibration instead of "drag it near the camera"
**Problem Solved:** Windows laptops and external webcams put the lens in different places; no
Windows prompter calibrates (moody-windows explicitly lacks it).
**Approach:** one-time "put the crosshair on your camera lens" step per monitor. The panel anchors
its top-center ~1 cm below that point; eye-contact research says the eye-contact sweet spot is ~2 deg below the lens.
**Design Impact:** per-monitor geometry + DPI module (missing from simple_shell; add it there).

### I-005: Capture-invisible by construction
**Problem Solved:** per-pixel-alpha windows (UpdateLayeredWindow) can't be excluded from capture
(MS: "not supported", error 8).
**Approach:** Moody's panel is opaque black anyway (it merges with the bezel). Use an opaque
popup with a rounded region (or DWM rounded corners) and draw the glow and fades inside it with
Cairo. Then WDA_EXCLUDEFROMCAPTURE applies cleanly.
**Design Impact:** no layered-window code path needed for the MVP; simple_shell gains
`set_capture_excluded` + rounded popup.

### I-006: Ecosystem lift
Every gap filled lands in the owning library, not in simple_prompter:
- simple_speech: CUDA build, streaming, token timestamps, VAD.
- simple_audio: 16 kHz capture, selectany fix.
- simple_shell: capture exclusion, monitors, DPI.
- hotkeys: multi-id library extracted from ocr_capture.
These benefit simple_narrate, simple_ocr_capture, simple_widgets' SW_DICTATION and the planned
simple_speech Phase 8 (streaming).

## Differentiation from Existing Solutions
| Aspect | Existing | Our Approach | Benefit |
|--------|----------|--------------|---------|
| Voice following | Volume gate (Moody) or ASR-only jumps (followspot) | VAD motion + ASR position + spring | Instant and accurate |
| Noise | "might interpret it as speech" | Silero VAD + alignment must agree | Keyboard clicks don't scroll |
| Jargon | Blind decode | Already-read script as prompt (spike-verified safe) | Fewer misses on names |
| Placement | Notch (fixed) or manual drag | Per-monitor camera calibration | Works on any webcam |
| Capture hiding | Electron `setContentProtection` | Native affinity on an opaque popup | Reliable, no layered-window trap |
| Compute | CPU / Apple Speech | Local CUDA whisper, CPU fallback | Large model, real-time, private |
| Verifiability | Heuristics in app code | DBC-specified aligner + follower | Behavior is specified and tested |
