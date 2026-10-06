# CONTRACT DESIGN: simple_prompter

Date: 2026-10-05

## Ground rules (house rules, as in simple_taskman 05)

1. **Invariants are O(1)** (C-009, oracle rule 2026-09-11): scalars and counts only. Quantification
   over a collection is a postcondition, usually via an MML model query.
2. **Every feature named in a precondition is exported** to every client of the routine.
3. **Tests assert through TEST_SET_BASE**, never `check` (finalized `check` is vacuous).
4. **Contracts never call externals** (clocks, files, whisper). Time enters as an argument.
5. **MML element equality is by value** (`model_equals`); `PT_WORD_ID` is expanded with value equality.
6. **Model queries are for contracts and tests only**, never implementation logic.
7. **Constants are classified by range**: `a_kind >= {PT_EVENT_KIND}.Session_start and a_kind <= {PT_EVENT_KIND}.Abort`.
8. **`|=|` binds tighter than `and`/`&`**: always parenthesize model equalities (oracle error log 2026-10-05, VWOE in TM_WINDOW).
9. **Floating-point** postconditions compare within `Epsilon` (1.0e-9 for exact arithmetic, 1.0e-3 s for times).
10. Fields named in an `old` expression are evaluated on entry; models used under `old` are built once per call.

11. **MML models are not ITERABLE** (`MML_SEQUENCE` inherits only `MML_MODEL`, mml_sequence.e:14-21).
    Quantify with `across 1 |..| n as i all … item (i) … end` over the class's own index queries, or
    with the model's `for_all`/`exists` agents. `across list as ic` (a base list) binds `ic` to the item
    (ES 25.02 semantics, as in simple_taskman tm_frame.e:31).

Notation: `MML_SEQUENCE` operations used: `#` count, `[]` item, `&` extended, `+` concatenation,
`front (n)`, `tail (n)`, `interval (a, b)`, `|=|`, `range`, `first`, `last` (simple_mml/src/mml_sequence.e).

## MML Model Queries

| Class | Attribute | Type | Model Query | MML Type |
|-------|-----------|------|-------------|----------|
| `PT_SCRIPT_REVISION` | `word_list` | `ARRAYED_LIST [PT_WORD]` | `ids_model` | `MML_SEQUENCE [PT_WORD_ID]` |
| `PT_SCRIPT_REVISION` | `word_list` | | `spoken_ids_model` (non-cue) | `MML_SEQUENCE [PT_WORD_ID]` |
| `PT_SCRIPT_REVISION` | `passage_list` | `ARRAYED_LIST [PT_PASSAGE]` | `passage_bounds_model` | `MML_SEQUENCE [INTEGER]` (first indexes) |
| `PT_SCRIPT_HISTORY` | `revision_list` | `ARRAYED_LIST [PT_SCRIPT_REVISION]` | `revisions_model` | `MML_SEQUENCE [PT_SCRIPT_REVISION]` |
| `PT_JOURNAL` | `event_list` | `ARRAYED_LIST [PT_TAKE_EVENT]` | `events_model` | `MML_SEQUENCE [PT_TAKE_EVENT]` |
| `PT_SPEECH_MAP` | `span_list` | `ARRAYED_LIST [PT_TIME_SPAN]` | `spans_model` | `MML_SEQUENCE [PT_TIME_SPAN]` |
| `PT_WORD_TIMELINE` | `occurrence_list` | `ARRAYED_LIST [PT_WORD_OCCURRENCE]` | `occurrences_model` | `MML_SEQUENCE [PT_WORD_OCCURRENCE]` |
| `PT_CUT_LIST` | `cut_list` | `ARRAYED_LIST [PT_CUT]` | `cuts_model`, `words_model` (ids in output order) | `MML_SEQUENCE [PT_CUT]`, `MML_SEQUENCE [PT_WORD_ID]` |
| `PT_LAYOUT` | `line_list` | `ARRAYED_LIST [PT_LINE]` | `line_starts_model` | `MML_SEQUENCE [INTEGER]` |
| `PT_KEYMAP` | `bindings` | `HASH_TABLE [PT_KEY_BINDING, INTEGER]` (by action) | `actions_model` | `MML_SET [INTEGER]` |
| `PT_SPEECH_SLOT` | `records` | `ARRAYED_QUEUE [STRING_8]` | `records_model` | `MML_SEQUENCE [STRING_8]` |

