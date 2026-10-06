# LANDSCAPE: simple_prompter

Web research 2026-10-05 (URLs in REFERENCES.md). Ecosystem sweep 2026-10-05, read-only, file:line cited.

## Key finding
Prompters split into two families:
1. **Volume/VAD-gated constant scroll:** Moody, CueNotch, NotchPrompter, moody-windows. Simple and
   instant, but noise counts as speech, and the app has no idea where you are in the script.
   Moody's own FAQ: "Loud background noise can interfere—Moody might interpret it as speech."
2. **Word tracking:** PromptSmart VoiceTrack (patented), Tellie, Textream, followspot, ScriptFollower,
   talkprompter. Streaming ASR, then forward-only fuzzy alignment of heard words to the known script.

## Existing Solutions

### Moody (the reference)
| Aspect | Assessment |
|--------|------------|
| Type | Desktop app, macOS 15+ |
| URL | https://moody.mjarosz.com |
| Price | $39 one-time |
| Voice | "Text scrolls as you speak and pauses when you pause", likely volume-based |
**Strengths:** below the camera; hover/click pause; speed/size/color; countdown; voice-level "beam"; editor; "only you can see the prompter" when screen sharing; on-device.
**Weaknesses:** Mac only; noise-triggered scroll; no word tracking; no import formats documented.
**Relevance:** 95% (UX target).

### PromptSmart (VoiceTrack)
| Type | App, Win/Mac/iOS/Android | URL | https://appsumo.com/products/promptsmart/ |
**Strengths:** true word-level tracking, offline; waits when you ad-lib.
**Weaknesses:** subscription; not hidden from screen share (per sharespeak table); not a camera-pinned overlay.
**Relevance:** 70% (tracking behavior target).

### Notchie / CueNotch / Tellie / NotchPrompter (Mac notch apps)
Notchie: voice-paced, noise suppression, hidden from share, $29.99. CueNotch: volume-based, "Ghost Mode".
Tellie: word-by-word on-device recognition, 40+ languages. NotchPrompter: sound-based.
**Relevance:** 60%: confirms the feature set (hide-from-share is table stakes).

### ShareSpeak / GhostPrompter / FlowPrompter (Windows)
Native Windows, "AI voice-follow", hidden from screen share; GhostPrompter is click-through and placed near the webcam.
**Relevance:** 60%: the Windows competitive bar.

### Open source (code to learn from)
| Project | Stack | Voice method | Notes |
|---------|-------|--------------|-------|
| moody-windows | Electron, MIT | Web Audio volume | `setContentProtection(true)` = WDA_EXCLUDEFROMCAPTURE; no camera-aware positioning; Ctrl+Alt+I click-through, Ctrl+Alt+H hide, Space play/pause |
| glass-prompter | Python/Qt, MIT | Offline ASR | Hidden from Zoom/Teams/Meet/OBS on Win10 2004+ |
| talkprompter | C# WPF .NET 8, MIT | Vosk; sherpa-onnx streaming | "Camera mode" narrow strip at top |
| followspot | whisper.cpp server | 3.5 s window every 0.25 s; Smith-Waterman on words, >=2 matches to move; coast after 1.5 s no-match; Silero VAD | Best documented whisper-based design |
| ScriptFollower | Swift | Forward-only; window 3 back / 40 ahead; exact/plural/Levenshtein 1-2; short words never move; LCS over last 6 heard words | Best documented alignment algorithm, "microseconds per update" |
| Textream | Swift, macOS | Apple Speech word tracking + constant + voice-activated modes | Three-mode design worth copying |

