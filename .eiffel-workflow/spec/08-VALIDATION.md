# DESIGN VALIDATION: simple_prompter

Date: 2026-10-05. Validates 01-07. Nothing compiled yet: this checks the design, not the code.

## OOSC2 Compliance

| Principle | Status | Evidence |
|-----------|--------|----------|
| Single Responsibility | ✓ | 04 inventory gives one responsibility per class. Policies (matcher, restart, transitions, stop words) are separate from engines |
| Single Choice | ✓ | State machine in `PT_TRANSITIONS` only (07 §2.6); event mapping only inside `PT_TAKE_CONTROLLER.perform` (07 §2.12); bytes→rt only in `PT_RECORDING_CLOCK`; capture args only in `PT_CAPTURE_PLAN` |
| Open/Closed | ✓ | New follow modes = new `PT_FOLLOWER` descendant; new transcriber/audio source = new descendant; voice commands (deferred) would add an input route, not change the controller |
| Liskov Substitution | ✓ | 04 §5 table: descendants keep parent postconditions (followers: never backward, held frozen) and add only `ensure then` |
| Interface Segregation | ✓ | Facade exposes script/follow/take/assembly groups; engines are reachable for advanced clients but the app uses the facade + views |
| Dependency Inversion | ✓ | Library depends on abstractions (`PT_CLOCK`, `PT_TEXT_MEASURE`, `PT_TRANSCRIBER`, `PT_AUDIO_SOURCE`); effects implemented in app/worker clusters |

## Eiffel Excellence

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Command-Query Separation | ✓ (2 documented exceptions) | 06 §4: fluent `with_*` (house exception), `PT_SPEECH_SLOT.take_all` (atomic drain across processors). `PT_TAKE_SOLVER.solve` corrected to command + `last_result` |
| Uniform Access | ✓ | `count`, `output_duration`, `rt` usable as attributes or functions without client change |
| Design by Contract | ✓ | 05 contracts for all engines; invariants O(1); collection laws as postconditions through models |
| Genericity | ✓ (deliberately none) | 04 §6: generic mailbox rejected because SCOOP values cross as encoded strings |
| Inheritance | ✓ | IS-A only (deferred roots + effective policies); no implementation inheritance between engines |
| Information Hiding | ✓ | Storage lists `{NONE}`; revisions created only by parser/history (`create {PT_SCRIPT_PARSER, PT_SCRIPT_HISTORY}`) |

## Practical Quality

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Void-safe | ✓ | Optional event fields `detachable` with kind-based invariants; results with failure use XOR |
| SCOOP-compatible | ✓ | One `separate` speech worker + slot; batch analysis as a job in that worker after Wrap (debate 01); GUI never waits (06 §6) |
| simple_* first | ✓ | 03 "Design Constraints Validated"; tokenizer extracted from simple_speed_reader rather than rewritten (A-103) |
| MML postconditions | ✓ | 05 model table (11 models). The non-iterability of models was caught and fixed (rule 11; oracle gotcha recorded) |
| Invariants O(1) | ✓ | Reviewed every invariant in 05/07: scalars, counts, attachment checks only |
| Per-target assertions | ✓ | 04 §8 (C-010) |
| Testable | ✓ | Pure library target; fakes for clock/measure/transcriber; fixtures listed (07 §5) |

## Requirements Traceability