## Class Contracts: script

### PT_WORD_ID (expanded)
```eiffel
make (a_value: INTEGER_64)
    require positive: a_value > 0
    ensure set: value = a_value
invariant
    -- default value 0 means "no word"; constructed ids are > 0
    non_negative: value >= 0
```

### PT_SCRIPT_REVISION (immutable)
```eiffel
word (a_index: INTEGER): PT_WORD
    require valid_index: a_index >= 1 and a_index <= word_count
index_of (a_id: PT_WORD_ID): INTEGER
    ensure
        zero_or_found: Result = 0 or else word (Result).id ~ a_id
        found_if_present: ids_model.has (a_id) implies Result > 0
passage_of (a_index: INTEGER): INTEGER
    require valid_index: a_index >= 1 and a_index <= word_count
    ensure
        contains: passage (Result).first_word <= a_index and a_index <= passage (Result).last_word
invariant
    number_positive: number >= 1
    passages_fit: passage_count <= word_count
    sections_fit: section_count <= passage_count
    empty_consistent: word_count = 0 implies passage_count = 0
```

### PT_SCRIPT_PARSER
```eiffel
parse (a_text: READABLE_STRING_GENERAL; a_number: INTEGER; a_ids: PT_ID_SOURCE): PT_SCRIPT_REVISION
    require
        number_positive: a_number >= 1
    ensure
        numbered: Result.number = a_number
        ids_unique: Result.ids_model.range.count = Result.word_count            -- DR-001
        ids_fresh: across 1 |..| Result.word_count as i all Result.word (i).id.value > old a_ids.last_issued end
        passages_partition: Result.word_count > 0 implies
            (Result.passage (1).first_word = 1 and Result.passage (Result.passage_count).last_word = Result.word_count)
        passages_contiguous: across 2 |..| Result.passage_count as i all
            Result.passage (i).first_word = Result.passage (i - 1).last_word + 1 end   -- DR-004
        cues_not_spoken: across 1 |..| Result.word_count as i all
            Result.word (i).is_cue implies not Result.spoken_ids_model.has (Result.word (i).id) end
```

### PT_SCRIPT_HISTORY
```eiffel
start (a_first: PT_SCRIPT_REVISION)
    require
        empty: revision_count = 0
        first_numbered: a_first.number = 1
    ensure
        one: revision_count = 1
        current_is_first: current_revision = a_first

apply_edit (a_first, a_last: INTEGER; a_new_text: READABLE_STRING_GENERAL)
        -- Replace words a_first..a_last of the current revision (a_first = a_last + 1 inserts;
        -- empty text deletes = strike).
    require
        has_revision: revision_count >= 1
        range_low: a_first >= 1
        range_high: a_last <= current_revision.word_count
        range_ordered: a_first <= a_last + 1
    ensure
        one_more: revision_count = old revision_count + 1
        numbered: current_revision.number = old current_revision.number + 1
        history_kept: (revisions_model.front (old revision_count) |=| old revisions_model)     -- DR-002
        prefix_ids_kept: (current_revision.ids_model.front (a_first - 1)
                          |=| (old current_revision.ids_model).front (a_first - 1))          -- DR-003
        suffix_ids_kept: (current_revision.ids_model.tail (current_revision.word_count - (old current_revision.word_count - a_last) + 1)
                          |=| (old current_revision.ids_model).tail (a_last + 1))           -- DR-003
        ids_unique: current_revision.ids_model.range.count = current_revision.word_count

revision (a_number: INTEGER): PT_SCRIPT_REVISION
    require valid: a_number >= 1 and a_number <= revision_count
    ensure numbered: Result.number = a_number
invariant
    current_consistent: revision_count >= 1 implies current_revision.number = revision_count
```

## Class Contracts: follow

### PT_CLOCK (deferred) and descendants
```eiffel
now_ms: REAL_64
    deferred
    ensure non_negative: Result >= 0
-- Monotonicity is a property of successive calls; it is tested (fake + QPC), not expressible as a single-call contract.
```
`PT_FAKE_CLOCK.advance (a_ms)` `require a_ms >= 0` `ensure now_ms = old now_ms + a_ms`.