### ASR engine options (local, GPU)
| Engine | Streaming | GPU on Windows | C API | Notes |
|--------|-----------|----------------|-------|-------|
| whisper.cpp 1.8.2 (already wrapped by simple_speech) | Sliding window only (`whisper-stream` is a "naive example") | CUDA via `-DGGML_CUDA=1` | Yes (`whisper.h`) | Built-in Silero VAD since v1.7.6; `--prompt` initial prompt (~224 tokens) can bias toward script text; token timestamps API exists but unwrapped |
| sherpa-onnx | True streaming (zipformer transducer) | onnxruntime-gpu CUDA 11.8/12.x | Yes (`c-api.h`: CreateOnlineRecognizer, AcceptWaveform, Decode, GetResult; hotwords) | Already vendored in simple_speech for diarization (v1.12.20 headers); Blackwell support of onnxruntime-gpu unverified |
| Vosk | Streaming | CPU | Yes; grammar-restricted recognizer | Grammar = script words; CPU only; dated models |
| NVIDIA Nemotron streaming 0.6B | Cache-aware, 80-1120 ms modes, WER 7.8% @160 ms | NeMo (Python) | No ONNX export confirmed | Out unless an ONNX export appears (no Python in product) |
| whisper_streaming / LocalAgreement | Streaming policy | n/a | Python | 3.3 s latency: too slow alone |

## Eiffel Ecosystem Check

### ISE Libraries
- base, time, testing: allowed. Vision2: not used (simple_vision has no topmost/opacity).

### simple_* Libraries (file:line evidence from the sweep)
| Need | Library | State | Evidence |
|------|---------|-------|----------|
| ASR | simple_speech 1.1.1 | PARTIAL: file/PCM only, no streaming, no token timestamps, CPU-only build | `SIMPLE_SPEECH.transcribe_pcm` src/simple_speech.e:167; `WHISPER_ENGINE` whisper_engine.e:93,108; README:33 "Phase 8 (real-time streaming) planned"; wrapper sets `use_gpu=true` Clib/whisper_wrapper.c:9 |
| whisper build | whisper_cpp_build (v1.8.2, 4979e04) | CPU only: `GGML_CUDA:BOOL=OFF` in build/ and build_avx2/ | CMakeCache.txt |
| Models | simple_speech/models | base, base.en, large-v3-turbo-q5_0 (574 MB); Silero v6.2.0 VAD downloaded 2026-10-05 | dir listing |
| Mic capture | simple_audio 1.0 | PARTIAL: WASAPI shared, polled `pump`; likely refuses 16 kHz (no AUTOCONVERTPCM/GetMixFormat); mutable header static `g_enumerator` (audio_bridge.h:76) | `AUDIO_RECORDER`, `AUDIO_DEVICE.peak_level` audio_device.e:173 |
| VAD | none in Eiffel | NO: `whisper_vad_*` declared in whisper.h:680-719, unwrapped | |
| Overlay | simple_shell 1.10.0 | PARTIAL: `SHELL_STRIP` topmost+toolwindow popup, no-activate (simple_shell.h:715-720); `SHELL_OUTLINES` click-through + `SetWindowRgn` (412,424); `SHELL_SHARED` selectany (49) | No SetWindowDisplayAffinity / WS_EX_LAYERED anywhere in simple_* |
| Rendering | simple_cairo 1.3.0, SW_PAINTER | YES for gradients/masks/mono font; no blur | `CAIRO_GRADIENT.make_radial` cairo_gradient.e:35-82; `CAIRO_CONTEXT.mask` cairo_context.e:399; `SW_PAINTER.font(Role_mono)` :47, `rrect_fill` :230 |
| Animation tick | simple_shell | PARTIAL: `SHELL_WINDOW.set_fast_timer` shell_window.e:123 (WM_TIMER, ~15.6 ms granularity); speed_reader uses 12 ms | |
| Hotkeys | simple_ocr_capture 1.15.0 (app-internal) | PARTIAL: single fixed id, modifier-required guard | `OCR_HOTKEY.register` ocr_hotkey.e:57; ocr_hotkey.h:86 |
| DPI / monitors | none | NO: only `SetProcessDPIAware()`; per-monitor code only in simple_sdf's vendored minifb | |
| Settings / script | simple_toml 0.1.2, simple_json, simple_config, simple_file, simple_markdown (HTML only), simple_pdf | YES (no DOCX) | |
| Local LLM | simple_ai_client 1.0.0 `OLLAMA_CLIENT` | YES (default 11434: must pass 11435) | ollama_client.e:281 |
| SCOOP worker to GUI | simple_chat `SUMMARY_SLOT`, simple_taskman `TM_FRAME_SLOT` | YES: pattern; blocking externals must be `C blocking inline` (21 s GUI freeze otherwise, client_app.e:24-34) | |
| Installer | Inno scripts in speed_reader, ocr_capture, speech | YES | |
| Closest app analogue | simple_speed_reader | timed text on SW at 12 ms tick, worker exe, installer | app/sr_app.e:182-193 |

