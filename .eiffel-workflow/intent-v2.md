# Intent v2: simple_prompter

Date: 2026-10-05. Supersedes intent.md (whose What / Why / Users / Acceptance Criteria / Out of Scope stand,
except as changed below). Review engine: Claude self-review (adversarial), plus the dependency audit.

## Changes from intent.md
1. ISE `time` dropped: simple_datetime for wall timestamps, simple_shell QPC for motion. ISE footprint = `base` + `testing` only.
2. Q4 (recommended): practice mode also captures the mic through ffmpeg's tail file. simple_audio leaves the critical path.
3. Q9 (recommended): speech scheduling logic moves into the pure library (`PT_SPEECH_PIPELINE`), so it's testable headless.
4. New test fixture written: `testing/fixtures/read_test_01.md` + answer key (Larry will record it, `larry_read_01.wav`).

## Deep Review: Questions and Recommended Answers

### Q1. Is this one project, or two (prompter + Take Studio)?
**Why it matters:** 101 classes plus six upstream deltas is a big bite. If Take Studio slips, the prompter must still ship.
**Alternatives:** (a) one project, phase-gated; (b) split `simple_take_studio` into its own library on top of simple_prompter; (c) one project, Take Studio removed until later.
**Recommended:** **(a) one project, phase gates.** P1 ("Moody on Windows") must be usable on its own before any T-phase starts.
The library is pure, so Take Studio classes don't burden P1 at runtime. Splitting later is cheap, because `take/`, `assembly/`
and `output/` depend on `script/` but nothing in `script/`/`follow/` depends on them.

### Q2. Approve `simple_text_structure` (new library, extracted from simple_speed_reader)?
**Why it matters:** the alternative is a second tokenizer in the ecosystem (the oracle "enumerate first" rule).
**Alternatives:** (a) new library `simple_text_structure` (STS_); (b) put the tokenizer into simple_markdown; (c) copy SR classes into simple_prompter.
**Recommended:** **(a)**. Migrate simple_speed_reader onto it **after** prompter P1 (it isn't blocking, and
SR keeps working meanwhile). (b) mixes concerns: markdown syntax vs prose structure. (c) duplicates code.