### PT_WORD_MATCHER
```eiffel
distance (a, b: READABLE_STRING_32): INTEGER       -- bounded Levenshtein (stops at Max_distance + 1)
    ensure
        non_negative: Result >= 0
        zero_iff_equal: (Result = 0) = a.same_string (b)
        bounded: Result <= Max_distance + 1
matches (a_heard: READABLE_STRING_32; a_script: PT_WORD): BOOLEAN
    ensure
        exact_matches: a_heard.same_string (a_script.normalized) implies Result
        cue_never: a_script.is_cue implies not Result
        tolerance: Result implies (distance (a_heard, a_script.normalized) <= allowed_distance (a_script.normalized.count)
                                   or is_stem_variant (a_heard, a_script.normalized))
allowed_distance (a_length: INTEGER): INTEGER
    ensure short_strict: a_length <= 4 implies Result = 0
           medium: (a_length >= 5 and a_length <= 7) implies Result = 1
           long: a_length >= 8 implies Result = 2
```

### PT_ALIGNER
```eiffel
make (a_revision: PT_SCRIPT_REVISION; a_matcher: PT_WORD_MATCHER)
    ensure at_start: position = 0; certain: confidence = 1.0; revision_set: revision = a_revision

update (a_heard: PT_HEARD_WORDS)
    ensure
        within_script: position >= 0 and position <= revision.word_count
        window_bound: position <= old position + Window_ahead                                    -- bounded look-ahead
        forward_bias: position < old position implies last_alignment.anchor_count >= Backward_evidence   -- DR-016
        stop_words_inert: last_alignment.anchor_count = 0 implies position = old position          -- DR-017
        jump_evidence: (position - old position) > Small_jump implies
                       last_alignment.anchor_count >= required_anchors (position - old position)
        confidence_range: confidence >= 0.0 and confidence <= 1.0
        alignment_consistent: last_alignment.word_index = position

reanchor (a_index: INTEGER)
    require valid: a_index >= 0 and a_index <= revision.word_count
    ensure placed: position = a_index; certain: confidence = 1.0

required_anchors (a_jump: INTEGER): INTEGER
    require positive: a_jump > 0
    ensure monotone_tiers: Result >= 1 and Result <= 3
           small: a_jump <= Small_jump implies Result = 1
invariant
    position_range: position >= 0 and position <= revision.word_count
    confidence_range: confidence >= 0.0 and confidence <= 1.0
    constants_sane: Window_back >= 0 and Window_ahead >= 1 and Backward_evidence >= 2
```
`anchor_count` = matched non-stop words in the scored recent-heard sequence (LCS over the last `Recent_heard` heard words against the window).

### PT_FOLLOWER (deferred) — every descendant inherits these
```eiffel
advance (a_dt_s: REAL_64)
    require non_negative: a_dt_s >= 0
    ensure
        held_frozen: is_held implies target = old target
        never_backward: target >= old target                                    -- DR-015 (caret changes are separate commands)
        end_clamped: target <= word_count
        velocity_non_negative: velocity >= 0
on_voice (a_frame: PT_VOICE_FRAME)
    ensure position_untouched: target = old target       -- inputs change velocity/intent only; motion happens in advance
on_alignment (a_alignment: PT_ALIGNMENT)
    ensure position_untouched: target = old target
hold
    ensure held: is_held; stopped: velocity = 0; target_kept: target = old target
release
    ensure running: not is_held
set_caret (a_index: INTEGER)                       -- the ONLY way to move backward
    require valid: a_index >= 0 and a_index <= word_count
    ensure placed: target = a_index.to_double; flagged: caret_changed
invariant
    velocity_non_negative: velocity >= 0
    held_still: is_held implies velocity = 0
    target_range: target >= 0 and target <= word_count
```
`PT_CONSTANT_FOLLOWER.advance`:
```eiffel
ensure then
    constant_rate: (not is_held and old target + words_per_second * a_dt_s <= word_count)
                   implies (target - (old target + words_per_second * a_dt_s)).abs < Epsilon
```
`PT_VOICE_GATED_FOLLOWER.advance`:
```eiffel
ensure then
    silent_stops: (not is_speaking and ramp_finished) implies velocity = 0
    speed_capped: velocity <= words_per_second
```
`PT_TRACKING_FOLLOWER.advance`:
```eiffel
ensure then
    coast_limited: seconds_since_anchor > Coast_limit implies velocity = 0
    rate_capped: velocity <= Max_rate_factor * measured_rate.max (Min_rate)
```

