# Phase 2: Claude Review Response
# STATUS: COMPLETE
# Date: 2026-10-05
# Model: Claude Opus 5.5 (adversarial self-review)
# Scope: src/ (84 classes), testing/ (11 classes, 78 tests)

Line numbers are from the files as compiled for phase1-compile.txt.

## HIGH

### ISSUE 1: Two index conventions for "where the reader is" (off by one)
- **LOCATION**: PT_TAKE_CONTROLLER.perform `resumes_at_caret` (pt_take_controller.e:176); `reader_position` (:102); PT_ALIGNER.position doc (pt_aligner.e:47-48); PT_FOLLOWER.target doc (pt_follower.e:15-16)
- **SEVERITY**: HIGH
- **DESCRIPTION**:
  - The caret is a 1-based word index: "restart AT word k". `resumes_at_caret` sets `follower.target = caret`.
  - `reader_position = floor (target) + 1`, so right after resuming at word k the controller believes the reader is on word k+1.
  - The aligner's `position` is "word the reader is on", while the follower's target behaves as "words passed".
  - Again, prompt text and the journal's flub word would all be off by one word.
- **SUGGESTION**:
  - One convention: follower target and aligner position both mean **words already read** (fractional for the follower). Caret k means `set_caret (k - 1)` and `reanchor (k - 1)`, and `reader_position = floor (target) + 1` is the next word to read.
  - Change `resumes_at_caret` to `follower.target = (caret - 1).to_double`.
  - Update both docs and the aligner contracts ("last word confirmed read").

### ISSUE 2: The scroll model cannot see caret changes; Again would scroll backward through the text
- **LOCATION**: PT_SCROLL_MODEL.tick `forward_unless_caret` (pt_scroll_model.e:72); `caret_changed := False` at the start of every `advance` (pt_constant_follower.e:59; pt_voice_gated_follower.e:77; pt_tracking_follower.e:82)
- **SEVERITY**: HIGH
- **DESCRIPTION**:
  - `tick` calls `follower.advance`, which clears `caret_changed` before `tick`'s postcondition reads it.
  - After a backward caret move, the spring glides toward the lower target, so `position` decreases. The postcondition then fails, and on screen the text visibly rewinds.
- **SUGGESTION**:
  - Drop the `caret_changed` dependency.
  - In `tick`: if `follower.target < position` (a caret moved back), call `jump_to (follower.target)`; otherwise step the spring.
  - Contract: `old follower.target < old position implies position = follower.target`; otherwise `position >= old position`.

### ISSUE 3: A decode result from before a restart can yank the position after it
- **LOCATION**: PT_ALIGNER.update / reanchor (pt_aligner.e)
- **SEVERITY**: HIGH
- **DESCRIPTION**:
  - After Again (flub at word 50, reanchor to 40), a window decoded before the restart can still be in flight: 250 ms step + ~60 ms decode + slot latency.
  - That window contains words 45-50, which are anchored matches, so the aligner jumps straight back to 50 and the follower races ahead of the reader.
  - Nothing in the contracts relates window time to the reanchor.
- **SUGGESTION**:
  - `reanchor (a_index; a_at_sample: INTEGER_64)` records `reanchored_at`.
  - `update` ensures `a_heard.window_start < reanchored_at implies position = old position` (stale windows are ignored).
  - The controller passes the recording-clock sample at Count_in_done.

### ISSUE 4: The facade does not rewire after a live edit
- **LOCATION**: SIMPLE_PROMPTER.load_script_text (simple_prompter.e:195 layout.build, :197 aligner); edits happen in PT_TAKE_CONTROLLER.commit_edit
- **SEVERITY**: HIGH
- **DESCRIPTION**:
  - The aligner and layout are built once, for revision 1. After `commit_edit` (revision 2), the aligner still matches against the old revision (wrong ids for edited words), and the layout's word count differs from the follower's.
  - `PT_SCROLL_MODEL.y_offset`'s precondition then fails, and alignment goes wrong.
- **SUGGESTION**:
  - The facade owns `commit_edit` and `perform (Skip)`: it calls the controller, then rebuilds the aligner and layout and rescales the follower.
  - Add a facade invariant (O(1)): `has_script implies (aligner.revision = history.current_revision and layout.word_count = history.current_revision.word_count and follower.word_count = layout.word_count)`.

