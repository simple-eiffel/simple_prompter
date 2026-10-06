# DECISIONS: simple_prompter

Evidence: `../evidence/video-analysis.md`, `../evidence/spike-cuda-whisper.md`, 02-LANDSCAPE.md.
Status: proposed. Larry approves or changes these at /eiffel.intent.

### D-001: How to follow the voice
**Question:** volume/VAD gating (Moody), ASR word tracking (PromptSmart), or both?
**Options:**
1. VAD-gated constant scroll: instant, simple, no GPU; drifts, noise-prone, no notion of position.
2. ASR + alignment only: knows position; motion is jumpy between updates and lags at speech onset.
3. Hybrid: VAD drives motion, ASR+alignment drives position and rate (I-001).
**Decision:** 3, delivered as three user modes: **Tracking** (hybrid, default when a GPU is
present), **Voice-gated** (VAD only), **Constant** (manual), as Textream does.
**Rationale:** the spike shows ASR costs ~60 ms per 3 s window on the 5070 Ti, so tracking is cheap.
VAD alone handles the pause/resume feel the reel shows. Voice-gated mode reuses the same code with the ASR input switched off.
**Implications:** one `PROMPTER_FOLLOWER` state machine with two inputs; modes are configurations of it.
**Reversible:** YES

### D-002: ASR engine
**Question:** whisper.cpp (already wrapped) vs sherpa-onnx streaming zipformer vs Vosk.
**Options:**
1. whisper.cpp CUDA, sliding 3 s window every 250 ms: measured 53-63 ms warm, word timestamps, built-in Silero VAD; reuses simple_speech.
2. sherpa-onnx streaming transducer: true streaming, hotwords for look-ahead bias; onnxruntime-gpu on Blackwell unverified; new wrapper surface.
3. Vosk grammar mode: CPU only, dated models.
**Decision:** 1 (whisper.cpp CUDA, large-v3-turbo-q5_0 on GPU, base.en on CPU fallback). Keep 2 as the
contingency if tracking quality needs look-ahead hotwords or if latency at speech onset proves too high.
**Rationale:** measured, already in the ecosystem, one engine for file transcription and live use.
**Implications:** extend simple_speech (see D-004). Decode params: greedy, `no_context = true`
(spike gotcha 1), prompt = already-read script only (gotcha 2), token timestamps on.
**Reversible:** YES (engine behind a deferred `PROMPTER_RECOGNIZER`)