| Requirement | Addressed By | Phase | Status |
|-------------|--------------|-------|--------|
| FR-001 overlay | `SHELL_PANEL` (U-0) via `PT_PILL` | P1 | ✓ |
| FR-002 default position | `SHELL_MONITORS`, `PT_SETTINGS`, `PT_PILL` | P1 | ✓ |
| FR-003 capture exclusion | `SHELL_PANEL.set_capture_excluded`, `is_capture_excluded` indicator | P1 (+S-2) | ✓ (spike pending) |
| FR-004/005 look, fade | `PT_PILL_RENDERER`, `PT_LAYOUT` | P1 | ✓ |
| FR-006 smooth scroll | `PT_SCROLL_MODEL`, `PT_QPC_CLOCK`, 16 ms tick | P1 | ✓ |
| FR-007 adjustable/persisted | `PT_SETTINGS`, `PT_CAMERA_ANCHOR` | P1 | ✓ |
| FR-008 glow | `PT_PILL_RENDERER` (simple_cairo radial gradient) from voice level | P1 | ✓ |
| FR-009 calibration | `PT_CALIBRATION_OVERLAY`, `PT_CAMERA_ANCHOR` | P2 | ✓ |
| FR-010 countdown/time | `PT_TAKE_CONTROLLER` count_in, renderer | T1 | ✓ |
| FR-020 capture | `PT_WASAPI_SOURCE` (simple_audio U-0) | P1 | ✓ |
| FR-021 voice-gated | `PT_VOICE_GATED_FOLLOWER` (ramps 0.15/0.20 s) | P1 | ✓ |
| FR-022 constant | `PT_CONSTANT_FOLLOWER` (full skeleton 07 §2.10) | P1 | ✓ |
| FR-023/024/025 tracking | `PT_ALIGNER`, `PT_TRACKING_FOLLOWER`, `PT_WORD_MATCHER` | P2 | ✓ |
| FR-026 Silero | `PT_SPEECH_WORKER` with `SPEECH_VAD` | P1 | ✓ |
| FR-040 .txt/.md | `PT_SCRIPT_PARSER` + simple_markdown.to_plain_text + STS | P1 | ✓ |
| FR-041 edit/reload | `PT_INLINE_EDITOR`, `PT_SCRIPT_HISTORY` | T1 | ✓ |
| FR-042 hotkeys | `PT_KEYMAP` + `SHELL_HOTKEYS` | P1 | ✓ |
| FR-043 mouse | `PT_INPUT_ROUTER` | P1 | ✓ |
| FR-044 cues | `PT_SCRIPT_PARSER` (is_cue), matcher `cue_never` | P1 | ✓ |
| FR-T01 Again | `PT_TAKE_CONTROLLER.perform (Again)`, `PT_RESTART_POLICY.again_caret` | T1 | ✓ |
| FR-T02 browse/pick | `pick_word`, Back/Forward actions | T1 | ✓ |
| FR-T03 surfaces | `PT_INPUT_ROUTER` → same `PT_ACTION`s | T1 | ✓ |
| FR-T04 bare keys | `PT_KEYMAP` invariant `bare_only_when_recording` | T1 | ✓ |
| FR-T05 revisions | `PT_SCRIPT_HISTORY.apply_edit` (id preservation postconditions) | T1 | ✓ |
| FR-T06 no stale | `PT_TAKE_SOLVER` `no_stale` | T2 | ✓ |
| FR-T07 recording | `PT_CAPTURE_PLAN` (mjpeg, pcm_s16le, f32le tee), `PT_RECORDER` | T1 | ✓ |
| FR-T08 rt marks | `PT_RECORDING_CLOCK` (bytes / 64,000), `PT_TAIL_SOURCE` | T1 | ✓ |
| FR-T09 journal | `PT_JOURNAL` (append-only; torn-line replay) | T1 | ✓ |
| FR-T10 refine | `PT_SESSION_ANALYZER`, `PT_ATTEMPT_ALIGNER`, `PT_SILENCE_SNAPPER` | T3 | ✓ |
| FR-T11 solver | `PT_TAKE_SOLVER` (exact cover as one model equality) | T2 | ✓ |
| FR-T12 Edit Floor | `PT_EDIT_FLOOR_WINDOW`, chips, timeline, `PT_PREVIEW_PLAYER` (ffplay 8.0 present) | T4 | ✓ |
| FR-T13 render | `PT_RENDER_PLAN` (spike recipe), `PT_RENDERER` | T2 | ✓ |
| FR-T14 captions | `PT_CAPTION_BUILDER` | T2 | ✓ |
| FR-T15 review.srt | `PT_REVIEW_SRT_WRITER` | T1 | ✓ |
| FR-T16 flags | `PT_FLAGGER`, `PT_FLAG_KIND` | T3 | ✓ |
| FR-T17 EDL | `PT_EDL_WRITER` (CMX3600 only, 03) | T2 | ✓ (modified) |
| FR-T18 chapters | `PT_CHAPTER_WRITER` | T2 | ✓ |
| FR-T19 punch-in | `PT_RENDER_PLAN` cosmetics option (default off) | T2 | ✓ |
| FR-T20/T22/T23 | `PT_CUT.src` index; writer hook; OBS not designed | later | ◐ COULD |
| FR-T21 voice commands | DEFERRED (F-02) | — | n/a |
| FR-NEW-001 resume by char offset | `PT_SETTINGS` resume point (char_start + revision hash) | P1 | ✓ |
| FR-NEW-002 drag-drop | `PT_APP` (`set_on_files`, SR pattern) | P1 | ✓ |
| FR-NEW-003 preflight | `PT_PREFLIGHT` | T1 | ✓ |
| FR-NEW-004 device loss | `PT_RECORDER` health → controller Abort with reason | T1 | ✓ |
| FR-NEW-005 recovery | `PT_SESSION` load + `PT_JOURNAL.replay_from` | T1 | ✓ |
| FR-NEW-006 decision log | `PT_TAKE_SOLVER.decisions`, analyzer → `analysis/decisions.log` | T2/T3 | ✓ |
| FR-NEW-007 abbreviations | `STS_ABBREVIATIONS` (U-0) | U-0 | ✓ |
| FR-NEW-008 focus self-heal | `PT_APP` | P1 | ✓ |
| NFR-001 pause ≤ 250 ms | VAD 32 ms frames + `Ramp_down_s` 0.20 | P1 | ✓ (measure) |
| NFR-002 tracking ≤ 700 ms | 250 ms step + ~60 ms decode (spike) | P2 | ✓ (measure) |
| NFR-003 frame time | SCOOP worker; GUI never waits; cached text strip | P1 | ✓ (measure S-3) |
| NFR-004 GPU ≤ 2 GB | One resident whisper: ~1.08 GB measured (debate 01, S2); analysis reuses it. *Was "573 + 573 ✓": 573 MB is the file size* | P1 | ✓ |
| NFR-006 privacy | No network code; Ollama not in scope | all | ✓ |
| NFR-007 startup | Worker warms model in background | P1 | ✓ |
| NFR-008 CPU fallback | base.en CPU; voice-gated needs no ASR | P2 | ✓ |
| NFR-009 DPI | `SHELL_MONITORS` per-monitor-v2 | P1 | ✓ |
| NFR-010 1-hour | Bounded slot; no accumulating buffers (tail source reads fixed chunks) | P1 | ✓ (measure) |
| NFR-T01 Again ≤ 50 ms | GUI-local controller + follower hold | T1 | ✓ |
| NFR-T02 no interruption | Tail file: ffmpeg never waits on the GUI (A-101) | T1 | ✓ |
| NFR-T03 analysis ≤ 25% | Job in the live speech worker (debate 01) | T3 | ◐ (unmeasured; debate 01 V1 runs it before Step 4 builds) |
| NFR-T04 render ≤ 30% | NVENC one pass (720p spike ≈ 5%) | T2 | ✓ |
| NFR-T05 raw untouched | Outputs written to `out/`; no writer opens raw.mkv for write | T2 | ✓ |

