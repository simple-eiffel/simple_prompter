# 09 ADDENDUM: changes from the approved intent (2026-10-05)

Larry approved intent-v2.md with **all 12 recommendations** ("Approve", 2026-10-05). Where this
addendum and 04-08 disagree, this addendum wins. /eiffel.contracts works from 04-08 + this file.

| Q | Decision | Spec change |
|---|----------|-------------|
| Q1 | One project, phase-gated; P1 must be usable alone | none (07 §1 phases stand) |
| Q2 | Create `simple_text_structure` (STS_); simple_speed_reader migrates after prompter P1 | none (04 §1.1 stands) |
| Q3 | Upstream as scoped changes, order: simple_shell → simple_speech → simple_text_structure → simple_markdown → simple_ffmpeg → (simple_audio optional) | 07 §1 U-0 order fixed to this |
| Q4 | **ffmpeg captures the mic in every mode** (practice = audio-only dshow → tee.f32) | **Remove `PT_WASAPI_SOURCE`** from speech/; simple_audio leaves the dependency list for v1; `PT_CAPTURE_PLAN` gains `make_audio_only`; `PT_TAIL_SOURCE` serves both modes; recording clock works the same in practice mode (journal still off) |
| Q5 | Voice-gated default until P2 passes on larry_read_01.wav + a live read; then Tracking (auto-fallback without GPU/model) | `PT_SETTINGS.default_mode` logic |
| Q6 | Journal = JSONL, one flushed line per event | **Contracts phase: verify simple_file append + flush per line; if absent, add it to simple_file** |
| Q7 | If capture exclusion fails: "NOT HIDDEN" badge + hide hotkey; DirectComposition only if the opaque path is impossible | `PT_PILL_RENDERER` badge state from `is_capture_excluded` |
| Q8 | Sessions in `%USERPROFILE%\Videos\simple_prompter\<yyyy-mm-dd>-<script>.take\`, configurable | `PT_SETTINGS.sessions_root`; `PT_PREFLIGHT` uses measured bitrate (T-0) |
| Q9 | **Pure speech pipeline** | **Add to library src/follow:** `PT_SPEECH_PIPELINE` (frame cadence, VAD-gated 3 s / 250 ms window scheduling, prompt bookkeeping, record encoding), `PT_VAD` (deferred: `speech_probability (samples): REAL_64`), `PT_DECODER` (deferred: `decode (window, prompt): PT_HEARD_WORDS`). Test doubles `PT_SCRIPTED_VAD`, `PT_SCRIPTED_DECODER`. `PT_SPEECH_WORKER` keeps only the processor + `C blocking inline` effective classes `PT_SILERO_VAD`, `PT_WHISPER_DECODER` (speech/) |
| Q10 | Edit Floor preview via ffplay (`-ss/-t`, `-autoexit`, titled, placed beside the window) | none |
| Q11 | Dev builds only until T2; installer after | none |
| Q12 | Rename `PT_ACTION.Pick` → **`Pick_word`** | Applied to 04, 05, 07 on 2026-10-05 |

Also from the audit: **ISE `time` removed**: `simple_datetime` for wall timestamps; the library target
depends on base + simple_* only (+ testing in the test target).

## Net class count after the addendum
- Library: 77 + `PT_SPEECH_PIPELINE`, `PT_VAD`, `PT_DECODER`, `PT_SCRIPTED_VAD`, `PT_SCRIPTED_DECODER` = **82**.
- speech/: 7 − `PT_WASAPI_SOURCE` + `PT_SILERO_VAD`, `PT_WHISPER_DECODER` = **8**.
- runtime 5, app 11, worker 1, so **107 simple_prompter classes** (+ 7 STS_).

## New fixtures
- `testing/fixtures/read_test_01.md` + `read_test_01.answer_key.md` (12 scored behaviors).
- `testing/fixtures/larry_read_01.wav` (pending: Larry records it).