### Gobo Libraries
- Not needed.

### Gap Analysis
Not available in Eiffel today:
1. CUDA whisper build.
2. Live/streaming transcription with token timestamps.
3. VAD.
4. Robust 16 kHz mic capture.
5. Capture-excluded overlay window.
6. Per-monitor DPI and monitor geometry.
7. Multi-id hotkey library.
8. Transcript-to-script alignment (nothing exists).

## Comparison Matrix
| Feature | Moody | PromptSmart | moody-windows | followspot | Our Need |
|---------|-------|-------------|---------------|------------|----------|
| Under-camera overlay | ✓ | ✗ | ✓ (manual drag) | ✗ | MUST |
| Hidden from capture | ✓ | ✗ | ✓ | n/a | MUST |
| VAD/volume pause-resume | ✓ | ✓ | ✓ | ✓ | MUST |
| Word tracking | ✗ | ✓ | ✗ | ✓ | SHOULD (differentiator) |
| Robust to noise | ✗ | ✓ | ✗ | ✓ (Silero) | SHOULD |
| Camera calibration | ✗ (notch is fixed) | ✗ | ✗ | ✗ | SHOULD (gap) |
| Windows native | ✗ | ✓ | Electron | ✗ | MUST |
| Local GPU | n/a | ✗ | ✗ | CPU/GPU | SHOULD |

## Patterns Identified
| Pattern | Seen In | Adopt? |
|---------|---------|--------|
| Forward-only alignment with bounded look-ahead window | ScriptFollower, followspot, PromptSmart | YES |
| Short/stop words never move position | ScriptFollower | YES |
| Bigger jumps need more matching words | ScriptFollower, followspot | YES |
| Coast at measured rate when ASR silent but VAD says speech | followspot | YES |
| Volume-only gating | Moody, CueNotch | YES, as fallback mode only |
| Three modes (track / voice-gated / constant) | Textream | YES |
| `setContentProtection` / WDA_EXCLUDEFROMCAPTURE | moody-windows, glass-prompter | YES |
| Narrow strip at top of screen | talkprompter, all notch apps | YES |
| Hover to pause | Moody | YES |

## Eye contact (layout constraint)
- Perceived eye contact peaks ~2 deg below the lens; tolerance ~3 deg in a 2025 J. Vision study
  (prior estimates +-4.5 deg above / +-5.5 deg below) [PMC12439499].
- Chen (CHI 2002): people are less sensitive to gaze below the camera than to the side (figures
  from search snippets; primary PDF 403).
- At 60 cm: 2 deg = 2.1 cm, 5 deg = 5.2 cm. **Implication:** 2-3 lines, narrow column (horizontal
  tolerance is tighter), panel starts flush under the lens.

## Build vs Buy vs Adapt
| Option | Effort | Risk | Fit |
|--------|--------|------|-----|
| Build in Eiffel on simple_* | MED-HIGH | MED | 95%: ecosystem showcase, local GPU, Larry's own tool |
| Adopt (buy ShareSpeak/GhostPrompter) | LOW | LOW | 50%: closed, no word tracking guarantee, not Eiffel |
| Adapt moody-windows (Electron) | MED | MED | 30%: wrong stack, volume-only |

**Initial Recommendation:** BUILD, reusing simple_speech/simple_audio/simple_shell/simple_cairo, and
fixing their gaps upstream.
