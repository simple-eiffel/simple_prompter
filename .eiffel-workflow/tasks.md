# Implementation Tasks: simple_prompter (Phase 3)

Date: 2026-10-05.
Inputs:
- src/ (87 classes, contracts frozen after the Phase 2 fixes);
- approach.md;
- synopsis.md (approved);
- spec/10-ADDENDUM-CONTRACTS.md;
- real-voice evidence (larry_read_01).

**Scope of `/eiffel.implement`: the pure library (Track A).** Upstream libraries, spikes and the app, speech,
runtime and worker clusters are Track B (end of file); they need their own work and are listed for sequencing only.

**Rules for every task:**
- Contracts are frozen. Implementation fills bodies only; a needed contract change goes back through review.
- Gate: `ec.sh check` on both targets (0 errors, 0 warnings, grep `Error code`), then `ec.sh test` and run the F_code exe.
  Paste the actual output.
- "Tests green" names tests in testing/. A task is done when they pass and no previously green test turns red.
- simple_* first: simple_json (codecs), simple_toml (settings), simple_file (journal), simple_encoding (UTF-8).
  When a task adds a library to the ECF, it audits it (no ISE/Gobo where simple_* exists).

---

## Task 1: Normalizer
**Files:** src/script/pt_normalizer.e
**Features:** normalized
### Acceptance Criteria
- [ ] Lowercase; letters and digits kept; inner apostrophe kept ("they're"); typographic apostrophes mapped to `'`
- [ ] Tests green: `test_normalizer`
- [ ] Decide L18: keep `normalized_not_longer` (document English-only) or relax it (that needs review)
### Implementation Notes
Single pass over the characters. Dashes and quotes are dropped.
### Dependencies
None

---

## Task 2: Script parser (interim tokenizer behind the final contracts)
**Files:** src/script/pt_script_parser.e
**Features:** parse
### Acceptance Criteria
- [ ] Words with fresh ids; passages (sentences); paragraphs; sections from `#` lines; heading words `is_heading`; `[CUE: ...]` words `is_cue`; stop-word flags
- [ ] Abbreviations ("Dr.", "Mr.", "Ms.", "Mrs.", "e.g.", "i.e.", "U.S.", "vs.", "etc.", "St.") do not end sentences (FR-NEW-007)
- [ ] Tests green: `test_parser_finds_words_and_passages`, `test_parser_cues_are_not_spoken`; facade tests no longer fail on `words_found`
- [ ] New test: `read_test_01.md` parses into the expected passage and section counts; "Dr. Meyer" stays in one sentence
### Implementation Notes
- Interim local tokenizer modeled on SR_TOKENIZER (whitespace split, `source_start` offsets, sentence ends `. ! ?` and the ellipsis, closing-quote skip).
- Swap to simple_text_structure when Track B U-0 lands; the contracts don't change.
- Markdown: strip `#`, `**`, `_` and link syntax locally until SIMPLE_MARKDOWN.to_plain_text exists.
### Dependencies
Task 1

---

## Task 3: Script history: live edits
**Files:** src/script/pt_script_history.e
**Features:** apply_edit
### Acceptance Criteria
- [ ] LCS on normalized forms keeps the ids of unchanged words inside the range; fresh ids for new words; words outside the range keep their ids; passages, sections and char spans rebuilt
- [ ] Insert (`first = last + 1`) and strike (empty text) both work
- [ ] Tests green: `test_history_edit_keeps_untouched_ids`. New: insert, strike, edit at word 1, edit at the last word
### Dependencies
Task 2

---

## Task 4: Word matcher + phonetic key
**Files:** src/follow/pt_word_matcher.e, src/follow/pt_equivalences.e
**Features:** distance, is_stem_variant, matches, phonetic_key
### Acceptance Criteria
- [ ] Banded Levenshtein with early exit above Max_distance; stem variants (s, es, ed, ing); `matches` uses equivalences
- [ ] Metaphone-style `phonetic_key` so that "celero" and "silero" agree; no false friends (`test_unrelated_words_differ` stays green)
- [ ] Tests green: `test_matcher_exact_and_tolerant`, `test_equivalent_word_matches`, `test_phonetics_from_the_recording`
### Dependencies
Task 1

---

