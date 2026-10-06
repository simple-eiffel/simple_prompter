# RISKS: simple_prompter

## Risk Register
| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| RISK-001 | Capture exclusion fails on our window type (error 8) or some capturer ignores it | MED | HIGH | Opaque popup, no UpdateLayeredWindow (D-007); spike with OBS, Teams, Snipping Tool, Game Bar before UI work |
| RISK-002 | Whisper hallucinates on silence or misreads overlapping windows | MED | HIGH | Silero VAD gates decode (noise returned "" in 7 ms); no_context=true; prior-text prompt only; LCS over recent words |
| RISK-003 | Aligner jumps on repeated phrases ("So when you..." appears twice in the reel script) | HIGH | MED | Forward bias + bounded window + jump evidence f(N); contract tests built from the reel script |
| RISK-004 | Ad-libbing drags position or freezes motion awkwardly | MED | MED | Coast up to ~1.5 s at measured rate, then hold; position only moves on anchored matches |
| RISK-005 | simple_audio WASAPI refuses 16 kHz or drops packets | HIGH | HIGH | D-005 hardening; spike with real mic before follower work |
| RISK-006 | Blocking whisper call freezes the GUI | MED | HIGH | `C blocking inline` on the worker processor (C-005); GUI never queries the worker synchronously |
| RISK-007 | WM_TIMER jitter makes scrolling look steppy | MED | MED | Time-based motion; DwmFlush fallback (D-008) |
| RISK-008 | Header statics fork per TU in new inline C (audio, shell additions) | MED | HIGH | `__declspec(selectany)` for every mutable static (C-006); known incident v1.8.0 |
| RISK-009 | GPU contention with OBS NVENC / Ollama while recording | LOW | MED | ~25% GPU duty at 60 ms/250 ms; 573 MB VRAM; drop to base.en or 500 ms step under load |
| RISK-010 | CUDA DLL weight (cublasLt 478 MB) blocks a public installer | HIGH (public) / NONE (Larry) | MED | D-013: CPU default, optional GPU pack, GGML_BACKEND_DL |
| RISK-011 | Mixed-DPI multi-monitor placement wrong | MED | LOW | Per-monitor-v2 awareness; calibration stores per-monitor coordinates |
| RISK-012 | First decode is slow (cold kernels 117-408 ms, model load 5.7 s) | HIGH | LOW | Load + warm-up decode at startup in the background; Voice-gated mode works before the model is ready |
| RISK-013 | Fullscreen apps or other topmost windows cover the panel | LOW | LOW | Re-assert HWND_TOPMOST on a slow tick; documented limitation for exclusive fullscreen |

## Technical Risks

### RISK-001: Capture exclusion
**Description:** WDA_EXCLUDEFROMCAPTURE has caveats: only top-level windows of our process,
only with DWM composition, unsupported on UpdateLayeredWindow windows; Microsoft gives no guarantee.
**Likelihood:** MEDIUM. **Impact:** HIGH (core promise).
**Indicators:** SetWindowDisplayAffinity returns FALSE (GetLastError 8); window visible in an OBS preview.
**Mitigation:** opaque popup; test matrix: OBS display capture, OBS window capture, Teams/Zoom
share, Snipping Tool, Win+PrtScn, Game Bar.
**Contingency:** WDA_MONITOR (shows black in capture); "hide on share" hotkey.

### RISK-002: ASR hallucination and window overlap
**Description:** whisper invents text on silence and noise; overlapping windows re-decode the same words.
**Evidence:** spike gotcha 1 (context carry-over truncation) and gotcha 2 (look-ahead prompt hallucination).
**Mitigation:** VAD gate; no_context; prior-text prompt; aligner treats heard words as noisy evidence;
word probability threshold from verbose output.
**Contingency:** Voice-gated mode remains fully functional.

### RISK-003: Ambiguous script positions
**Description:** scripts repeat phrases; a match to the wrong occurrence jumps the display.
**Mitigation:** nearest-forward occurrence wins; jump evidence scales with distance; spring
smoothing limits visual jump speed; tests built from the reel script's repeated "So when you".

### RISK-005: Live audio path
**Description:** simple_audio has never been proven on a live mic stream at 16 kHz (SW_DICTATION
never pumps; the format request is likely refused).
**Mitigation:** first spike after research: capture 10 s from the default mic, then 16 kHz mono float, then
the CUDA whisper decode. Measure end to end.
**Contingency:** request the mix format (e.g. 48 kHz stereo float) and resample in Eiffel (3:1 decimation with a low-pass filter).

## Ecosystem Risks
- simple_speech changes (CUDA variant, streaming API) must not break speech_cli or SW_DICTATION.
  Keep the CPU build as default; add the CUDA build as a second lib set; run speech tests before/after.
- simple_shell is shared by simple_narrate and simple_ocr_capture (which fork its header):
  additions only, no behavior change to SHELL_STRIP/SHELL_OUTLINES.
- whisper_cpp_build pinned at v1.8.2; the CUDA build uses the same commit, so DLL ABIs match the existing wrapper.

## Resource Risks
- Scope creep (editor, DOCX, LLM helpers, remote) delays the core. Hold them to COULD.
- Three upstream library changes (speech, audio, shell) before the app shines. Sequence them by
  spike order so each lands with a runnable proof.