### PT_LAYOUT
```eiffel
build (a_revision: PT_SCRIPT_REVISION; a_measure: PT_TEXT_MEASURE; a_width: REAL_64)
    require positive_width: a_width > 0
    ensure
        covers: a_revision.word_count > 0 implies
            (line (1).first_word = 1 and line (line_count).last_word = a_revision.word_count)
        contiguous: across 2 |..| line_count as i all line (i).first_word = line (i - 1).last_word + 1 end
        fits_or_single: across 1 |..| line_count as i all
            line (i).width <= a_width or line (i).first_word = line (i).last_word end
line_of (a_word: INTEGER): INTEGER
    require valid: a_word >= 1 and a_word <= word_count
    ensure contains: line (Result).first_word <= a_word and a_word <= line (Result).last_word
y_of (a_position: REAL_64): REAL_64
    require in_range: a_position >= 0 and a_position <= word_count
    ensure non_negative: Result >= 0
-- monotonicity of y_of in a_position is a tested property (sampled), not a single-call contract
```

## Class Contracts: take

### PT_TAKE_EVENT
```eiffel
make_flub (a_rt: REAL_64; a_word: PT_WORD_ID)
    require rt_ok: a_rt >= 0
    ensure kind_set: kind = {PT_EVENT_KIND}.Flub; rt_set: rt = a_rt; word_set: word ~ a_word
make_edit (a_rt: REAL_64; a_from_rev: INTEGER; a_first, a_last: PT_WORD_ID; a_old, a_new: READABLE_STRING_GENERAL)
    require rt_ok: a_rt >= 0; rev_ok: a_from_rev >= 1
    ensure kind_set: kind = {PT_EVENT_KIND}.Edit; next_rev: to_rev = a_from_rev + 1
-- … one creator per kind (session_start, resume, hold, flub, rewind_to, count_in, edit, star, reject, note, align, wrap, abort)
invariant
    kind_known: kind >= {PT_EVENT_KIND}.Session_start and kind <= {PT_EVENT_KIND}.Abort
    rt_non_negative: rt >= 0
    edit_complete: kind = {PT_EVENT_KIND}.Edit implies
        (attached old_text and attached new_text and to_rev = from_rev + 1)
    resume_has_caret: kind = {PT_EVENT_KIND}.Resume implies caret.value > 0
```

### PT_JOURNAL
```eiffel
append (a_event: PT_TAKE_EVENT)
    require
        rt_ordered: a_event.rt >= last_rt                                   -- DR-005
        open: is_open
    ensure
        appended: (events_model |=| (old events_model & a_event))           -- DR-006
        last_updated: last_rt = a_event.rt
        persisted: lines_written = old lines_written + 1                    -- one flushed JSONL line per event
replay_from (a_lines: ITERABLE [READABLE_STRING_8])
    require empty: count = 0
    ensure
        ordered: across 2 |..| count as i all event (i).rt >= event (i - 1).rt end
        skipped_reported: skipped_lines >= 0                                -- a torn last line after a crash is skipped, not fatal
invariant
    last_rt_non_negative: last_rt >= 0
    empty_zero: count = 0 implies last_rt = 0
```
No `remove`, `put`, or `wipe_out` features exist (append-only by construction).

### PT_RECORDING_CLOCK
```eiffel
Bytes_per_second: INTEGER = 64_000          -- 16 kHz × 4 bytes (f32 mono)
observe_bytes (a_total: INTEGER_64; a_at_ms: REAL_64)
    require monotone: a_total >= byte_count; time_ok: a_at_ms >= observed_at_ms
    ensure counted: byte_count = a_total; rt_exact: (rt - a_total / Bytes_per_second).abs < Epsilon
rt_at (a_now_ms: REAL_64): REAL_64          -- interpolated between observations
    require after: a_now_ms >= observed_at_ms
    ensure
        not_before: Result >= rt
        bounded: Result <= rt + Max_interpolation_s
invariant
    rt_non_negative: rt >= 0
    bytes_non_negative: byte_count >= 0
```