## Task 5: Aligner
**Files:** src/follow/pt_aligner.e
**Features:** update (window LCS, anchors, jump/backward evidence, rate, stale guard)
### Acceptance Criteria
- [ ] Recent-heard buffer (Recent_heard); LCS against [position − Window_back, position + Window_ahead]; only anchored (non-stop) matches move; jump tiers; backward needs Backward_evidence
- [ ] Multi-word heard spans may match one script word, and one joined heard token may match several script words (H7: "for example" ~ "e.g.", "cpp" ~ "c p p")
- [ ] Windows starting before `reanchored_at` are ignored (H3)
- [ ] Rate: aligned words per second over a sliding interval
- [ ] Tests green: `test_aligner_follows_reading`, `test_repeated_phrase_picks_the_forward_occurrence`; `test_stale_window_is_ignored` stays green and becomes meaningful
### Dependencies
Task 4

---

## Task 6: Spring, layout, scroll model
**Files:** src/follow/pt_spring.e, pt_layout.e, pt_scroll_model.e
**Features:** step, build, y_of, tick
### Acceptance Criteria
- [ ] Closed-form critically damped step (no overshoot)
- [ ] Greedy wrap with paragraph breaks; `y_of` interpolates between line tops (monotone, tested by sampling)
- [ ] `tick` snaps back when the follower target drops below the position (H2); otherwise springs forward
- [ ] Tests green: `test_spring_moves_toward_target`, `test_layout_wraps_every_word`, `test_restart_snaps_scroll_back`
### Dependencies
None

---

## Task 7: Voice-gated and tracking followers
**Files:** src/follow/pt_voice_gated_follower.e, pt_tracking_follower.e
**Features:** advance, on_alignment
### Acceptance Criteria
- [ ] Voice-gated ramps (0.15 s up, 0.20 s down); stops ≤ 250 ms after speech ends
- [ ] Tracking: measured rate + spring term toward the aligned word, never negative; coast ≤ Coast_limit, then hold; fallback rate before the first alignment
- [ ] Tests green: `test_voice_gated_moves_only_while_speaking`, `test_tracking_holds_after_coast_limit`; strengthen `test_voice_gated_stops_within_250_ms` to assert motion first (L19)
### Dependencies
None

---

## Task 8: Speech pipeline + speech codec
**Files:** src/follow/pt_speech_pipeline.e, pt_speech_codec.e
**Features:** push, encode_frame, encode_heard, decode
### Acceptance Criteria
- [ ] Ring buffer; one frame per 512 samples with RMS level and VAD probability; threshold + hangover (`is_in_speech`)
- [ ] Decode the last min (samples, Window_samples) at Step_samples boundaries **only while in speech** (M13: add the postcondition through review if missing); prompt passed; decoder disabled = no decodes
- [ ] Optional L21: pending-frame models
- [ ] Codec round trip for frames and heard words (UTF-8; '|' escaped)
- [ ] Tests green: all `TEST_PIPELINE` tests
### Dependencies
None

---

## Task 9: Restart policy
**Files:** src/take/pt_restart_policy.e
**Features:** again_caret, step_back, step_forward
### Acceptance Criteria
- [ ] Again rule (current sentence start; previous sentence if within Early_words; last confident start when unsure); passage and paragraph stepping
- [ ] Tests green: `test_again_caret_rules`. New: step_back/forward at the first/last passage, by paragraph
### Dependencies
None

---

## Task 10: Take controller: event mapping and effects
**Files:** src/take/pt_take_controller.e
**Features:** perform (mapping table, spec 07 §2.12 with the H1 convention), commit_edit, add_marker, sample_alignment
### Acceptance Criteria
- [ ] Events appended only while recording (rt from `current_rt`); follower hold/release/set_caret (caret − 1)
- [ ] Again stores `last_again_target` (M7); browse steps the caret through the policy
- [ ] Skip strikes the caret passage and creates a revision (M14: add the postcondition through review); commit_edit applies the edit, journals, rescales the follower, puts the caret at the passage start, returns to Held
- [ ] Align events rate-limited to ≤ 4/s while recording
- [ ] Tests green: `test_record_then_count_in_done_reads`, `test_again_counts_in_from_sentence_start`, `test_resume_puts_reader_on_the_caret`, `test_practice_writes_no_journal`, `test_commit_edit_makes_a_revision`. New: the cough journal from a scripted action sequence matches the fixture `cough_journal`
### Dependencies
Tasks 3, 9

---

## Task 11: Journal persistence, replay, codec
**Files:** src/take/pt_journal.e, pt_journal_codec.e (+ ECF: simple_json, simple_file)
**Features:** append (persist), replay_from, encode, decode
### Acceptance Criteria
- [ ] **Verify first (approved Q6):** does simple_file support append + flush per line? If not, add it **in simple_file** (Track B) before this task closes
- [ ] JSONL per spec F-01 §9.3; torn last line skipped and counted; rt order preserved on replay
- [ ] L17: `persisted` clause conditioned on `is_persistent` (through review), or rename
- [ ] Tests green: `test_codec_round_trip`. New: write-then-replay through a temp file; a torn final line is skipped
### Dependencies
None (Task 10 uses the in-memory journal)