### ISSUE 5: The keymap cannot express the decided controls
- **LOCATION**: PT_KEYMAP.bindings `HASH_TABLE [PT_KEY_BINDING, INTEGER]` keyed by action (pt_keymap.e:164); `bind` uses `force` by action (:128)
- **SEVERITY**: HIGH
- **DESCRIPTION**: Spec 07 §2.14 needs two things this structure can't hold:
  - **Several keys per action:** Hold = Ctrl+Alt+Space and clicker B and ".".
  - **State-dependent clicker meaning:** PageUp = Again while READING but Back while HELD.

  One binding per action, with no state, can hold neither.
- **SUGGESTION**:
  - Key the table by (modifiers, vkey) to a **logical control** (e.g. `Ctl_hold_toggle`, `Ctl_clicker_back`, `Ctl_clicker_forward`, plus the direct actions).
  - A new pure class **`PT_CONTROL_RESOLVER`** maps (logical control, take state) to a `PT_ACTION`, testable headless. PT_INPUT_ROUTER (app) only translates OS key events to controls.
  - Contracts: one control per key combo; bare keys only while recording.

### ISSUE 6: dshow audio buffer latency is unspecified
- **LOCATION**: PT_CAPTURE_PLAN.arguments (pt_capture_plan.e:67)
- **SEVERITY**: HIGH
- **DESCRIPTION**:
  - The plan does not set `-audio_buffer_size`. ffmpeg's dshow help says the default is "the device's default".
  - The device buffer adds directly to the tee latency. The voice-gated pause budget is ≤ 250 ms (NFR-001), with ~200 ms already in the ramp.
  - The default size on the FHD Camera microphone is unmeasured.
- **SUGGESTION**: Add `-audio_buffer_size 50` (ms) before `-i` in both plan variants, plus a postcondition. Measure the tee latency in spike T-0 with and without it.

## MEDIUM

### ISSUE 7: `old again_target` evaluated on every `perform`
- **LOCATION**: PT_TAKE_CONTROLLER.perform `again_caret` (pt_take_controller.e:174)
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: Every action (Hold, Go, Star…) evaluates the restart policy on entry. A policy bug breaks all actions, not just Again, and the policy work is wasted on every call.
- **SUGGESTION**: Compute the target inside `perform` for Again and store `last_again_target`. Postcondition: `a_action = Again implies (caret = last_again_target)`; the policy's own contract guarantees the value.

### ISSUE 8: Record/Play allowed with an empty script
- **LOCATION**: PT_TAKE_CONTROLLER.is_allowed / PT_TRANSITIONS
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: With 0 words, `caret = 0`. Count_in_done would build `make_resume` with a none caret, which violates its `real_caret` precondition in Phase 4.
- **SUGGESTION**: `is_allowed` is False for Play/Record when `revision.word_count = 0` (postcondition clause).

### ISSUE 9: Star can attach to two attempts
- **LOCATION**: PT_JOURNAL.has_star_after, Star_grace = 5.0 (pt_journal.e:92-102)
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: Two attempts that end within 5 s of a Star are both considered starred.
- **SUGGESTION**: A Star marks exactly one attempt: the current one while reading, else the most recent one that ended before it. PT_ATTEMPT_BUILDER contract: starred attempts ≤ Star events, and each Star maps to one attempt. Drop the grace window.

### ISSUE 10: The solver doesn't constrain where attempts switch
- **LOCATION**: PT_TAKE_SOLVER.solve postconditions
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: The design switches attempts only at passage boundaries (or tight carets), but no clause says so. A mid-sentence splice between two reads would satisfy the contract.
- **SUGGESTION**: Add `across 2 |..| last_result.count as i all last_result.cut (i).attempt /= last_result.cut (i - 1).attempt implies (is_passage_start (cut (i).first_word_index) or cut (i).is_tight) end`.