### PT_TRANSITIONS (single choice for the state machine)
```eiffel
is_allowed (a_state, a_action: INTEGER; a_recording: BOOLEAN): BOOLEAN
    require state_known: …range…; action_known: …range…
    ensure recording_only / practice_only: see 07 §2.6
next_state (a_state, a_action: INTEGER): INTEGER
    require listed: table_entry (a_state, a_action) /= 0
    ensure known: Result >= {PT_TAKE_STATE}.Idle and Result <= {PT_TAKE_STATE}.Wrapped
```
Table (excerpt, superseded by the full table in 07 §2.6, which adds Stop, Abort, Skip, Analysis_done and recording/practice rules):
| From \ Action | record / play | again | hold | go | back/fwd/pick_word | edit_open | edit_commit/cancel | star/reject/note | wrap | count_in_done |
|---|---|---|---|---|---|---|---|---|---|---|
| idle | count_in (play: no journal) | – | – | – | – | – | – | – | – | – |
| count_in | – | count_in | held | – | – | – | – | – | analyzing | reading |
| reading | – | count_in | held | – | – | – | – | reading | analyzing | – |
| held | – | count_in | – | count_in | held | editing | – | held | analyzing | – |
| editing | – | – | – | – | – | – | held | – | – | – |
| analyzing / wrapped | – | – | – | – | – | – | – | – | – | – |

### PT_TAKE_CONTROLLER
```eiffel
perform (a_action: INTEGER)
    require
        known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
        no_argument: not needs_argument (a_action)
        allowed: is_allowed (a_action)                                            -- DR-008
    ensure
        transitioned: state = transitions.next_state (old state, a_action)
        journal_monotone: journal.count >= old journal.count
        again_caret: a_action = {PT_ACTION}.Again implies caret = old again_target
        go_resumes_at_caret: a_action = {PT_ACTION}.Count_in_done implies follower_caret = caret
        browse_not_journaled: (a_action = {PT_ACTION}.Back or a_action = {PT_ACTION}.Forward)
                              implies journal.count = old journal.count

pick_word (a_index: INTEGER)
    require held: state = {PT_TAKE_STATE}.Held; valid: a_index >= 1 and a_index <= revision.word_count
    ensure placed: caret = a_index; not_journaled: journal.count = old journal.count

commit_edit (a_new_text: READABLE_STRING_GENERAL)
    require editing: state = {PT_TAKE_STATE}.Editing
    ensure
        new_revision: history.revision_count = old history.revision_count + 1
        back_to_held: state = {PT_TAKE_STATE}.Held
        caret_at_edit: caret = revision.passage (revision.passage_of (old edit_first.max (1).min (revision.word_count))).first_word
        journaled: journal.last_event.kind = {PT_EVENT_KIND}.Edit

again_target: INTEGER          -- query: default caret for Again (PT_RESTART_POLICY)
    ensure valid: Result >= 1 and Result <= revision.word_count
invariant
    state_known: state >= {PT_TAKE_STATE}.Idle and state <= {PT_TAKE_STATE}.Wrapped
    caret_valid: revision.word_count > 0 implies (caret >= 1 and caret <= revision.word_count)
    revision_current: revision = history.current_revision
```

### PT_RESTART_POLICY
```eiffel
again_caret (a_revision: PT_SCRIPT_REVISION; a_position: INTEGER; a_confident: BOOLEAN; a_last_confident: INTEGER): INTEGER
    require valid: a_position >= 1 and a_position <= a_revision.word_count
    ensure
        at_passage_start: Result = a_revision.passage (a_revision.passage_of (Result)).first_word
        not_after: Result <= a_position
        previous_if_early: (a_confident and a_position - passage_start (a_revision, a_position) < Early_words
                            and a_revision.passage_of (a_position) > 1)
                           implies a_revision.passage_of (Result) = a_revision.passage_of (a_position) - 1
step_back (a_revision: PT_SCRIPT_REVISION; a_caret, a_unit: INTEGER): INTEGER
    ensure not_after: Result <= a_caret; at_unit_start: …
```

## Class Contracts: assembly

### PT_SPEECH_MAP
```eiffel
make_from_spans (a_spans: ITERABLE [PT_TIME_SPAN]; a_duration: REAL_64)
    require ordered_disjoint: -- checked by caller via is_ordered_disjoint (a_spans)
    ensure duration_set: duration = a_duration
is_silent_at (a_t: REAL_64): BOOLEAN
    require in_range: a_t >= 0 and a_t <= duration
    ensure definition: Result = not across 1 |..| span_count as i some span (i).contains (a_t) end
silence_around (a_t: REAL_64): detachable PT_TIME_SPAN
    ensure inside: attached Result implies (Result.contains (a_t) and is_silent_at ((Result.t0 + Result.t1) / 2))
invariant
    duration_non_negative: duration >= 0
```