### Q3. Order of upstream (U-0) work and how heavy each is
**Why it matters:** six libraries; a full spec-kit run for each would stall the prompter for weeks.
**Alternatives:** (a) full spec kit per library; (b) scoped change per library: contracts + tests + docs, recorded in its CHANGELOG; (c) build inside simple_prompter first, upstream later.
**Recommended:** **(b), in this order:**
1. simple_shell (SHELL_PANEL + capture exclusion: unblocks spike S-2 and P1's pill);
2. simple_speech (VAD + decode params + word timestamps + CUDA variant);
3. simple_text_structure (extraction);
4. simple_markdown (`to_plain_text`);
5. simple_ffmpeg (dshow listing);
6. simple_audio (optional per Q4).

(c) violates "fix gaps in the owning library".

### Q4. Practice-mode audio: harden simple_audio WASAPI, or use ffmpeg for the mic always?
**Why it matters:** simple_audio has untested live capture (no 16 kHz, a packet bug, a header static, SW_DICTATION
never pumps). Two capture paths means two sets of bugs.
**Alternatives:**
- (a) harden simple_audio, using it in practice mode and ffmpeg in recording mode;
- (b) **always ffmpeg**: practice mode runs `ffmpeg -f dshow -i audio=… -f f32le -flush_packets 1 tee.f32` (audio only, no video). The same `PT_TAIL_SOURCE` serves both modes;
- (c) always simple_audio, and mux its audio into the recording later.

**Recommended:** **(b)**. One audio path, already spike-proven for latency (tail file within ~0.17 s), the same
sample clock in both modes, no new C. Costs ~0.5 s of ffmpeg start-up when entering practice mode, which is acceptable.
simple_audio hardening drops to "nice to have" (still worth doing for SW_DICTATION, but not on this project's
critical path). `PT_WASAPI_SOURCE` is removed from v1.

### Q5. Which follow mode is the default?
**Why it matters:** Tracking is the differentiator but lands in P2. Defaulting to an unproven mode makes the first experience bad.
**Alternatives:** (a) Voice-gated default always; (b) Tracking default once its P2 acceptance passes, Voice-gated before; (c) ask at first run.
**Recommended:** **(b)**. Voice-gated is the default through P1. When P2's 5-minute ≤ 1-line test passes on
`larry_read_01.wav` plus a live read, the default flips to Tracking (falling back to Voice-gated automatically if no GPU or model is found).

### Q6. Journal storage: JSONL file or SQLite?
**Why it matters:** the crash-recovery promise rests on it. SQLite is transactional, but the ecosystem had a GC
close bug (memory: sqlite close-during-GC use-after-free, fixed 2026-09-28).
**Alternatives:** (a) JSONL, one flushed line per event; (b) SQLite via simple_sql (SR_LOG pattern); (c) both.
**Recommended:** **(a) JSONL.**
- Human-readable.
- Trivially greppable.
- A torn last line after a crash is detectable and skippable (contract `skipped_lines`).
- No database lifecycle.

**Verify at /eiffel.contracts:** simple_file supports append + flush per line. If not, add it there, not in
simple_prompter.

### Q7. What if capture exclusion fails in spike S-2?
**Why it matters:** "invisible on screen share" is a headline promise.
**Alternatives:** (a) block P1 until it works; (b) ship with a visible "NOT HIDDEN" badge plus a hide hotkey; (c) fall back to DirectComposition (much more C).
**Recommended:** **(b) for P1, (c) only if the spike shows the opaque-popup path is impossible.**
`is_capture_excluded` is already an observable status, and the badge is the honest UI. For recording-only use (webcam, not
screen), exclusion doesn't matter at all.

### Q8. Session storage location and disk budget
**Why it matters:** 1080p30 raw recordings are large. Bitrate is unmeasured; an estimate of ~10-15 Mbps is ~1 GB per 10-15 min.
**Alternatives:** (a) `%USERPROFILE%\Videos\simple_prompter\<yyyy-mm-dd>-<script>.take\`; (b) next to the script file; (c) ask every time.
**Recommended:** **(a), configurable in Settings**, with the preflight disk check (FR-NEW-003) using the
**measured** bitrate from T-0, plus a 10-minute free-space warning.

### Q9. The speech worker is the hardest part to test. Can more of it be pure?
**Why it matters:** SCOOP + whisper + audio in one class means bugs only show up live.
**Alternatives:** (a) leave the worker monolithic in `speech/`; (b) split: pure `PT_SPEECH_PIPELINE` (frames,
VAD-gated window scheduling, 250 ms cadence, prompt bookkeeping, record encoding) in the library, driven by injected
`PT_VAD` / `PT_DECODER` deferred classes, with a thin `PT_SPEECH_WORKER` processor wrapper; (c) test only through the app.
**Recommended:** **(b)**.
- The pipeline is tested headless with scripted VAD and decoder outputs. `larry_read_01.wav` can drive it through a file source in an integration test.
- The SCOOP wrapper only owns the processor and the `C blocking inline` calls.

Adds 3 library classes: `PT_SPEECH_PIPELINE`, `PT_VAD`, `PT_DECODER`. Removes logic from `PT_SPEECH_WORKER`.

### Q10. Edit Floor preview through ffplay: acceptable UX?
**Why it matters:** ffplay opens its own window with its own key bindings, and has no frame-accurate scrub.
**Alternatives:** (a) ffplay child windows (v1); (b) embedded frame view (decode JPEG frames into an SW image) plus system audio; (c) open the take range in VLC.
**Recommended:** **(a) for T4**, with `-ss/-t`, `-autoexit`, window title naming the take, and placement next to the Edit Floor. (b) is the
first T4+ improvement if (a) feels clumsy in Larry's real use. (c) has no reliable range control.

### Q11. Installer and GPU distribution now or later?
**Why it matters:** cublasLt64_13.dll is 478 MB. Packaging early wastes effort while the design moves.
**Alternatives:** (a) installer in P1; (b) dev builds only until T2, Larry's CUDA toolkit on PATH; (c) never (Larry-only tool).
**Recommended:** **(b)**. Installer after T2 (SR .iss template; ffmpeg/whisper DLLs isolated in subfolders;
optional GPU pack per D-013). Public-release decisions wait for real use.

### Q12. Naming check
**Why it matters:** names are the API.
**Review:**
- `PT_` prefix: verified free.
- `SIMPLE_PROMPTER` facade: house convention.
- "Edit Floor" (`PT_EDIT_FLOOR_WINDOW`) is Larry's own phrase.
- `PT_TAIL_SOURCE`: clear (tails a growing file).
- `PT_TRANSITIONS`: clear.
- One rename recommended: `PT_TAKE_CONTROLLER` → keep. `PT_ACTION.Pick` → **`Pick_word`**, matching `pick_word` and avoiding "pick a take" confusion in the Edit Floor.

**Recommended:** accept, with the `Pick_word` rename.

## Testability of Acceptance Criteria

| Criterion | Deterministic test? | How |
|-----------|---------------------|-----|
| Solver exact cover / no stale / star wins | YES | Synthetic journals (TEST_SET_BASE) |
| Again ≤ 50 ms, caret, count-in | YES (logic) + manual timing | Controller tests; pasted live timing |
| Inline edit id preservation | YES | History tests |
| Journal replay after crash | YES | Truncated JSONL fixture |
| Voice-gated latencies | YES | `larry_read_01.wav` pause section through `PT_SPEECH_PIPELINE` with real VAD (integration) |
| Tracking ≤ 1 line | YES (replay) + live | `larry_read_01.wav` + answer key rows 6-12 |
| Capture exclusion | MANUAL | Spike S-2 screenshots (pasted) |
| Frame-accurate render | YES | Burned-clock source + frame compare (spike method) |
| Frame time p99 | MANUAL/MEASURED | Instrumented build log, pasted |
| Zero network calls | MANUAL | Process monitor during a session (pasted) |

## Dependency Audit (simple_* First)

All needs map to simple_* libraries, verified during research and spec (file:line evidence in research/02 and
spec/03-04):

| Need | Library | Status |
|------|---------|--------|
| Collections | ISE base | Allowed (no equivalent) |
| Testing | ISE testing + simple_testing 1.0 | Allowed (house standard) |
| Models | simple_mml 1.0 | Present |
| Timestamps | simple_datetime | Present (replaces ISE time) |
| JSON | simple_json 1.0.0 | Present |
| TOML | simple_toml 0.1.2 | Present |
| Files / UTF-8 | simple_file 1.0.0, simple_encoding | Present (UTF-8 `content` bug to verify, A-112) |
| Markdown | simple_markdown 1.0.0 | Present; needs `to_plain_text` |
| Text structure | simple_text_structure | **Gap → new library (Q2)** |
| Window / monitors / hotkeys / timer / QPC | simple_shell 1.10.0 | Present; needs SHELL_PANEL, SHELL_MONITORS, SHELL_HOTKEYS |
| Views / painting | simple_widgets, simple_cairo 1.3.0 | Present |
| Speech | simple_speech 1.1.1 | Present; needs VAD/decode params/words/stream/CUDA |
| Processes | simple_process | Present (`write_input` SHOULD) |
| dshow listing | simple_ffmpeg 1.0 | Present; needs listing |
| Mic (practice) | simple_audio 1.0 | Not needed in v1 if Q4 accepted |

## Gaps Identified (Potential simple_* Libraries)

| Gap | Current Workaround | Proposed simple_* |
|-----|-------------------|-------------------|
| Prose structure (tokens, sentences, paragraphs, sections, navigation) | Lives inside simple_speed_reader app | **simple_text_structure** (Q2) |
| Capture-excluded / topmost panels, monitors, multi-hotkeys | App-local headers (ocr_capture, narrate forks) | simple_shell additions (not a new lib) |
| Streaming ASR + VAD | none | simple_speech Phase 8 (its README already plans streaming) |

## MML Decision
**Decision:** YES-Required (library core: script history, journal, cut list, word timeline, speech map, layout, keymap, slot).
**Rationale:** the collection laws (append-only, exact cover in order, id preservation, frame conditions) are only
expressible as model postconditions; invariants stay O(1).

## Approval
**APPROVED by Larry, 2026-10-05 ("Approve")**: all 12 recommendations accepted, no overrides.
Spec changes applied in spec/09-ADDENDUM-INTENT.md. Next: `/eiffel.contracts d:/prod/simple_prompter`.