---

## Task 12: Facade wiring
**Files:** src/simple_prompter.e (+ ECF: simple_encoding)
**Features:** open_script, prompt_text
### Acceptance Criteria
- [ ] UTF-8 read with BOM strip (interim local reader; simple_text_structure / fixed simple_file later); `.md` through the local strip (later SIMPLE_MARKDOWN.to_plain_text)
- [ ] `prompt_text` = the last Prompt_words words before the reader's word
- [ ] Tests green: all `LIB_TESTS`. New: open `read_test_01.md` from disk
### Dependencies
Tasks 2, 5, 10

---

## Task 13: Speech map gaps + cut-list floor
**Files:** src/assembly/pt_speech_map.e, pt_cut_list.e
**Features:** silence_around, floor_spans
### Acceptance Criteria
- [ ] Maximal silent interval around t; complement of the kept spans per source
- [ ] Tests green: `test_floor_is_the_complement`. New: silence_around on the larry_read_01.vad.tsv map at 20.0 s gives 19.17-22.85
### Dependencies
None

---

## Task 14: Attempt builder
**Files:** src/assembly/pt_attempt_builder.e, (journal helpers)
**Features:** build
### Acceptance Criteria
- [ ] One attempt per Resume, closed at Hold/Flub/Wrap/Abort or the end; word range estimated from Align samples
- [ ] **M9:** each Star marks exactly one attempt (the current one while reading, else the last one ended before it); replace `has_star_after`'s grace window (through review)
- [ ] Tests green: `test_attempt_per_resume`. New: star attribution with two short attempts
### Dependencies
Task 11 (event access only; may start earlier)

---

## Task 15: Take solver
**Files:** src/assembly/pt_take_solver.e
**Features:** solve
### Acceptance Criteria
- [ ] DP over (word, attempt); latest valid take; star wins; rejected/stale excluded; fewest splices; decisions logged; missing words reported
- [ ] **M10:** attempt switches only at passage starts or tight carets (postcondition through review)
- [ ] **M11:** `superseded_by_star` by passage overlap
- [ ] Tests green: `test_solver_exact_cover_after_cough`. New: starred older take wins; edited passage forces the newer take; missing passage reported
### Dependencies
Tasks 13, 14

---

## Task 16: Silence snapper
**Files:** src/assembly/pt_silence_snapper.e
**Features:** snap
### Acceptance Criteria
- [ ] Edges at gap midpoints, else head/tail pads and tight
- [ ] **M12:** spans clamped to [0, duration] (postcondition through review)
- [ ] Tests: new snapper test on the larry_read_01 VAD map
### Dependencies
Task 13

---

## Task 17: Attempt aligner
**Files:** src/assembly/pt_attempt_aligner.e
**Features:** align
### Acceptance Criteria
- [ ] Per attempt: heard words inside its span, forward matching from the journaled caret against its revision; finds the caret word inside a run-up
- [ ] **M23:** occurrence spans clipped to VAD speech (whisper word times absorb silences)
- [ ] Tests: new test with PT_SCRIPTED_TRANSCRIBER fed from `larry_read_01.words.tsv` and `.vad.tsv`
### Dependencies
Task 5

---

## Task 18: Flagger
**Files:** src/assembly/pt_flagger.e
**Features:** flag
### Acceptance Criteria
- [ ] Misread (not equivalent), low confidence, unmarked restart, tight splice, missing, long pause
- [ ] Equivalence-class matches never flagged as misreads (H7)
- [ ] Tests green: `test_flagger_flags_every_tight_cut`. New: on larry_read_01, the homophones are **not** flagged; "55070" **is** flagged
### Dependencies
Tasks 4, 15

---

## Task 19: Session analyzer
**Files:** src/assembly/pt_session_analyzer.e
**Features:** analyze
### Acceptance Criteria
- [ ] Orchestrates transcribe → build → align → solve → snap → flag; failure path; decision log lines
- [ ] L19: success-path test with a scripted transcriber (the current failure test stays)
### Dependencies
Tasks 14-18

---