### PT_ATTEMPT_BUILDER
```eiffel
build (a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY; a_end_rt: REAL_64): ARRAYED_LIST [PT_ATTEMPT]
    require ended: a_end_rt >= a_journal.last_rt
    ensure
        ordered_disjoint: across 2 |..| Result.count as i all Result [i - 1].span.t1 <= Result [i].span.t0 end   -- DR-009
        one_per_resume: Result.count = a_journal.count_of ({PT_EVENT_KIND}.Resume)
        within: across Result as ic all ic.span.t1 <= a_end_rt end
        starred_from_journal: across Result as ic all ic.is_starred = a_journal.has_star_after (ic.span.t0, ic.span.t1) end
```

### PT_TAKE_SOLVER
```eiffel
solve (a_final: PT_SCRIPT_REVISION; a_attempts: LIST [PT_ATTEMPT]; a_timeline: PT_WORD_TIMELINE;
       a_map: PT_SPEECH_MAP): PT_CUT_LIST
    ensure
        exact_cover_in_order: is_complete implies (Result.words_model |=| a_final.spoken_ids_model)      -- DR-010
        missing_reported: not is_complete implies (missing_words.count > 0)
        no_rejected: across 1 |..| Result.count as i all not a_attempts [Result.cut (i).attempt].is_rejected end -- DR-011
        no_stale: across 1 |..| Result.count as i all is_current_take (Result.cut (i), a_final, a_attempts) end  -- DR-013
        star_wins: across 1 |..| Result.count as i all not superseded_by_star (Result.cut (i), a_attempts) end
        output_ordered: across 2 |..| Result.count as i all Result.cut (i).first_word_index > Result.cut (i - 1).last_word_index end
```
`exact_cover_in_order` is one model equality expressing "every spoken word exactly once, in script order".

### PT_SILENCE_SNAPPER
```eiffel
snap (a_cuts: PT_CUT_LIST; a_map: PT_SPEECH_MAP; a_timeline: PT_WORD_TIMELINE): PT_CUT_LIST
    ensure
        same_count: Result.count = a_cuts.count
        same_words: (Result.words_model |=| a_cuts.words_model)
        in_silence_or_tight: across 1 |..| Result.count as i all
            Result.cut (i).is_tight or (a_map.is_silent_at (Result.cut (i).span.t0) and a_map.is_silent_at (Result.cut (i).span.t1)) end
        words_not_clipped: across 1 |..| Result.count as i all
            Result.cut (i).span.t0 <= a_timeline.start_of (Result.cut (i).first_word) and Result.cut (i).span.t1 >= a_timeline.end_of (Result.cut (i).last_word) end
```

### PT_CUT_LIST
```eiffel
output_duration: REAL_64
    ensure sum: (Result - span_total (cuts_model)).abs < Epsilon
        -- span_total: model-level helper (loop over the sequence); Eiffel has no `across … sum` form
to_output_time (a_src: INTEGER; a_rt: REAL_64): REAL_64
    require kept: is_kept (a_src, a_rt)
    ensure in_range: Result >= 0 and Result <= output_duration
floor_spans (a_src: INTEGER; a_raw_duration: REAL_64): ARRAYED_LIST [PT_TIME_SPAN]
    ensure complement: ((output_duration_of (a_src) + total (Result)) - a_raw_duration).abs < Epsilon_time  -- DR-012
invariant
    count_non_negative: count >= 0
```

## Class Contracts: output

### PT_TIMECODE
```eiffel
srt (a_seconds: REAL_64): STRING_8       -- HH:MM:SS,mmm
    require non_negative: a_seconds >= 0
    ensure shape: Result.count = 12 and Result [9] = ','
           round_trip: (seconds_of_srt (Result) - a_seconds).abs <= 0.0005
```

### PT_CAPTION_BUILDER
```eiffel
build (a_final: PT_SCRIPT_REVISION; a_cuts: PT_CUT_LIST; a_timeline: PT_WORD_TIMELINE): ARRAYED_LIST [PT_CAPTION_CUE]
    ensure
        ordered_non_overlapping: across 2 |..| Result.count as i all Result [i].t0 >= Result [i - 1].t1 end
        text_is_final_script: (concatenated_ids (Result) |=| a_cuts.words_model)
        within_output: across Result as ic all ic.t1 <= a_cuts.output_duration + Epsilon_time end
        cue_length: across Result as ic all ic.text.count <= Max_cue_chars and ic.t1 - ic.t0 <= Max_cue_seconds end
```