## Risk Mitigations Implemented

| Risk | Mitigation in Design |
|------|---------------------|
| RISK-001 capture exclusion | Opaque `SHELL_PANEL`; `is_capture_excluded` surfaced; spike S-2 |
| RISK-002 hallucination | VAD gate in worker; decode params (no_context, prior-text prompt); aligner anchors |
| RISK-003 repeated phrases | `PT_ALIGNER` window/jump-evidence contracts; reel-script fixture |
| RISK-005 live audio | Recording uses tail file; WASAPI hardening upstream (practice only) |
| RISK-006 GUI freeze | SCOOP worker; `C blocking inline`; slot drain non-blocking |
| RISK-007 timer jitter | `PT_SCROLL_MODEL` from QPC dt, not tick counts |
| RISK-008 header statics | selectany rule in all U-0 C additions |
| RISK-012 cold decode | Warm-up in worker start; voice-gated usable before ready |
| R-T1 back-pressure | **Removed** by the tail-file design (A-101) |
| R-T2 A/V drift | Spike T-0 (30-min) before T1 sign-off |
| R-T3 wrong take | Journal caret anchors attempt alignment (`PT_ATTEMPT_ALIGNER` searches near the caret) |
| R-T4 bare-key leak | Keymap invariant + release on every exit + stale cleanup at start |
| R-T8 editor creep | T4 limited to choose/nudge/play/restore/render |

## Open Issues

1. **New library `simple_text_structure`** (extracting simple_speed_reader's tokenizer): needs Larry's
   go-ahead (name, and whether simple_speed_reader migrates now or later).
2. **simple_speed_reader test contracts likely unmonitored** (assertions declared only in the
   library target; its `testing` cluster lives in the extending target, the same pattern as the
   simple_taskman incident). Not verified; report only.
3. **Upstream deltas (U-0)** span six libraries. Each needs its own spec-kit pass or a scoped change.
   The order is driven by phases: P1 needs simple_shell + simple_speech VAD + simple_audio +
   simple_markdown + simple_text_structure.
4. **Spikes S-1..S-3 and T-0** are unrun: live mic, capture exclusion vs real capturers, SCOOP slot at
   16 ms, live dshow + tail latency + 30-min drift.
5. **`PT_CUT_LIST.words_model`** relies on each cut carrying its word ids (07 §2.13). Confirm in contracts
   that cut id lists are built from the revision current at the take (stale detection).
6. **QPC interpolation bound** `Max_interpolation_s` in `PT_RECORDING_CLOCK`: pick from T-0 measurements
   (tail flush granularity).
7. **Analysis time** (NFR-T03) unmeasured.

## Ready for Implementation
- [x] All requirements traced (FR-T20/22/23 COULD, partially; FR-T21 deferred)
- [x] All risks mitigated in design (two depend on spikes)
- [x] All principles satisfied
- [x] Design is complete for /eiffel.intent and /eiffel.contracts on the library target

**VERDICT:** READY for `/eiffel.intent`. Before `/eiffel.contracts` compiles anything that touches them,
open issue 1 (library extraction approval) and the U-0 sequencing (issue 3) need Larry's decisions.