### ISSUE 11: `superseded_by_star` checks only the first word
- **LOCATION**: PT_TAKE_SOLVER.superseded_by_star (pt_take_solver.e:96-104)
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: A starred attempt that covers the rest of the passage but not its first word isn't detected.
- **SUGGESTION**: Test passage overlap (any word of the cut's passage covered by a starred attempt).

### ISSUE 12: Snapped spans can leave the speech map
- **LOCATION**: PT_SILENCE_SNAPPER.snap `in_silence_or_tight` (pt_silence_snapper.e:47)
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: Padding the last cut by `tail_pad` can push `t1` past `a_map.duration`. The postcondition then calls `is_silent_at` outside its precondition.
- **SUGGESTION**: Add the postcondition `within_recording: across … all last_result.cut (i).span.t1 <= a_map.duration end`, and clamp in the body.

### ISSUE 13: The pipeline's speech gating is not contracted
- **LOCATION**: PT_SPEECH_PIPELINE.push
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: The postconditions bound the decode count but never require that decodes happen only during speech (plus hangover). Decoding silence wastes GPU and invites hallucinations (RISK-002).
- **SUGGESTION**: Track `frames_since_speech`. Contract: `not is_in_speech implies pending_heard_count = old pending_heard_count`, and `is_in_speech = (frames_since_speech <= Hangover_frames)`.

### ISSUE 14: Skip creates a revision but `perform` doesn't say so
- **LOCATION**: PT_TAKE_CONTROLLER.perform (Skip)
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: Skip is an edit (a strike), but there is no postcondition on the revision count or the follower rescale. It also needs the facade rewiring from ISSUE 4.
- **SUGGESTION**: `a_action = Skip implies history.revision_count = old history.revision_count + 1`; route Skip through the facade.

### ISSUE 15: Duplicate key combos allowed
- **LOCATION**: PT_KEYMAP.bind
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: Two actions on the same keys make `action_for` pick whichever binding it reaches first.
- **SUGGESTION**: Covered by the ISSUE 5 redesign (table keyed by combo). Meanwhile add a precondition: the combo is not bound to another action.

### ISSUE 16: Reloading a script during a recording orphans the session
- **LOCATION**: SIMPLE_PROMPTER.load_script_text
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: There is no guard, so a reload creates a new controller and journal mid-recording.
- **SUGGESTION**: `require not_recording: not has_script or else not controller.is_recording`.

## LOW

### ISSUE 17: `lines_written` counts in-memory appends
- **LOCATION**: PT_JOURNAL.append `persisted` (pt_journal.e:141, :145)
- **SEVERITY**: LOW
- **DESCRIPTION**: The name and comment say "persisted", but the counter also grows when nothing is written.
- **SUGGESTION**: Rename it `appended_count`, or contract `persisted: is_persistent implies lines_written = old lines_written + 1`.

### ISSUE 18: `normalized_not_longer` fails for Unicode case expansion
- **LOCATION**: PT_WORD invariant (pt_word.e:73) and creation precondition (:22)
- **SEVERITY**: LOW
- **DESCRIPTION**: Some lowercase mappings expand a character (e.g. "İ" → "i̇"). English scripts are fine today.
- **SUGGESTION**: Drop the clause, or document English-only normalization.

### ISSUE 19: Vacuous tests
- **LOCATION**: TEST_FOLLOWERS.test_voice_gated_stops_within_250_ms; TEST_ASSEMBLY.test_analyzer_reports_transcriber_failure
- **SEVERITY**: LOW
- **DESCRIPTION**: Both pass against the stubs: the follower never moves, and the analyzer always fails.
- **SUGGESTION**: First assert the follower moved (velocity > 0) before silence. Add a success-path analyzer test with a scripted transcriber.

### ISSUE 20: Settings API incomplete
- **LOCATION**: PT_SETTINGS
- **SEVERITY**: LOW
- **DESCRIPTION**: There are no setters for count-in, pads, the sessions root, or camera/microphone names, although the invariants constrain them.
- **SUGGESTION**: Add bounded setters in Phase 4.

### ISSUE 21: Pipeline pending lists have no MML models
- **LOCATION**: PT_SPEECH_PIPELINE
- **SEVERITY**: LOW
- **DESCRIPTION**: Frame conditions are stated by counts only.
- **SUGGESTION**: Add `pending_frames_model: MML_SEQUENCE [PT_VOICE_FRAME]` and state "earlier frames unchanged" with `front`.

## INFO

### NOTE A: Edit postconditions are safe at script edges
`MML_SEQUENCE.front`/`tail` delegate to `interval`, which clamps both bounds and has no precondition (mml_sequence.e). So `front (0)` and `tail (count + 1)` are empty sequences, and `apply_edit`'s prefix/suffix clauses hold at word 1 and at the last word.

### NOTE B: Invariants checked O(1)
Every invariant in src/ compares scalars, counts or references; no models or loops (oracle rule).

### NOTE C: SCOOP traitor rule recorded
The speech worker must create its PT_SPEECH_PIPELINE (with VAD/decoder) on its own processor (spec 10 addendum).

## ADDENDUM: findings from Larry's real recording (larry_read_01, evidence/real-voice-larry_read_01.md)

### ISSUE 22: Matcher and normalizer have no equivalence classes (HIGH)
- **LOCATION**: PT_WORD_MATCHER.matches / PT_NORMALIZER.normalized (contracts allow only exact, stem variant, bounded Levenshtein)
- **SEVERITY**: HIGH
- **DESCRIPTION**:
  - Raw accuracy on real speech was 91.7%.
  - The misses are systematic: homophones (their/they're -> there, to/too -> two, whole -> hole, so -> sew), spoken abbreviations (e.g. -> "for example", Ms. -> Mrs.), number words vs digits (one -> 1, twenty twenty-six -> 26), compound split/join (postcondition -> post condition, c p p -> CPP), and phonetics (Silero -> Celero, distance 2 on 6 letters, rejected).
  - Without these, about 8% of words never anchor, and the flagger raises ~14 false misreads in 3 minutes.
- **SUGGESTION**:
  - New pure class **PT_EQUIVALENCES**: homophone sets, abbreviation table (written -> spoken forms), number words <-> digits, phonetic key (Metaphone-style).
  - Matcher contract: `equivalent (heard, script) implies matches`.
  - Aligner: allow a multi-word span to match one script word ("for example" ~ "e.g.") and a joined token to match several ("cpp" ~ "c p p").
  - Flagger: equivalence-class matches are never misreads.

### ISSUE 23: Whisper word timestamps absorb silences (MEDIUM)
- **LOCATION**: PT_ATTEMPT_ALIGNER / PT_SESSION_ANALYZER (word spans from the transcriber)
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: The 3.68 s instructed pause (VAD 19.17-22.85) is invisible in whisper's word times: it is folded into a word's duration. Cut placement from word times would land inside silence that whisper claims is speech, or clip words.
- **SUGGESTION**:
  - Contract that occurrence spans are clipped to VAD speech (each occurrence span lies within a speech-map span, ±pad).
  - Snapper uses the map (already so).
  - Evaluate whisper DTW token timestamps (`-dtw large.v3.turbo`) in T-3.

### ISSUE 24: Spoken headings (MEDIUM)
- **LOCATION**: PT_SCRIPT_PARSER (sections), PT_SCRIPT_REVISION.spoken_ids_model, PT_TAKE_SOLVER exact cover
- **SEVERITY**: MEDIUM
- **DESCRIPTION**: Larry read both headings aloud. If heading words are required, cover fails when they're skipped; if they're unmatchable, reading them looks like an ad-lib.
- **SUGGESTION**:
  - Heading words get `is_optional`: matchable by the aligner, but excluded from `spoken_ids_model` (required cover).
  - The solver may include them when heard.

### ISSUE 25: Silero classifies a cough as speech (LOW)
- **LOCATION**: PT_SPEECH_PIPELINE / PT_VOICE_GATED_FOLLOWER
- **SEVERITY**: LOW
- **DESCRIPTION**: A 1.2 s cough was VAD speech, so voice-gated mode creeps about 2 words during a cough. In tracking mode whisper emits `*cough*`.
- **SUGGESTION**:
  - Voice-gated: accept, and document.
  - Tracking: the decoder strips bracketed or starred non-speech annotations (`*cough*`, `[laughs]`) before alignment (PT_DECODER postcondition: no heard word starts with '*' or '[').