### PT_EDL_WRITER
```eiffel
write (a_cuts: PT_CUT_LIST; a_fps: INTEGER; a_reel: READABLE_STRING_8): STRING_8
    require fps_ok: a_fps > 0
    ensure one_event_per_cut: event_lines (Result) = a_cuts.count
           header: Result.starts_with ("TITLE:")
```

## Class Contracts: record and config

### PT_CAPTURE_PLAN
```eiffel
arguments: ARRAYED_LIST [STRING_32]
    require complete: has_devices and has_output_paths
    ensure
        dshow_input: has_pair (Result, "-f", "dshow")
        mjpeg_requested: has_pair (Result, "-vcodec", "mjpeg")          -- FHD Camera: YUYV 1080p is 5 fps
        mkv_out: Result.last_index_of_path (raw_path) > 0
        tee_flushed: has_pair (Result, "-flush_packets", "1")
        tee_format: has_pair (Result, "-f", "f32le") and has_pair (Result, "-ar", "16000") and has_pair (Result, "-ac", "1")
        pcm_audio: has_pair (Result, "-c:a", "pcm_s16le")                -- no encoder delay (spike)
```

### PT_RENDER_PLAN
```eiffel
filter_script (a_cuts: PT_CUT_LIST): STRING_8
    require non_empty: a_cuts.count >= 1
    ensure
        trims: occurrences (Result, "trim=") = a_cuts.count and occurrences (Result, "atrim=") = a_cuts.count
        one_concat: occurrences (Result, "concat=n=" + a_cuts.count.out) = 1
        fades_at_joints: occurrences (Result, "afade=") = 2 * a_cuts.count - 2
```

### PT_KEYMAP
```eiffel
bind (a_binding: PT_KEY_BINDING)
    require interlock: a_binding.modifiers /= 0 or a_binding.is_bare_while_recording   -- modifier-less hotkey gotcha
    ensure bound: binding_for (a_binding.action) = a_binding
           others_kept: (actions_model / a_binding.action) |=| (old actions_model / a_binding.action)
bare_keys_active: BOOLEAN
activate_bare_keys
    require recording: is_recording
    ensure active: bare_keys_active
deactivate_bare_keys
    ensure inactive: not bare_keys_active
invariant
    bare_only_when_recording: bare_keys_active implies is_recording                            -- DR-014
```

### PT_SETTINGS (SR_SETTINGS pattern)
```eiffel
set_font_size (a_px: INTEGER)
    require in_range: a_px >= Min_font and a_px <= Max_font
    ensure set: font_size = a_px; saved: save_count = old save_count + 1
font_size: INTEGER
    ensure clamped: Result >= Min_font and Result <= Max_font      -- bounded getter, default on bad data
```

### PT_SPEECH_SLOT (separate mailbox)
```eiffel
put (a_record: STRING_8)
    ensure grown_or_dropped: count = (old count + 1).min (Capacity)
           newest_last: records_model.last.same_string (a_record)
take_all: ARRAYED_LIST [STRING_8]
    ensure drained: count = 0; all_returned: Result.count = old count
invariant
    bounded: count <= Capacity
```
Overflow drops the oldest *frame* records first (heard records carry position and are worth more).

## Contract Completeness Checklist

| Feature | What changed | How (vs old) | What did NOT change |
|---------|--------------|--------------|---------------------|
| `PT_SCRIPT_HISTORY.apply_edit` | new revision | number +1 | older revisions; prefix/suffix ids |
| `PT_JOURNAL.append` | event added | `old model & e` | prior events (model equality) |
| `PT_FOLLOWER.advance` | target, velocity | ≥ old target; rate laws per mode | held → target unchanged |
| `PT_FOLLOWER.on_voice/on_alignment` | intent/velocity | | target |
| `PT_TAKE_CONTROLLER.perform` | state, caret, journal | table-driven | journal for browse actions |
| `PT_TAKE_CONTROLLER.pick_word` | caret | = index | journal |
| `PT_KEYMAP.bind` | one binding | replaced | all other actions |
| `PT_SILENCE_SNAPPER.snap` | cut spans | into silence | cut count, words |
| `PT_ALIGNER.update` | position, confidence | forward-bias laws | position when no anchors |