## Task 20: Writers: captions, review.srt, chapters, EDL
**Files:** src/output/pt_caption_builder.e, pt_review_srt_writer.e, pt_chapter_writer.e, pt_edl_writer.e
### Acceptance Criteria
- [ ] Caption cues from final script words via the cut map (limits enforced); SRT/VTT text
- [ ] review.srt one cue per shown mark
- [ ] Chapters starting at 0:00
- [ ] CMX3600 events
- [ ] Tests green: `test_review_srt_one_cue_per_mark`, `test_edl_has_one_event_per_cut`. New: caption cue limits; chapters from `read_test_01.md` headings
### Dependencies
Tasks 13, 15

---

## Task 21: Cut and analysis codecs
**Files:** src/output/pt_cut_codec.e, pt_analysis_codec.e (+ simple_json)
### Acceptance Criteria
- [ ] Round trips
- [ ] Tests green: `test_cut_codec_round_trip`. New: analysis round trip, success and failure
### Dependencies
Task 19 (types only)

---

## Task 22: Render plan
**Files:** src/record/pt_render_plan.e
**Features:** filter_script, arguments
### Acceptance Criteria
- [ ] The spike graph (trim/atrim + setpts + afade 20 ms + concat; optional punch-in); NVENC args with `-filter_complex_script`
- [ ] Tests green: `test_render_plan_follows_the_spike_recipe`
- [ ] Manual (pasted): render the spike's synthetic source from a 3-cut plan; frames at the joints match (burned clock)
### Dependencies
Task 13

---

## Task 23: Settings persistence
**Files:** src/config/pt_settings.e (+ simple_toml)
### Acceptance Criteria
- [ ] TOML load with bounded fallbacks; save on set; keymap and camera anchors as tables
- [ ] L20: setters for count-in, pads, sessions root, devices
- [ ] Tests: save/load round trip through a temp file; out-of-range file values fall back to defaults
### Dependencies
None

---

## Task 24: Real-voice replay test (acceptance for Tracking)
**Files:** testing/test_real_voice.e (new), fixtures larry_read_01.words.tsv / .vad.tsv / read_test_01.md
### Acceptance Criteria
- [ ] Feed the recording's heard words (in 3 s windows, 250 ms steps) to PT_ALIGNER over the parsed `read_test_01.md`
- [ ] Position never more than one line behind or ahead of the spoken word outside the ad-lib
- [ ] Holds during the ad-lib; jumps over the skipped paragraph; picks the right "So when you" each time
- [ ] When this passes on the fixture and a live read (Track B), `PT_SETTINGS.mark_tracking_proven` becomes eligible (approved Q5)
### Dependencies
Tasks 2, 4, 5

---

## Dependency graph (Track A)

```
T1 ─► T2 ─► T3 ─────────────────────┐
 └──► T4 ─► T5 ─► T17                ├─► T10 ─► T12
             └──► T24                │
T9 ──────────────────────────────────┘
T6, T7, T8, T11, T23: independent
T13 ─► T15 ◄─ T14 (◄ T11) ─► T18 (◄ T4) ─► T19 (◄ T16, T17) ─► T21
T13 ─► T16;  T13 ─► T22;  T13 + T15 ─► T20
```

**Suggested order:**
1. T1, T6, T7, T8, T9, T11, T13, T23 (independent).
2. T2, T4.
3. T3, T5.
4. T10, T14.
5. T12, T15, T16, T17.
6. T18, T19, T20, T21, T22.
7. T24.

---

## Track B (not in `/eiffel.implement` scope; sequencing only)

| Item | What | Unblocks |
|------|------|----------|
| U-0a | simple_shell: SHELL_PANEL (+capture exclusion), SHELL_MONITORS, SHELL_HOTKEYS | Pill, S-2 |
| S-2 | Capture-exclusion spike vs OBS/Teams/Snipping/Game Bar | FR-003 |
| U-0b | simple_speech: SPEECH_DECODE_PARAMS, words, SPEECH_VAD, SPEECH_STREAM, CUDA variant | PT_SILERO_VAD, PT_WHISPER_DECODER |
| S-1 / T-0 | Live mic + dshow capture with `-audio_buffer_size 50`: tee latency and 30-min drift | NFR-001, recording clock bound |
| S-3 | SCOOP worker + slot at 16 ms (worker builds its pipeline on its own processor) | GUI frame time |
| U-0c | simple_text_structure (extract SR tokenizer + navigator) | Replace the T2 interim tokenizer |
| U-0d | simple_markdown.to_plain_text | Replace the T2/T12 local strip |
| U-0e | simple_ffmpeg dshow listing; simple_process write_input; simple_file append/flush (if T11 finds it missing) | Settings window, recorder stop, journal |
| App | app/, runtime/, speech/, worker/ clusters + their ECF targets | Usable product |