### D-003: In-process vs whisper-server child
**Question:** call whisper.dll in-process from a SCOOP worker, or run `whisper-server` and POST over HTTP?
**Options:**
1. In-process via simple_speech: no ports, no child lifecycle, one install; needs `C blocking inline` and a SCOOP processor.
2. Child whisper-server: process isolation (a CUDA crash doesn't kill the GUI); HTTP+multipart per window; port management.
**Decision:** 1 for the product. whisper-server stays as a dev harness for measuring and regression-testing decode quality.
**Rationale:** the ecosystem has the SCOOP worker + slot pattern (simple_chat, simple_taskman) and simple_speech already links whisper.dll.
**Reversible:** YES

### D-004: Where new speech capabilities live
**Decision:** in **simple_speech**, not in simple_prompter:
- CUDA build variant (ggml-cuda.dll);
- decode params (no_context, prompt, greedy, audio_ctx);
- token/word timestamps + probabilities (`whisper_full_get_token_data`);
- VAD (`whisper_vad_*`, Silero v6.2.0 model);
- a `SPEECH_STREAM` rolling-window API.
This is simple_speech's planned "Phase 8 (real-time streaming)" (README:33).
**Rationale:** "fix lib gaps in the lib"; SW_DICTATION, simple_narrate and others benefit.
**Reversible:** NO (ecosystem placement), cheap to adjust.

### D-005: Microphone capture
**Decision:** harden **simple_audio** (WASAPI shared mode):
- `AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | SRC_DEFAULT_QUALITY` to get 16 kHz mono from the mix format, or GetMixFormat + an Eiffel resampler;
- fix the partial-packet release;
- make `g_enumerator` `__declspec(selectany)`;
- event-driven or tight-pump capture on the worker processor.
**Rationale:** the gaps the sweep found (audio_bridge.h:76; no 16 kHz) block every live-speech app, not only this one.
**Reversible:** YES

### D-006: Concurrency
**Decision:** SCOOP. One `separate` **speech worker** owns the audio client, VAD and whisper context.
It deposits small value messages (`VOICE_FRAME` level+speech flag every ~30 ms, `HEARD_WORDS` every
~250 ms) into a non-blocking slot. The GUI tick drains it, as `TM_FRAME_SLOT`/`SUMMARY_SLOT` do.
The GUI never waits on the worker. The worker receives `prompt_text` updates the other way.
**Rationale:** C-001, C-005; proven pattern; a 21 s freeze otherwise (simple_chat).
**Reversible:** NO

### D-007: Overlay window
**Options:**
1. Per-pixel alpha layered window (UpdateLayeredWindow): true translucency; **can't be excluded from capture** (MS forum, error 8).
2. Opaque WS_POPUP, rounded region / DWM corner preference, all effects drawn inside with Cairo.
3. DirectComposition + WS_EX_NOREDIRECTIONBITMAP: translucency + affinity (Electron route); much more C.
**Decision:** 2. Extend **simple_shell** with:
- a `SHELL_PANEL`-style popup (topmost, toolwindow, noactivate);
- `set_capture_excluded` (WDA_EXCLUDEFROMCAPTURE, fall back to WDA_MONITOR);
- rounded shape;
- optional click-through;
- whole-window alpha via SetLayeredWindowAttributes (compatible with affinity).
**Rationale:** Moody's pill is opaque black; option 2 is simplest and keeps the "invisible" promise.
**Reversible:** YES (3 later if translucency is wanted)

### D-008: Rendering and frame pacing
**Decision:**
- Cairo (simple_cairo / SW_PAINTER) into the panel's DC.
- Text layout is cached as a pre-rendered strip, so each frame is one blit + fade mask + radial glow.
- Pacing: `set_fast_timer(16)` first and measure jitter. If it steps visibly, move to DwmFlush-paced frames on the GUI processor.
- Scroll offset is a REAL_64 advanced by `velocity * dt` from a high-resolution clock, never by tick count.
**Rationale:** WM_TIMER granularity is ~15.6 ms; time-based motion hides tick jitter.
**Reversible:** YES

### D-009: Alignment algorithm
**Decision:** forward-biased bounded-window fuzzy matcher in pure Eiffel (ScriptFollower + followspot ideas):
- normalized word tokens;
- window 3 back / 40 ahead;
- match = exact, stem/plural, or bounded Levenshtein (<=1 for short, <=2 for long);
- stop words never move the position;
- jump size N needs 1/2/3+ anchored matches;
- score the last ~6 heard words by LCS against the window, which absorbs whisper's revisions across overlapping windows;
- a backward move needs strong evidence (re-read).
Rate estimate = aligned words / speech time.
**Rationale:** microseconds per update; fully contract-testable (I-002).
**Reversible:** YES

### D-010: Placement
**Decision:**
- Default top-center of the primary monitor.
- Calibration step stores camera point per monitor (device name + resolution key).
- Panel anchors just below it.
- Per-monitor-v2 DPI awareness added to simple_shell.
**Reversible:** YES

### D-011: Script format and settings
**Decision:**
- Scripts: .txt and .md (strip Markdown to plain text; headings become section markers for jump-to-section; `[CUE]` brackets render dimmed and are excluded from alignment).
- Settings: TOML via simple_toml in `%APPDATA%\simple_prompter\settings.toml`.
- DOCX later.
**Reversible:** YES

### D-012: Hotkeys
**Decision:**
- Extract `OCR_HOTKEY` into a reusable multi-id hotkey class (simple_shell or a small simple_hotkey) with the modifier-required interlock.
- Defaults (all with Ctrl+Alt): Space play/pause, Up/Down speed, Left/Right line, H hide, I click-through, R restart.
**Reversible:** YES

### D-013: GPU distribution
**Facts:** ggml-cuda.dll is 44 MB; it needs cudart64_13 (0.5 MB), cublas64_13 (52 MB) and **cublasLt64_13 (478 MB)**.
**Decision:**
- Larry's machine: CUDA toolkit already on PATH, nothing extra to ship.
- Public installer: CPU build by default plus an optional "GPU pack" download.
- Investigate `GGML_BACKEND_DL=ON` so ggml-cuda loads at runtime and its absence just means CPU.
**Reversible:** YES

### D-014: Library / app split
**Decision:** `simple_prompter` library (ECF library target) holds:
- `PROMPT_SCRIPT`, `SCRIPT_TOKENIZER`, `SCRIPT_ALIGNER`, `PROMPTER_FOLLOWER`, `SCROLL_MODEL`;
- settings;
- the speech-worker facade.
No GUI dependency in the core. The `prompter` app target holds the panel, renderer, hotkeys, calibration and editor.
**Rationale:** the core is testable headless (TEST_SET_BASE), and other apps can reuse the follower (e.g. simple_narrate karaoke-style read-along).
**Reversible:** YES
