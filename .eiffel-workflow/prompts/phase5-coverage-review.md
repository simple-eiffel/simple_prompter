# Test Coverage Review: simple_prompter (Phase 5)

Review the tests against the contracts. The contracts below are the short form of every
library class (exported signatures, header comments, require/ensure, invariants), generated
from src/ on 2026-10-05. Test routine names follow, per test class; full sources are in
testing/*.e.

## Check For
- Postconditions without a test that would notice them failing (a test that calls the
  feature counts in the contract-checked build, where every postcondition is evaluated;
  look for postconditions whose failure no assertion would also catch in the lean build)
- Edge cases not tested (empty scripts, one-word passages, cue-only passages, zero-length
  recordings, a take with no heard words)
- Precondition boundary tests missing (each refusal is checked with assert_refused)
- Behavior only checked on synthetic data that real voice might break (the real-voice
  tests replay larry_read_01: word times, VAD map, and the whole analyzer)

## Coverage measured
Public features named in tests: 750/750 (100.0%)
Classes: 88; fully covered: 88

## Tests

### LIB_TESTS (4)
- test_load_wires_everything
- test_fluent_configuration
- test_constant_practice_read_moves
- test_prompt_is_already_read_text_only

### TEST_ACCEPTANCE (17)
- test_read_test_parses_into_sections_and_sentences
- test_edit_insert_strike_and_edges
- test_step_back_and_forward_edges
- test_cough_session_journal
- test_journal_writes_and_replays
- test_silence_around_the_instructed_pause
- test_star_marks_exactly_one_attempt
- test_starred_older_take_wins
- test_edited_passage_needs_the_newer_take
- test_missing_passage_is_reported
- test_snapper_places_cuts_in_silence
- test_analyzer_success_path
- test_captions_respect_limits
- test_chapters_start_at_zero
- test_analysis_codec_round_trip
- test_settings_round_trip
- test_open_read_test_from_disk

### TEST_ASSEMBLY (8)
- test_speech_map_silence
- test_cut_list_output_mapping
- test_cut_list_refuses_script_disorder
- test_floor_is_the_complement
- test_attempt_per_resume
- test_solver_exact_cover_after_cough
- test_analyzer_reports_transcriber_failure
- test_flagger_flags_every_tight_cut

### TEST_ATTEMPT_ALIGNMENT (13)
- test_long_cue_does_not_stop_alignment
- test_stop_word_does_not_skip_ahead
- test_two_heard_words_for_one_script_word
- test_one_heard_token_for_three_script_words
- test_one_for_one_substitution_is_a_misread
- test_homophones_are_not_misreads
- test_uneven_gap_is_not_a_misread
- test_digits_are_not_sound_alikes
- test_ad_lib_word_does_not_pull_the_pointer
- test_skipped_paragraph_is_recovered
- test_misread_flags_only_inside_the_final_video
- test_analyzer_raises_the_misread_flag
- test_run_up_lookahead_and_substitution_limits

### TEST_CONFIG (10)
- test_defaults_need_modifiers
- test_bare_key_needs_the_recording_flag
- test_bare_keys_only_while_recording
- test_activation_refused_outside_recording
- test_two_keys_for_one_control
- test_rebinding_a_combo_replaces_it
- test_clicker_back_depends_on_state
- test_hold_toggle_and_wrap_by_mode
- test_setters_save_and_clamp_by_contract
- test_default_mode_waits_for_proof

### TEST_COVERAGE_CORE (35)
- test_time_span_queries
- test_word_timeline_queries
- test_equivalence_tables
- test_matcher_queries
- test_aligner_reanchor_and_constants
- test_alignment_record
- test_constant_follower_speed
- test_voice_gated_ramps
- test_tracking_follower_steers_and_coasts
- test_layout_lines_and_scroll
- test_spring_rate_and_reset
- test_pipeline_threshold_decoding_and_frames
- test_speech_codec_heard_round_trip
- test_voice_frame_seconds_and_fakes
- test_cut_and_cut_list_queries
- test_attempt_and_builder
- test_take_solver_queries
- test_flagger_low_confidence_restart_and_pause
- test_snapper_pads_and_words_inside
- test_analysis_records
- test_snapper_steps_over_vad_margins
- test_silence_searches_and_speech_map
- test_captions_vtt_and_cue_words
- test_edl_helpers
- test_cut_codec_errors_and_objects
- test_render_plan_fields
- test_review_srt_helpers
- test_chapter_and_timecode_helpers
- test_script_edit_kinds
- test_restart_policy_units
- test_script_parser_classification
- test_revision_and_structure_queries
- test_history_ids_and_journal_status
- test_event_names_and_edit_fields
- test_fixed_measure_and_heard_word

### TEST_COVERAGE_TAKE (17)
- test_session_folder_paths
- test_recorder_health
- test_camera_anchor
- test_scripted_transcriber
- test_settings_defaults_and_setters
- test_key_binding_codes
- test_keymap_bare_keys_follow_recording
- test_win32_virtual_key_codes
- test_control_resolver_routes
- test_controller_marker_count_in_and_queries
- test_controller_edit_range_again_and_wrap
- test_transitions_partition_actions
- test_recording_clock_samples_and_interpolation
- test_preflight_reports_problems
- test_capture_plan_fields
- test_session_analysis_and_cuts
- test_facade_feeds_voice_and_heard

### TEST_EQUIVALENCES (6)
- test_homophones_from_the_recording
- test_spoken_abbreviations_from_the_recording
- test_numbers_from_the_recording
- test_compounds_from_the_recording
- test_phonetics_from_the_recording
- test_unrelated_words_differ

### TEST_FOLLOWERS (21)
- test_constant_one_word_per_second_at_60_wpm
- test_held_follower_does_not_move
- test_constant_clamps_at_end
- test_caret_is_the_only_backward_move
- test_rescale_clamps_target
- test_voice_gated_moves_only_while_speaking
- test_voice_gated_stops_within_250_ms
- test_tracking_holds_after_coast_limit
- test_spring_moves_toward_target
- test_fixed_measure
- test_layout_wraps_every_word
- test_scroll_tick_keeps_time
- test_restart_snaps_scroll_back
- test_allowed_distance_tiers
- test_matcher_exact_and_tolerant
- test_equivalent_word_matches
- test_reanchor_places_position
- test_stop_words_alone_never_move
- test_stale_window_is_ignored
- test_aligner_follows_reading
- test_repeated_phrase_picks_the_forward_occurrence

### TEST_OUTPUTS (10)
- test_srt_and_vtt
- test_chapter_and_edl
- test_review_srt_one_cue_per_mark
- test_edl_has_one_event_per_cut
- test_render_plan_follows_the_spike_recipe
- test_cut_codec_round_trip
- test_capture_plan_recording_arguments
- test_capture_plan_sets_a_small_audio_buffer
- test_capture_plan_practice_is_audio_only
- test_preflight_disk_check

### TEST_PIPELINE (7)
- test_push_advances_recording_clock
- test_one_frame_per_512_samples
- test_no_decode_when_disabled
- test_decodes_while_speaking_with_prompt
- test_clear_pending_keeps_clock
- test_scripted_doubles
- test_speech_codec_round_trip

### TEST_REAL_VOICE (7)
- test_tracking_follows_larry_within_a_line
- test_tracking_holds_during_the_ad_lib
- test_tracking_jumps_the_skipped_paragraph
- test_tracking_never_moves_backward
- test_aligner_meets_frame_budget
- test_misreads_on_larry_read_01
- test_analysis_of_larry_read_01

### TEST_SCOOP_CONSUMER (1)
- test_separate_recording_clock

### TEST_SCRIPT (10)
- test_word_id_default_is_none
- test_revision_structure_from_fixture
- test_index_of_and_passage_of
- test_revision_rejects_duplicate_ids
- test_id_source_is_monotone
- test_stop_words
- test_parser_finds_words_and_passages
- test_parser_cues_are_not_spoken
- test_history_edit_keeps_untouched_ids
- test_normalizer

### TEST_TAKE (17)
- test_table_lists_34_pairs
- test_recording_only_and_practice_only
- test_editing_allows_only_commit_or_cancel
- test_record_then_count_in_done_reads
- test_again_counts_in_from_sentence_start
- test_resume_puts_reader_on_the_caret
- test_empty_script_cannot_start
- test_pick_word_moves_caret_without_journal
- test_practice_writes_no_journal
- test_disallowed_action_is_refused
- test_commit_edit_makes_a_revision
- test_journal_append_keeps_order
- test_journal_refuses_time_travel
- test_codec_round_trip
- test_64000_bytes_is_one_second
- test_clock_refuses_shrinking_file
- test_again_caret_rules

Total: 183 tests.

## Contracts (short form)
```eiffel
======== pt_analysis.e
class
	PT_ANALYSIS
create
	make, make_failed
feature {NONE} -- Initialization
	make (a_map: PT_SPEECH_MAP; a_timeline: PT_WORD_TIMELINE; a_attempts: LIST [PT_ATTEMPT];
			-- Successful analysis.
		ensure
			success: is_success and error = Void
			cuts_set: cuts = a_cuts
	make_failed (a_error: READABLE_STRING_32)
			-- Failed analysis (the Edit Floor falls back to live marks).
		require
			reason_present: not a_error.is_empty
		ensure
			failed: not is_success and attached error
feature -- Access
	speech_map: PT_SPEECH_MAP
	timeline: PT_WORD_TIMELINE
	attempts: ARRAYED_LIST [PT_ATTEMPT]
	cuts: PT_CUT_LIST
	flags: ARRAYED_LIST [PT_FLAG]
	decisions: ARRAYED_LIST [STRING_32]
	error: detachable STRING_32
feature -- Status
	is_success: BOOLEAN
invariant
	success_xor_error: is_success xor attached error
======== pt_attempt.e
class
	PT_ATTEMPT
create
	make
feature {NONE} -- Initialization
	make (a_index: INTEGER; a_span: PT_TIME_SPAN; a_caret: PT_WORD_ID; a_revision, a_first_index, a_last_index: INTEGER;
		require
			index_positive: a_index >= 1
			real_caret: not a_caret.is_none
			revision_positive: a_revision >= 1
			first_positive: a_first_index >= 1
			range_ordered: a_last_index >= a_first_index - 1
			not_both: not (a_starred and a_rejected)
		ensure
			index_set: index = a_index
			span_set: span = a_span
			caret_set: caret ~ a_caret
			revision_set: revision = a_revision
			range_set: first_index = a_first_index and last_index = a_last_index
			marks_set: is_starred = a_starred and is_rejected = a_rejected
feature -- Access
	index: INTEGER
	span: PT_TIME_SPAN
	caret: PT_WORD_ID
			-- Restart word the attempt began at.
	revision: INTEGER
	first_index, last_index: INTEGER
	word_count: INTEGER
		ensure
			non_negative: Result >= 0
feature -- Status
	is_starred: BOOLEAN
	is_rejected: BOOLEAN
	is_empty: BOOLEAN
invariant
	index_positive: index >= 1
	real_caret: not caret.is_none
	revision_positive: revision >= 1
	first_positive: first_index >= 1
	range_ordered: last_index >= first_index - 1
	not_both: not (is_starred and is_rejected)
======== pt_attempt_aligner.e
class
	PT_ATTEMPT_ALIGNER
create
	make
feature {NONE} -- Initialization
	make (a_matcher: PT_WORD_MATCHER)
		ensure
			matcher_set: matcher = a_matcher
			empty: last_timeline.count = 0
feature -- Constants
	Run_up: INTEGER = 6
	Lookahead: INTEGER = 8
feature -- Access
	matcher: PT_WORD_MATCHER
	last_timeline: PT_WORD_TIMELINE
			-- Result of the last `align'.
	last_misreads: ARRAYED_LIST [PT_MISREAD]
			-- One-for-one substitutions found by the last `align' (T18): heard words that matched
			-- nothing, followed by a match that skipped exactly as many script words.
	Lost_after: INTEGER = 2
			-- Unmatched heard words in a row before the search widens (skipped paragraph, ad-lib);
			-- the confirmation rule keeps an ad-lib word from pulling the pointer.
	Wide_lookahead: INTEGER = 60
			-- Spoken words searched when lost (content words only, confirmed by the next heard word).
	Max_substitution: INTEGER = 3
			-- Longest run of substituted words reported as misreads (longer runs are ad-libs or
			-- lost alignment, not misreads).
feature -- Basic operations
	align (a_attempts: LIST [PT_ATTEMPT]; a_history: PT_SCRIPT_HISTORY; a_heard: PT_HEARD_WORDS)
			-- Occurrences of script words heard during each attempt.
		require
			revisions_known: across a_attempts as ic all ic.revision >= 1 and ic.revision <= a_history.revision_count end
		ensure
			inside_attempts: across 1 |..| last_timeline.count as i all
					last_timeline.occurrence (i).attempt <= a_attempts.count and then
					a_attempts [last_timeline.occurrence (i).attempt].span.contains (last_timeline.occurrence (i).span.t0) end
			words_of_revision: across 1 |..| last_timeline.count as i all
					a_history.revision (a_attempts [last_timeline.occurrence (i).attempt].revision).index_of (last_timeline.occurrence (i).word) > 0 end
======== pt_attempt_builder.e
class
	PT_ATTEMPT_BUILDER
create
	make
feature {NONE} -- Initialization
	make
		ensure
			nothing_built: last_attempts.is_empty
feature -- Access
	last_attempts: ARRAYED_LIST [PT_ATTEMPT]
			-- Result of the last `build'.
feature -- Basic operations
	build (a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY; a_end_rt: REAL_64)
			-- Attempts of a session ending at `a_end_rt'.
		require
			ended: a_end_rt >= a_journal.last_rt
			has_revision: a_history.revision_count >= 1
		ensure
			one_per_resume: last_attempts.count = a_journal.count_of ({PT_EVENT_KIND}.Resume)
			indexed: across 1 |..| last_attempts.count as i all last_attempts [i].index = i end
			ordered_disjoint: across 2 |..| last_attempts.count as i all
					last_attempts [i - 1].span.t1 <= last_attempts [i].span.t0 end
			within: across last_attempts as ic all ic.span.t1 <= a_end_rt end
			known_revisions: across last_attempts as ic all ic.revision <= a_history.revision_count end
			one_star_one_attempt: starred_count <= a_journal.count_of ({PT_EVENT_KIND}.Star)
			not_both: across last_attempts as ic all not (ic.is_starred and ic.is_rejected) end
feature -- Contract helpers
	starred_count: INTEGER
			-- Starred attempts in `last_attempts'.
======== pt_cut.e
class
	PT_CUT
create
	make
feature {NONE} -- Initialization
	make (a_src: INTEGER; a_span: PT_TIME_SPAN; a_word_ids: ITERABLE [PT_WORD_ID];
			-- Interval `a_span' of source `a_src' carrying final-revision words `a_first_index'..`a_last_index'.
		require
			src_non_negative: a_src >= 0
			first_positive: a_first_index >= 1
			ordered: a_first_index <= a_last_index
			attempt_positive: a_attempt >= 1
		ensure
			src_set: src = a_src
			span_set: span = a_span
			range_set: first_word_index = a_first_index and last_word_index = a_last_index
			attempt_set: attempt = a_attempt
			tight_set: is_tight = a_tight
feature -- Access
	src: INTEGER
			-- Source file index (0 = raw.mkv; pickups later).
	span: PT_TIME_SPAN
	word_ids: ARRAYED_LIST [PT_WORD_ID]
			-- Spoken final-revision word ids carried, in order (cue words excluded).
	first_word_index, last_word_index: INTEGER
	attempt: INTEGER
	first_word: PT_WORD_ID
		require
			has_words: not word_ids.is_empty
	last_word: PT_WORD_ID
		require
			has_words: not word_ids.is_empty
feature -- Status
	is_tight: BOOLEAN
feature -- Derivation
	with_span (a_span: PT_TIME_SPAN; a_tight: BOOLEAN): PT_CUT
			-- Same words and attempt over `a_span'.
		ensure
			same_words: Result.word_ids ~ word_ids
			span_set: Result.span = a_span
invariant
	src_non_negative: src >= 0
	first_positive: first_word_index >= 1
	ordered: first_word_index <= last_word_index
	attempt_positive: attempt >= 1
	ids_fit_range: word_ids.count <= last_word_index - first_word_index + 1
======== pt_cut_list.e
class
	PT_CUT_LIST
create
	make
feature {NONE} -- Initialization
	make
		ensure
			empty: count = 0
feature -- Access
	count: INTEGER
	cut (a_index: INTEGER): PT_CUT
		require
			valid_index: a_index >= 1 and a_index <= count
	output_duration: REAL_64
			-- Length of the final video.
		ensure
			sum: (Result - span_total (cuts_model)).abs < 1.0e-9
	is_kept (a_src: INTEGER; a_rt: REAL_64): BOOLEAN
			-- Is time `a_rt' of source `a_src' in the final video?
	to_output_time (a_src: INTEGER; a_rt: REAL_64): REAL_64
			-- Where `a_rt' of source `a_src' lands in the final video.
		require
			kept: is_kept (a_src, a_rt)
		ensure
			in_range: Result >= 0 and Result <= output_duration + 1.0e-9
	floor_spans (a_src: INTEGER; a_raw_duration: REAL_64): ARRAYED_LIST [PT_TIME_SPAN]
			-- Parts of source `a_src' (length `a_raw_duration') not in the final video.
		require
			duration_non_negative: a_raw_duration >= 0
		ensure
			complement: ((source_kept_duration (a_src) + list_total (Result)) - a_raw_duration).abs < 1.0e-6
	source_kept_duration (a_src: INTEGER): REAL_64
			-- Total kept time from source `a_src'.
feature -- Model
	cuts_model: MML_SEQUENCE [PT_CUT]
		ensure
			same_count: Result.count = count
	words_model: MML_SEQUENCE [PT_WORD_ID]
			-- Word ids carried by the final video, in output order.
feature -- Model helpers
	span_total (a_cuts: MML_SEQUENCE [PT_CUT]): REAL_64
			-- Sum of span durations in `a_cuts'.
	list_total (a_spans: LIST [PT_TIME_SPAN]): REAL_64
			-- Sum of durations in `a_spans'.
feature -- Element change
	extend (a_cut: PT_CUT)
			-- Append the next cut in output (script) order.
		require
			script_order: count = 0 or else a_cut.first_word_index > cut (count).last_word_index
		ensure
			appended: (cuts_model |=| (old cuts_model & a_cut))
invariant
	count_non_negative: count >= 0
======== pt_flag.e
class
	PT_FLAG
create
	make
feature {NONE} -- Initialization
	make (a_kind: INTEGER; a_span: PT_TIME_SPAN; a_first_word, a_last_word: PT_WORD_ID; a_message: READABLE_STRING_32)
		require
			kind_known: a_kind >= {PT_FLAG_KIND}.Misread and a_kind <= {PT_FLAG_KIND}.Long_pause
			message_present: not a_message.is_empty
		ensure
			kind_set: kind = a_kind
			span_set: span = a_span
			words_set: first_word ~ a_first_word and last_word ~ a_last_word
			message_set: message.same_string (a_message)
feature -- Access
	kind: INTEGER
	span: PT_TIME_SPAN
	first_word, last_word: PT_WORD_ID
	message: STRING_32
			-- E.g. "sentence 15: you said 'their' (script: 'there')".
invariant
	kind_known: kind >= {PT_FLAG_KIND}.Misread and kind <= {PT_FLAG_KIND}.Long_pause
	message_present: not message.is_empty
======== pt_flag_kind.e
class
	PT_FLAG_KIND
feature -- Constants
	Misread: INTEGER = 1
			-- Heard word differs from the script word.
	Low_confidence: INTEGER = 2
	Unmarked_restart: INTEGER = 3
			-- Same words read twice in one attempt without pressing Again.
	Tight_splice: INTEGER = 4
			-- A cut edge could not be placed in silence.
	Missing: INTEGER = 5
			-- A passage has no valid take.
	Long_pause: INTEGER = 6
			-- A long silence kept inside a take.
======== pt_flagger.e
class
	PT_FLAGGER
create
	make
feature {NONE} -- Initialization
	make (a_long_pause_s: REAL_64)
		require
			positive: a_long_pause_s > 0
		ensure
			set: long_pause_s = a_long_pause_s
feature -- Access
	long_pause_s: REAL_64
	last_flags: ARRAYED_LIST [PT_FLAG]
	count_of (a_kind: INTEGER): INTEGER
feature -- Basic operations
	flag (a_cuts: PT_CUT_LIST; a_missing: LIST [PT_WORD_ID]; a_timeline: PT_WORD_TIMELINE; a_map: PT_SPEECH_MAP)
			-- Flags for a solved and snapped session.
		ensure
			tight_flagged: count_of ({PT_FLAG_KIND}.Tight_splice) = tight_count (a_cuts)
			missing_flagged: a_missing.is_empty = (count_of ({PT_FLAG_KIND}.Missing) = 0)
	flag_misreads (a_misreads: LIST [PT_MISREAD]; a_cuts: PT_CUT_LIST)
			-- Add a Misread flag for each misread that lies in the final video (T18). Misreads in
			-- takes that were not used do not matter to the viewer.
		ensure
			misreads_flagged: count_of ({PT_FLAG_KIND}.Misread) = old count_of ({PT_FLAG_KIND}.Misread) + kept_count (a_misreads, a_cuts)
			only_misreads_added: last_flags.count = old last_flags.count + kept_count (a_misreads, a_cuts)
feature -- Constants
	Low_confidence_level: REAL_64 = 0.35
feature -- Contract helpers
	kept_count (a_misreads: LIST [PT_MISREAD]; a_cuts: PT_CUT_LIST): INTEGER
			-- Misreads whose start lies in the final video.
		ensure
			bounded: Result >= 0 and Result <= a_misreads.count
	tight_count (a_cuts: PT_CUT_LIST): INTEGER
invariant
	positive: long_pause_s > 0
======== pt_misread.e
class
	PT_MISREAD
create
	make
feature {NONE} -- Initialization
	make (a_word: PT_WORD_ID; a_script_text, a_heard_text: READABLE_STRING_32; a_span: PT_TIME_SPAN; a_attempt: INTEGER)
			-- Script word `a_word' (written `a_script_text') heard as `a_heard_text' during `a_span' of attempt `a_attempt'.
		require
			real_word: not a_word.is_none
			script_present: not a_script_text.is_empty
			heard_present: not a_heard_text.is_empty
			attempt_positive: a_attempt >= 1
		ensure
			word_set: word ~ a_word
			script_set: script_text.same_string (a_script_text)
			heard_set: heard_text.same_string (a_heard_text)
			span_set: span = a_span
			attempt_set: attempt = a_attempt
feature -- Access
	word: PT_WORD_ID
			-- Script word that was expected.
	script_text: STRING_32
			-- The script word as written.
	heard_text: STRING_32
			-- What was heard instead (normalized).
	span: PT_TIME_SPAN
			-- When the heard word was spoken (recording time).
	attempt: INTEGER
			-- Attempt it was heard in.
invariant
	real_word: not word.is_none
	script_present: not script_text.is_empty
	heard_present: not heard_text.is_empty
	attempt_positive: attempt >= 1
======== pt_scripted_transcriber.e
class
	PT_SCRIPTED_TRANSCRIBER
inherit
	PT_TRANSCRIBER
create
	make, make_failing
feature {NONE} -- Initialization
	make (a_map: PT_SPEECH_MAP; a_heard: PT_HEARD_WORDS)
			-- Succeed with `a_map' and `a_heard'.
		ensure
			will_succeed: not fails
	make_failing (a_reason: READABLE_STRING_32)
			-- Fail with `a_reason'.
		ensure
			will_fail: fails
feature -- Access
	fails: BOOLEAN
	reason: detachable STRING_32
feature -- Basic operations
	transcribe (a_audio_path: READABLE_STRING_32; a_duration: REAL_64)
			-- Hand back the fixture (map re-dimensioned to `a_duration').
======== pt_session_analyzer.e
class
	PT_SESSION_ANALYZER
create
	make
feature {NONE} -- Initialization
	make (a_transcriber: PT_TRANSCRIBER; a_builder: PT_ATTEMPT_BUILDER; a_aligner: PT_ATTEMPT_ALIGNER;
		ensure
			transcriber_set: transcriber = a_transcriber
			not_yet: not last_analysis.is_success
feature -- Access
	transcriber: PT_TRANSCRIBER
	builder: PT_ATTEMPT_BUILDER
	aligner: PT_ATTEMPT_ALIGNER
	solver: PT_TAKE_SOLVER
	snapper: PT_SILENCE_SNAPPER
	flagger: PT_FLAGGER
	last_analysis: PT_ANALYSIS
			-- Outcome of the last `analyze'.
feature -- Basic operations
	analyze (a_audio_path: READABLE_STRING_32; a_duration: REAL_64; a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY)
			-- Analyze a wrapped session.
		require
			path_present: not a_audio_path.is_empty
			duration_positive: a_duration > 0
			journal_within: a_journal.last_rt <= a_duration
			has_revision: a_history.revision_count >= 1
		ensure
			failure_reported: not transcriber.is_success implies not last_analysis.is_success
			attempts_from_journal: last_analysis.is_success implies
					last_analysis.attempts.count = a_journal.count_of ({PT_EVENT_KIND}.Resume)
			cover_when_complete: (last_analysis.is_success and solver.is_complete) implies
					(last_analysis.cuts.words_model |=| a_history.current_revision.spoken_ids_model)
======== pt_silence_snapper.e
class
	PT_SILENCE_SNAPPER
create
	make
feature {NONE} -- Initialization
	make (a_head_pad, a_tail_pad: REAL_64)
			-- Margins used when no silence is available.
		require
			pads_non_negative: a_head_pad >= 0 and a_tail_pad >= 0
		ensure
			pads_set: head_pad = a_head_pad and tail_pad = a_tail_pad
feature -- Access
	head_pad, tail_pad: REAL_64
	last_result: PT_CUT_LIST
feature -- Basic operations
	snap (a_cuts: PT_CUT_LIST; a_map: PT_SPEECH_MAP; a_timeline: PT_WORD_TIMELINE)
			-- Snapped copy of `a_cuts' in `last_result'.
		require
			spans_in_map: across 1 |..| a_cuts.count as i all a_cuts.cut (i).span.t1 <= a_map.duration end
		ensure
			same_count: last_result.count = a_cuts.count
			same_words: (last_result.words_model |=| a_cuts.words_model)
			within_recording: across 1 |..| last_result.count as i all last_result.cut (i).span.t1 <= a_map.duration end
			in_silence_or_tight: across 1 |..| last_result.count as i all
					last_result.cut (i).is_tight or
					(a_map.is_silent_at (last_result.cut (i).span.t0) and a_map.is_silent_at (last_result.cut (i).span.t1)) end
			words_not_clipped: across 1 |..| last_result.count as i all
					words_inside (last_result.cut (i), a_timeline) end
feature -- Constants
	Probe: REAL_64 = 0.02
			-- Distance from a word edge at which silence is looked for.
	Max_lead: REAL_64 = 0.6
	Max_tail: REAL_64 = 0.8
			-- Longest silence kept before the first word / after the last word.
feature -- Silence search
	silence_before (a_map: PT_SPEECH_MAP; a_t: REAL_64): detachable PT_TIME_SPAN
			-- Nearest silent interval before `a_t' that reaches within `Max_lead' of it, stepping back
			-- over speech spans that begin within reach.
		require
			in_range: a_t >= 0 and a_t <= a_map.duration
		ensure
			within_reach: attached Result as al_r implies (al_r.t1 >= a_t - Max_lead and al_r.t0 <= a_t)
	silence_after (a_map: PT_SPEECH_MAP; a_t: REAL_64): detachable PT_TIME_SPAN
			-- Nearest silent interval after `a_t' that begins within `Max_tail' of it, stepping forward
			-- over speech spans that end within reach.
		require
			in_range: a_t >= 0 and a_t <= a_map.duration
		ensure
			within_reach: attached Result as al_r implies (al_r.t0 <= a_t + Max_tail and al_r.t1 >= a_t)
feature -- Contract helpers
	words_inside (a_cut: PT_CUT; a_timeline: PT_WORD_TIMELINE): BOOLEAN
			-- Do all heard occurrences of `a_cut''s words in its attempt lie inside its span?
invariant
	pads_non_negative: head_pad >= 0 and tail_pad >= 0
======== pt_speech_map.e
class
	PT_SPEECH_MAP
create
	make
feature {NONE} -- Initialization
	make (a_duration: REAL_64)
			-- Map of a recording `a_duration' seconds long, no speech yet.
		require
			non_negative: a_duration >= 0
		ensure
			duration_set: duration = a_duration
			no_speech: span_count = 0
feature -- Access
	duration: REAL_64
	span_count: INTEGER
	span (a_index: INTEGER): PT_TIME_SPAN
		require
			valid_index: a_index >= 1 and a_index <= span_count
	last_end: REAL_64
			-- End of the last speech span (0 when none).
feature -- Queries
	is_silent_at (a_t: REAL_64): BOOLEAN
			-- Is `a_t' outside every speech span?
		require
			in_range: a_t >= 0 and a_t <= duration
		ensure
			definition: Result = not across 1 |..| span_count as i some span (i).contains (a_t) end
	silence_around (a_t: REAL_64): detachable PT_TIME_SPAN
			-- Maximal silent interval containing `a_t', if `a_t' is silent.
		require
			in_range: a_t >= 0 and a_t <= duration
		ensure
			only_when_silent: attached Result implies is_silent_at (a_t)
			contains_t: attached Result as al_r implies al_r.contains (a_t)
feature -- Model
	spans_model: MML_SEQUENCE [PT_TIME_SPAN]
		ensure
			same_count: Result.count = span_count
feature -- Element change
	extend_span (a_span: PT_TIME_SPAN)
			-- Add the next speech span.
		require
			after_previous: a_span.t0 >= last_end
			within: a_span.t1 <= duration
		ensure
			appended: (spans_model |=| (old spans_model & a_span))
invariant
	duration_non_negative: duration >= 0
	within: last_end <= duration
======== pt_take_solver.e
class
	PT_TAKE_SOLVER
create
	make
feature {NONE} -- Initialization
	make (a_splice_cost, a_age_penalty, a_min_confidence: REAL_64)
		require
			costs_non_negative: a_splice_cost >= 0 and a_age_penalty >= 0
			confidence_range: a_min_confidence >= 0.0 and a_min_confidence <= 1.0
		ensure
			costs_set: splice_cost = a_splice_cost and age_penalty = a_age_penalty
			confidence_set: min_confidence = a_min_confidence
feature -- Access
	splice_cost, age_penalty, min_confidence: REAL_64
	last_result: PT_CUT_LIST
			-- Cut list from the last `solve'.
	missing_words: ARRAYED_LIST [PT_WORD_ID]
			-- Spoken final words with no valid take (last `solve').
	decisions: ARRAYED_LIST [STRING_32]
			-- One line per choice made (FR-NEW-006 decision log).
feature -- Status
	is_complete: BOOLEAN
			-- Did the last `solve' cover every spoken word?
feature -- Basic operations
	solve (a_history: PT_SCRIPT_HISTORY; a_attempts: LIST [PT_ATTEMPT]; a_timeline: PT_WORD_TIMELINE)
			-- Choose takes for `a_history.current_revision'.
		require
			has_revision: a_history.revision_count >= 1
			attempts_indexed: across 1 |..| a_attempts.count as i all a_attempts [i].index = i end
		ensure
			exact_cover_in_order: is_complete implies (last_result.words_model |=| a_history.current_revision.spoken_ids_model)
			missing_are_spoken: across missing_words as ic all a_history.current_revision.spoken_ids_model.has (ic) end
			no_rejected: across 1 |..| last_result.count as i all
					not a_attempts [last_result.cut (i).attempt].is_rejected end
			no_stale: across 1 |..| last_result.count as i all
					is_current_take (last_result.cut (i), a_history, a_attempts) end
			star_wins: across 1 |..| last_result.count as i all
					not superseded_by_star (last_result.cut (i), a_attempts) end
			decisions_logged: last_result.count > 0 implies decisions.count >= last_result.count
			switch_at_passage_start: across 2 |..| last_result.count as i all
					last_result.cut (i).attempt /= last_result.cut (i - 1).attempt implies
						(is_passage_start (a_history.current_revision, last_result.cut (i).first_word_index) or last_result.cut (i).is_tight) end
feature -- Contract helpers
	is_passage_start (a_revision: PT_SCRIPT_REVISION; a_word: INTEGER): BOOLEAN
			-- Is word `a_word' the first word of its passage?
	is_current_take (a_cut: PT_CUT; a_history: PT_SCRIPT_HISTORY; a_attempts: LIST [PT_ATTEMPT]): BOOLEAN
			-- Were all of `a_cut''s words present, unchanged, in the revision its attempt read?
		require
			attempt_known: a_cut.attempt >= 1 and a_cut.attempt <= a_attempts.count
			revision_known: a_attempts [a_cut.attempt].revision <= a_history.revision_count
	superseded_by_star (a_cut: PT_CUT; a_attempts: LIST [PT_ATTEMPT]): BOOLEAN
			-- Is `a_cut' taken from an unstarred attempt while a starred attempt, read in the same
			-- revision, covers its first word (review M11: passage overlap by word id)?
		require
			attempt_known: a_cut.attempt >= 1 and a_cut.attempt <= a_attempts.count
invariant
	costs_non_negative: splice_cost >= 0 and age_penalty >= 0
	confidence_range: min_confidence >= 0.0 and min_confidence <= 1.0
======== pt_time_span.e
class
	PT_TIME_SPAN
create
	make
feature {NONE} -- Initialization
	make (a_t0, a_t1: REAL_64)
			-- Interval from `a_t0' to `a_t1'.
		require
			non_negative: a_t0 >= 0
			ordered: a_t0 <= a_t1
		ensure
			set: t0 = a_t0 and t1 = a_t1
feature -- Access
	t0, t1: REAL_64
	duration: REAL_64
		ensure
			non_negative: Result >= 0
	midpoint: REAL_64
		ensure
			inside: contains (Result)
feature -- Status
	contains (a_t: REAL_64): BOOLEAN
		ensure
			definition: Result = (t0 <= a_t and a_t <= t1)
	overlaps (a_other: PT_TIME_SPAN): BOOLEAN
			-- Do the intervals share more than an end point?
invariant
	non_negative: t0 >= 0
	ordered: t0 <= t1
======== pt_transcriber.e
deferred class
	PT_TRANSCRIBER
feature -- Access
	last_map: detachable PT_SPEECH_MAP
			-- Speech map from the last successful `transcribe'.
	last_heard: detachable PT_HEARD_WORDS
			-- Words from the last successful `transcribe' (times are absolute seconds).
	last_error: detachable STRING_32
			-- Why the last `transcribe' failed.
feature -- Status
	is_success: BOOLEAN
			-- Did the last `transcribe' succeed?
feature -- Basic operations
	transcribe (a_audio_path: READABLE_STRING_32; a_duration: REAL_64)
			-- Transcribe the recording at `a_audio_path' (`a_duration' seconds long).
		require
			path_present: not a_audio_path.is_empty
			duration_positive: a_duration > 0
		deferred
		ensure
			outcome: is_success xor attached last_error
			map_on_success: is_success implies (attached last_map as al_map and then al_map.duration = a_duration)
			words_on_success: is_success implies attached last_heard
======== pt_word_occurrence.e
class
	PT_WORD_OCCURRENCE
create
	make
feature {NONE} -- Initialization
	make (a_word: PT_WORD_ID; a_span: PT_TIME_SPAN; a_confidence: REAL_64; a_attempt: INTEGER)
		require
			real_word: not a_word.is_none
			confidence_range: a_confidence >= 0.0 and a_confidence <= 1.0
			attempt_positive: a_attempt >= 1
		ensure
			word_set: word ~ a_word
			span_set: span = a_span
			confidence_set: confidence = a_confidence
			attempt_set: attempt = a_attempt
feature -- Access
	word: PT_WORD_ID
	span: PT_TIME_SPAN
	confidence: REAL_64
	attempt: INTEGER
invariant
	real_word: not word.is_none
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	attempt_positive: attempt >= 1
======== pt_word_timeline.e
class
	PT_WORD_TIMELINE
create
	make
feature {NONE} -- Initialization
	make
		ensure
			empty: count = 0
feature -- Access
	count: INTEGER
	occurrence (a_index: INTEGER): PT_WORD_OCCURRENCE
		require
			valid_index: a_index >= 1 and a_index <= count
	last_start: REAL_64
			-- Start of the last occurrence (0 when empty).
	occurrence_in (a_word: PT_WORD_ID; a_attempt: INTEGER): detachable PT_WORD_OCCURRENCE
			-- Occurrence of `a_word' in attempt `a_attempt', if heard there.
		ensure
			matches: attached Result as al_r implies (al_r.word ~ a_word and al_r.attempt = a_attempt)
	has_in (a_word: PT_WORD_ID; a_attempt: INTEGER): BOOLEAN
			-- Was `a_word' heard in attempt `a_attempt'?
feature -- Model
	occurrences_model: MML_SEQUENCE [PT_WORD_OCCURRENCE]
		ensure
			same_count: Result.count = count
feature -- Element change
	extend (a_occurrence: PT_WORD_OCCURRENCE)
			-- Add the next occurrence (start-time order).
		require
			ordered: a_occurrence.span.t0 >= last_start
		ensure
			appended: (occurrences_model |=| (old occurrences_model & a_occurrence))
invariant
	last_start_non_negative: last_start >= 0
======== pt_camera_anchor.e
class
	PT_CAMERA_ANCHOR
create
	make
feature {NONE} -- Initialization
	make (a_monitor_key: READABLE_STRING_32; a_x, a_y: INTEGER)
			-- Lens at (`a_x', `a_y') on the monitor identified by `a_monitor_key' (device name + resolution).
		require
			key_present: not a_monitor_key.is_empty
		ensure
			key_set: monitor_key.same_string (a_monitor_key)
			point_set: x = a_x and y = a_y
feature -- Access
	monitor_key: STRING_32
	x, y: INTEGER
invariant
	key_present: not monitor_key.is_empty
======== pt_control.e
class
	PT_CONTROL
feature -- Constants
	Hold_toggle: INTEGER = 1
			-- Hold while reading or counting in; Go while held.
	Again: INTEGER = 2
	Go: INTEGER = 3
	Back: INTEGER = 4
	Forward: INTEGER = 5
	Back_paragraph: INTEGER = 6
	Forward_paragraph: INTEGER = 7
	Edit: INTEGER = 8
	Star: INTEGER = 9
	Reject: INTEGER = 10
	Marker: INTEGER = 11
	Skip: INTEGER = 12
	Wrap: INTEGER = 13
			-- Wrap while recording; Stop in practice.
	Play_stop: INTEGER = 14
			-- Play from idle; Stop in practice.
	Abort: INTEGER = 15
	Clicker_back: INTEGER = 16
			-- Again while reading or counting in; Back while held.
	Clicker_forward: INTEGER = 17
			-- Go while held.
	Clicker_hold: INTEGER = 18
			-- Same as Hold_toggle.
	Hide: INTEGER = 19
			-- App-level (no take action).
	Click_through: INTEGER = 20
			-- App-level (no take action).
======== pt_control_resolver.e
class
	PT_CONTROL_RESOLVER
create
	make
feature {NONE} -- Initialization
	make
feature -- Access
	transitions: PT_TRANSITIONS
feature -- Queries
	action_for (a_control, a_state: INTEGER; a_recording: BOOLEAN): INTEGER
			-- Action for `a_control' in `a_state', or 0.
		require
			control_known: a_control >= {PT_CONTROL}.Hold_toggle and a_control <= {PT_CONTROL}.Click_through
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
		ensure
			allowed_or_none: Result /= 0 implies transitions.is_allowed (a_state, Result, a_recording)
			app_level_none: (a_control = {PT_CONTROL}.Hide or a_control = {PT_CONTROL}.Click_through) implies Result = 0
			clicker_back_reading: (a_control = {PT_CONTROL}.Clicker_back and a_state = {PT_TAKE_STATE}.Reading) implies Result = {PT_ACTION}.Again
			clicker_back_held: (a_control = {PT_CONTROL}.Clicker_back and a_state = {PT_TAKE_STATE}.Held) implies Result = {PT_ACTION}.Back
			hold_toggle_held: (a_control = {PT_CONTROL}.Hold_toggle and a_state = {PT_TAKE_STATE}.Held) implies Result = {PT_ACTION}.Go
======== pt_key_binding.e
class
	PT_KEY_BINDING
create
	make
feature {NONE} -- Initialization
	make (a_control: INTEGER; a_modifiers: NATURAL_32; a_vkey: INTEGER; a_bare_while_recording: BOOLEAN)
		require
			control_known: a_control >= {PT_CONTROL}.Hold_toggle and a_control <= {PT_CONTROL}.Click_through
			modifiers_known: a_modifiers <= All_modifiers
			vkey_range: a_vkey > 0 and a_vkey <= 254
			interlock: a_modifiers /= 0 or a_bare_while_recording
		ensure
			control_set: control = a_control
			key_set: modifiers = a_modifiers and vkey = a_vkey
			bare_set: is_bare_while_recording = a_bare_while_recording
feature -- Constants
	Mod_alt: NATURAL_32 = 0x1
	Mod_control: NATURAL_32 = 0x2
	Mod_shift: NATURAL_32 = 0x4
	Mod_win: NATURAL_32 = 0x8
	All_modifiers: NATURAL_32 = 0xF
feature -- Access
	control: INTEGER
	modifiers: NATURAL_32
	vkey: INTEGER
	key_code: INTEGER_64
			-- Unique code of the combo.
	combo_code (a_modifiers: NATURAL_32; a_vkey: INTEGER): INTEGER_64
			-- Code of combo (`a_modifiers', `a_vkey').
		ensure
			distinct_vkeys: Result \\ 65_536 = a_vkey
feature -- Status
	is_bare_while_recording: BOOLEAN
	is_bare: BOOLEAN
invariant
	control_known: control >= {PT_CONTROL}.Hold_toggle and control <= {PT_CONTROL}.Click_through
	interlock: modifiers /= 0 or is_bare_while_recording
	vkey_range: vkey > 0 and vkey <= 254
======== pt_keymap.e
class
	PT_KEYMAP
create
	make, make_default
feature {NONE} -- Initialization
	make
			-- No bindings.
		ensure
			empty: binding_count = 0
			not_recording: not is_recording and not bare_keys_active
	make_default
			-- Ctrl+Alt hotkeys of spec 07 section 2.14 (no bare keys; see `bind_clicker_defaults').
		ensure
			hold_bound: has_control ({PT_CONTROL}.Hold_toggle)
			again_bound: has_control ({PT_CONTROL}.Again)
			wrap_bound: has_control ({PT_CONTROL}.Wrap)
			no_bare_defaults: across bindings as ic all not ic.is_bare end
feature -- Constants (Win32 virtual keys)
	Vk_back: INTEGER = 0x08
	Vk_return: INTEGER = 0x0D
	Vk_space: INTEGER = 0x20
	Vk_prior: INTEGER = 0x21
			-- PageUp (clicker Back).
	Vk_next: INTEGER = 0x22
			-- PageDown (clicker Forward).
	Vk_end: INTEGER = 0x23
	Vk_left: INTEGER = 0x25
	Vk_right: INTEGER = 0x27
	Vk_b: INTEGER = 0x42
	Vk_e: INTEGER = 0x45
	Vk_h: INTEGER = 0x48
	Vk_i: INTEGER = 0x49
	Vk_n: INTEGER = 0x4E
	Vk_p: INTEGER = 0x50
	Vk_s: INTEGER = 0x53
	Vk_x: INTEGER = 0x58
	Vk_oem_period: INTEGER = 0xBE
feature -- Access
	binding_count: INTEGER
	has_control (a_control: INTEGER): BOOLEAN
			-- Is some key bound to `a_control'?
	keys_for (a_control: INTEGER): INTEGER
			-- Number of keys bound to `a_control'.
	control_for (a_modifiers: NATURAL_32; a_vkey: INTEGER): INTEGER
			-- Control bound to the key press, 0 if none (bare keys only while active).
		ensure
			bare_ignored_unless_active: (a_modifiers = 0 and not bare_keys_active) implies Result = 0
feature -- Status
	is_recording: BOOLEAN
	bare_keys_active: BOOLEAN
feature -- Model
	combos_model: MML_SET [INTEGER_64]
			-- Bound key combos.
		ensure
			same_count: Result.count = binding_count
feature -- Element change
	bind (a_binding: PT_KEY_BINDING)
			-- Bind (or rebind) the combo of `a_binding'.
		ensure
			bound: attached bindings.item (a_binding.key_code) as al_b and then al_b = a_binding
			others_kept: ((combos_model / a_binding.key_code) |=| (old combos_model / a_binding.key_code))
	bind_clicker_defaults
			-- Bare clicker keys, live only while recording: PageUp = Clicker_back,
			-- PageDown = Clicker_forward, B and "." = Clicker_hold.
		ensure
			two_hold_keys: keys_for ({PT_CONTROL}.Clicker_hold) >= 2
	set_recording (a_recording: BOOLEAN)
			-- Recording started or ended; ending releases bare keys.
		ensure
			set: is_recording = a_recording
			released: not a_recording implies not bare_keys_active
	activate_bare_keys
		require
			recording: is_recording
		ensure
			active: bare_keys_active
	deactivate_bare_keys
		ensure
			inactive: not bare_keys_active
invariant
	bare_only_when_recording: bare_keys_active implies is_recording
======== pt_settings.e
class
	PT_SETTINGS
create
	make_in_memory, make_with_file
feature {NONE} -- Initialization
	make_in_memory
			-- Defaults, never written to disk (tests).
		ensure
			memory_only: path = Void
			nothing_saved: save_count = 0
	make_with_file (a_path: READABLE_STRING_32)
			-- Load from `a_path' (defaults where absent or out of range).
		require
			path_present: not a_path.is_empty
		ensure
			persistent: attached path
feature -- Constants
	Min_font: INTEGER = 12
	Max_font: INTEGER = 96
	Default_font: INTEGER = 28
	Min_lines: INTEGER = 1
	Max_lines: INTEGER = 12
	Default_lines: INTEGER = 3
	Min_width: INTEGER = 200
	Max_width: INTEGER = 2400
	Default_width: INTEGER = 560
	Min_wpm: INTEGER = 40
	Max_wpm: INTEGER = 400
	Default_wpm: INTEGER = 130
feature -- Access
	path: detachable STRING_32
	save_count: INTEGER
			-- Number of saves (each setter saves once).
	font_size: INTEGER
	lines_visible: INTEGER
	column_width: INTEGER
	opacity: INTEGER
			-- 0..255 (whole-window alpha; capture-exclusion compatible).
	speed_wpm: INTEGER
	count_in_seconds: REAL_64
	head_pad, tail_pad: REAL_64
	sessions_root: STRING_32
			-- Empty = %USERPROFILE%\Videos\simple_prompter (resolved by the app; approved Q8).
	camera_name, microphone_name: STRING_32
	is_tracking_proven: BOOLEAN
			-- Set once Tracking passes its acceptance test (approved Q5).
	default_mode (a_gpu_available: BOOLEAN): INTEGER
			-- Mode to start in.
		ensure
			tracking_only_when_proven: Result = {PT_FOLLOW_MODE}.Tracking implies (is_tracking_proven and a_gpu_available)
			known: Result >= {PT_FOLLOW_MODE}.Constant and Result <= {PT_FOLLOW_MODE}.Tracking
feature -- Element change
	set_font_size (a_px: INTEGER)
		require
			in_range: a_px >= Min_font and a_px <= Max_font
		ensure
			set: font_size = a_px
			saved: save_count = old save_count + 1
	set_lines_visible (a_lines: INTEGER)
		require
			in_range: a_lines >= Min_lines and a_lines <= Max_lines
		ensure
			set: lines_visible = a_lines
			saved: save_count = old save_count + 1
	set_column_width (a_px: INTEGER)
		require
			in_range: a_px >= Min_width and a_px <= Max_width
		ensure
			set: column_width = a_px
			saved: save_count = old save_count + 1
	set_opacity (a_alpha: INTEGER)
		require
			in_range: a_alpha >= 0 and a_alpha <= 255
		ensure
			set: opacity = a_alpha
			saved: save_count = old save_count + 1
	set_speed_wpm (a_wpm: INTEGER)
		require
			in_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		ensure
			set: speed_wpm = a_wpm
			saved: save_count = old save_count + 1
	mark_tracking_proven
		ensure
			proven: is_tracking_proven
			saved: save_count = old save_count + 1
feature -- Element change (review L20)
	set_count_in_seconds (a_seconds: REAL_64)
		require
			in_range: a_seconds >= 0 and a_seconds <= 5
		ensure
			set: count_in_seconds = a_seconds
			saved: save_count = old save_count + 1
	set_pads (a_head, a_tail: REAL_64)
		require
			non_negative: a_head >= 0 and a_tail >= 0
			sane: a_head <= 2 and a_tail <= 2
		ensure
			set: head_pad = a_head and tail_pad = a_tail
			saved: save_count = old save_count + 1
	set_sessions_root (a_root: READABLE_STRING_32)
		ensure
			set: sessions_root.same_string (a_root)
			saved: save_count = old save_count + 1
	set_devices (a_camera, a_microphone: READABLE_STRING_32)
		require
			microphone_present: not a_microphone.is_empty
		ensure
			set: camera_name.same_string (a_camera) and microphone_name.same_string (a_microphone)
			saved: save_count = old save_count + 1
invariant
	font_range: font_size >= Min_font and font_size <= Max_font
	lines_range: lines_visible >= Min_lines and lines_visible <= Max_lines
	width_range: column_width >= Min_width and column_width <= Max_width
	opacity_range: opacity >= 0 and opacity <= 255
	wpm_range: speed_wpm >= Min_wpm and speed_wpm <= Max_wpm
	count_in_range: count_in_seconds >= 0 and count_in_seconds <= 5
	pads_non_negative: head_pad >= 0 and tail_pad >= 0
======== pt_aligner.e
class
	PT_ALIGNER
create
	make
feature {NONE} -- Initialization
	make (a_revision: PT_SCRIPT_REVISION; a_matcher: PT_WORD_MATCHER)
			-- Aligner over `a_revision', positioned before the first word.
		ensure
			revision_set: revision = a_revision
			matcher_set: matcher = a_matcher
			at_start: position = 0
			certain: confidence = 1.0
feature -- Constants
	Window_back: INTEGER = 3
	Window_ahead: INTEGER = 120
			-- Largest forward search (used when lost: e.g. after a skipped paragraph; real-voice replay).
	Normal_ahead: INTEGER = 40
			-- Forward search while tracking normally.
	Lost_after: INTEGER = 8
			-- Updates without an anchor (2 s at 250 ms) before the wide search is used.
	Recent_heard: INTEGER = 10
			-- Heard words aligned per update (6 was too few for function-word-heavy sentences:
			-- real-voice replay stuck at a closing paragraph; review of larry_read_01).
	Small_jump: INTEGER = 4
	Backward_evidence: INTEGER = 3
feature -- Access
	revision: PT_SCRIPT_REVISION
	matcher: PT_WORD_MATCHER
	position: INTEGER
			-- Words already read: the last word confirmed read (0 = none yet). The next word
			-- to read is position + 1 (one convention with PT_FOLLOWER.target, review H1).
	reanchored_at: INTEGER_64
			-- Sample-clock position of the last `reanchor'; decode windows starting before it
			-- are stale (review H3).
	confidence: REAL_64
			-- Confidence in `position', 0..1.
	last_alignment: PT_ALIGNMENT
			-- Estimate produced by the last `update' or `reanchor'.
	required_anchors (a_jump: INTEGER): INTEGER
			-- Anchored matches needed to move forward by `a_jump' words.
		require
			positive: a_jump > 0
		ensure
			tiers: Result >= 1 and Result <= 3
			small: a_jump <= Small_jump implies Result = 1
feature -- Element change
	update (a_heard: PT_HEARD_WORDS)
			-- Incorporate a decode result.
		ensure
			stale_ignored: a_heard.window_start < reanchored_at implies (position = old position and confidence = old confidence)
			within_script: position >= 0 and position <= revision.word_count
			window_bound: position <= old position + Window_ahead
			forward_bias: position < old position implies last_alignment.anchor_count >= Backward_evidence
			stop_words_inert: last_alignment.anchor_count = 0 implies position = old position
			jump_evidence: (position - old position) > Small_jump implies
					last_alignment.anchor_count >= required_anchors (position - old position)
			confidence_range: confidence >= 0.0 and confidence <= 1.0
			alignment_consistent: last_alignment.word_index = position
	reanchor (a_words_read: INTEGER; a_at_sample: INTEGER_64)
			-- Restart: `a_words_read' words count as read (caret k gives k - 1) as of sample `a_at_sample'.
		require
			valid: a_words_read >= 0 and a_words_read <= revision.word_count
			sample_non_negative: a_at_sample >= 0
		ensure
			placed: position = a_words_read
			certain: confidence = 1.0
			stamped: reanchored_at = a_at_sample
			alignment_consistent: last_alignment.word_index = a_words_read
invariant
	position_range: position >= 0 and position <= revision.word_count
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	reanchor_non_negative: reanchored_at >= 0
	constants_sane: Window_back >= 0 and Window_ahead >= 1 and Backward_evidence >= 2
======== pt_alignment.e
class
	PT_ALIGNMENT
create
	make
feature {NONE} -- Initialization
	make (a_word_index: INTEGER; a_confidence: REAL_64; a_matched_count, a_anchor_count: INTEGER;
			-- Reader at word `a_word_index' as of sample `a_sample_pos'.
		require
			index_non_negative: a_word_index >= 0
			confidence_range: a_confidence >= 0.0 and a_confidence <= 1.0
			counts_ordered: a_anchor_count >= 0 and a_anchor_count <= a_matched_count
			rate_non_negative: a_rate_wps >= 0
			position_non_negative: a_sample_pos >= 0
		ensure
			index_set: word_index = a_word_index
			confidence_set: confidence = a_confidence
			counts_set: matched_count = a_matched_count and anchor_count = a_anchor_count
			rate_set: rate_wps = a_rate_wps
			position_set: sample_pos = a_sample_pos
feature -- Access
	word_index: INTEGER
			-- Word the reader is on (0 = before the first word).
	confidence: REAL_64
			-- 0..1.
	matched_count: INTEGER
			-- Heard words matched to script words in the scored window.
	anchor_count: INTEGER
			-- Matched words that are not stop words (only these may move position).
	rate_wps: REAL_64
			-- Measured speaking rate, words per second.
	sample_pos: INTEGER_64
			-- Sample-clock position the estimate refers to.
feature -- Status
	is_anchored: BOOLEAN
			-- Did at least one non-stop word match?
invariant
	index_non_negative: word_index >= 0
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	counts_ordered: anchor_count >= 0 and anchor_count <= matched_count
	rate_non_negative: rate_wps >= 0
	position_non_negative: sample_pos >= 0
======== pt_clock.e
deferred class
	PT_CLOCK
feature -- Access
	now_ms: REAL_64
			-- Current time in milliseconds.
		deferred
		ensure
			non_negative: Result >= 0
======== pt_constant_follower.e
class
	PT_CONSTANT_FOLLOWER
inherit
	PT_FOLLOWER
create
	make
feature {NONE} -- Initialization
	make (a_word_count: INTEGER; a_wpm: INTEGER)
			-- Follower over `a_word_count' words at `a_wpm', held at the start.
		require
			words_non_negative: a_word_count >= 0
			wpm_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		ensure
			at_start: target = 0
			held_initially: is_held
			rate_set: words_per_second = a_wpm / 60.0
feature -- Constants
	Min_wpm: INTEGER = 40
	Max_wpm: INTEGER = 400
feature -- Access
	words_per_second: REAL_64
			-- Configured speed.
feature -- Input
	on_voice (a_frame: PT_VOICE_FRAME)
			-- Remember whether the reader is speaking (display only).
	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Ignored in constant mode.
feature -- Motion
	advance (a_dt_s: REAL_64)
			-- Move at the configured speed unless held.
		ensure then
			constant_rate: (not is_held and old target + words_per_second * a_dt_s <= word_count)
					implies (target - (old target + words_per_second * a_dt_s)).abs < 1.0e-9
feature -- Element change
	set_wpm (a_wpm: INTEGER)
			-- Change speed.
		require
			wpm_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		ensure
			rate_set: words_per_second = a_wpm / 60.0
			target_kept: target = old target
invariant
	rate_positive: words_per_second > 0
======== pt_decoder.e
deferred class
	PT_DECODER
feature -- Decoding
	decode (a_samples: SPECIAL [REAL_32]; a_count: INTEGER; a_window_start: INTEGER_64;
			-- Words heard in the first `a_count' samples of `a_samples', a window starting
			-- at sample `a_window_start'. `a_prompt' is text ALREADY spoken (never upcoming text).
		require
			count_valid: a_count > 0 and a_count <= a_samples.count
			start_non_negative: a_window_start >= 0
		deferred
		ensure
			window_kept: Result.window_start = a_window_start and Result.window_samples = a_count
			words_inside: across 1 |..| Result.count as i all Result.word (i).t1 <= a_count / 16_000 + 0.05 end
======== pt_equivalences.e
class
	PT_EQUIVALENCES
feature -- Queries
	are_equivalent (a_heard, a_script: READABLE_STRING_32): BOOLEAN
			-- Does heard `a_heard' (a word or short span) count as script word `a_script'?
		ensure
			reflexive: a_heard.same_string (a_script) implies Result
			homophones: same_homophone_class (a_heard, a_script) implies Result
			abbreviations: (is_spoken_form (a_heard, a_script) or is_spoken_form (a_script, a_heard)) implies Result
			compounds: joined (a_heard).same_string (joined (a_script)) implies Result
	homophone_class (a_word: READABLE_STRING_32): INTEGER
			-- Class number of `a_word' among the homophone sets, 0 if none.
		ensure
			non_negative: Result >= 0
	same_homophone_class (a, b: READABLE_STRING_32): BOOLEAN
	spoken_forms (a_written: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- How abbreviation `a_written' (normalized, e.g. "eg") may be spoken.
	is_spoken_form (a_heard, a_written: READABLE_STRING_32): BOOLEAN
			-- Is `a_heard' one of the spoken forms of `a_written'?
	number_value (a_word: READABLE_STRING_32): INTEGER
			-- Value of a digit string or a single number word (zero..twenty, tens), -1 otherwise.
		ensure
			minus_one_or_value: Result >= -1
	joined (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' without spaces and hyphens ("post condition" -> "postcondition").
		ensure
			no_spaces: not Result.has (' ')
			not_longer: Result.count <= a_text.count
	phonetic_key (a_word: READABLE_STRING_32): STRING_32
			-- Sound-alike key (Metaphone-style).
		ensure
			deterministic_length: Result.count <= a_word.count + 1
	Min_phonetic_length: INTEGER = 3
			-- Short keys collide too easily to count.
======== pt_fake_clock.e
class
	PT_FAKE_CLOCK
inherit
	PT_CLOCK
create
	make
feature {NONE} -- Initialization
	make
			-- Clock at time 0.
		ensure
			at_zero: now_ms = 0
feature -- Access
	now_ms: REAL_64
			-- Current time in milliseconds.
feature -- Element change
	advance (a_ms: REAL_64)
			-- Move time forward by `a_ms'.
		require
			non_negative: a_ms >= 0
		ensure
			advanced: now_ms = old now_ms + a_ms
	set (a_ms: REAL_64)
			-- Jump to `a_ms' (never backward).
		require
			not_backward: a_ms >= now_ms
		ensure
			set: now_ms = a_ms
invariant
	non_negative: now_ms >= 0
======== pt_fixed_measure.e
class
	PT_FIXED_MEASURE
inherit
	PT_TEXT_MEASURE
create
	make
feature {NONE} -- Initialization
	make (a_char_width, a_line_height: REAL_64)
			-- Every character is `a_char_width' wide; lines are `a_line_height' apart.
		require
			width_positive: a_char_width > 0
			height_positive: a_line_height > 0
		ensure
			width_set: char_width = a_char_width
			height_set: line_height = a_line_height
feature -- Access
	char_width: REAL_64
feature -- Measurement
	advance (a_text: READABLE_STRING_32): REAL_64
			-- `char_width' per character.
		ensure then
			fixed: Result = a_text.count * char_width
	space_advance: REAL_64
			-- One character.
	line_height: REAL_64
			-- Distance between baselines.
invariant
	width_positive: char_width > 0
	height_positive: line_height > 0
======== pt_follow_mode.e
class
	PT_FOLLOW_MODE
feature -- Constants
	Constant: INTEGER = 1
			-- Fixed speed, ignores the voice.
	Voice_gated: INTEGER = 2
			-- Fixed speed while VAD says speech.
	Tracking: INTEGER = 3
			-- Follows the spoken word (GPU ASR + aligner).
======== pt_follower.e
deferred class
	PT_FOLLOWER
feature -- Access
	target: REAL_64
			-- Words already read (fractional). The reader is on word floor (target) + 1; a
			-- restart at caret word k sets the target to k - 1 (one convention with
			-- PT_ALIGNER.position, review H1).
	velocity: REAL_64
			-- Words per second.
	word_count: INTEGER
			-- Words in the script being followed.
feature -- Status
	is_held: BOOLEAN
			-- Is motion frozen?
	caret_changed: BOOLEAN
			-- Did the last command move the target by caret (the only backward path)?
	is_speaking: BOOLEAN
			-- Did the last voice frame say speech?
feature -- Input
	on_voice (a_frame: PT_VOICE_FRAME)
			-- Take a VAD frame into account.
		deferred
		ensure
			position_untouched: target = old target
	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Take an aligner estimate into account.
		deferred
		ensure
			position_untouched: target = old target
feature -- Motion
	advance (a_dt_s: REAL_64)
			-- Move `a_dt_s' seconds forward in time.
		require
			non_negative: a_dt_s >= 0
		deferred
		ensure
			held_frozen: is_held implies target = old target
			never_backward: target >= old target
			end_clamped: target <= word_count
			velocity_non_negative: velocity >= 0
feature -- Control
	hold
			-- Freeze motion.
		ensure
			held: is_held
			stopped: velocity = 0
			target_kept: target = old target
	release
			-- Allow motion.
		ensure
			running: not is_held
			target_kept: target = old target
	set_caret (a_index: INTEGER)
			-- Set the words-read target to `a_index' (caret word k: `a_index' = k - 1).
			-- The only way to move backward.
		require
			valid: a_index >= 0 and a_index <= word_count
		ensure
			placed: target = a_index.to_double
			flagged: caret_changed
	rescale (a_word_count: INTEGER)
			-- The script was revised to `a_word_count' words; clamp the target.
		require
			non_negative: a_word_count >= 0
		ensure
			resized: word_count = a_word_count
			clamped: target = (old target).min (a_word_count)
invariant
	velocity_non_negative: velocity >= 0
	held_still: is_held implies velocity = 0
	target_range: target >= 0 and target <= word_count
	word_count_non_negative: word_count >= 0
======== pt_heard_word.e
class
	PT_HEARD_WORD
create
	make
feature {NONE} -- Initialization
	make (a_text, a_normalized: READABLE_STRING_32; a_t0, a_t1, a_probability: REAL_64)
			-- Heard `a_text' between `a_t0' and `a_t1' seconds into the window.
		require
			text_present: not a_text.is_empty
			times_ordered: a_t0 >= 0 and a_t0 <= a_t1
			probability_range: a_probability >= 0.0 and a_probability <= 1.0
		ensure
			text_set: text.same_string (a_text)
			normalized_set: normalized.same_string (a_normalized)
			times_set: t0 = a_t0 and t1 = a_t1
			probability_set: probability = a_probability
feature -- Access
	text: STRING_32
	normalized: STRING_32
	t0, t1: REAL_64
			-- Seconds relative to the decode window start.
	probability: REAL_64
invariant
	text_present: not text.is_empty
	times_ordered: t0 >= 0 and t0 <= t1
	probability_range: probability >= 0.0 and probability <= 1.0
======== pt_heard_words.e
class
	PT_HEARD_WORDS
create
	make
feature {NONE} -- Initialization
	make (a_window_start: INTEGER_64; a_window_samples: INTEGER; a_words: ITERABLE [PT_HEARD_WORD])
			-- Words heard in the window of `a_window_samples' starting at sample `a_window_start'.
		require
			start_non_negative: a_window_start >= 0
			window_positive: a_window_samples > 0
		ensure
			start_set: window_start = a_window_start
			size_set: window_samples = a_window_samples
feature -- Access
	window_start: INTEGER_64
			-- First sample of the decoded window.
	window_samples: INTEGER
			-- Window length in samples.
	count: INTEGER
			-- Number of words heard.
	word (a_index: INTEGER): PT_HEARD_WORD
			-- Word at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= count
	is_empty: BOOLEAN
			-- Was nothing heard?
	window_end: INTEGER_64
			-- One past the last sample of the window.
		ensure
			after_start: Result > window_start
feature -- Model
	normalized_model: MML_SEQUENCE [STRING_32]
			-- Normalized heard words, in order.
		ensure
			same_count: Result.count = count
invariant
	start_non_negative: window_start >= 0
	window_positive: window_samples > 0
======== pt_layout.e
class
	PT_LAYOUT
create
	make
feature {NONE} -- Initialization
	make
			-- Empty layout.
		ensure
			empty: line_count = 0 and word_count = 0
feature -- Access
	word_count: INTEGER
			-- Words laid out.
	width: REAL_64
			-- Column width used by the last `build'.
	line_height: REAL_64
			-- Line pitch used by the last `build'.
	line_count: INTEGER
	line (a_index: INTEGER): PT_LINE
		require
			valid_index: a_index >= 1 and a_index <= line_count
	line_of (a_word: INTEGER): INTEGER
			-- Line containing word `a_word'.
		require
			valid: a_word >= 1 and a_word <= word_count
		ensure
			contains: line (Result).contains (a_word)
	y_of (a_position: REAL_64): REAL_64
			-- Vertical offset that puts fractional word position `a_position' on the reading line.
		require
			in_range: a_position >= 0 and a_position <= word_count
		ensure
			non_negative: Result >= 0
feature -- Model
	line_starts_model: MML_SEQUENCE [INTEGER]
			-- First word of every line.
		ensure
			same_count: Result.count = line_count
feature -- Element change
	build (a_revision: PT_SCRIPT_REVISION; a_measure: PT_TEXT_MEASURE; a_width: REAL_64)
			-- Lay out `a_revision' in a column `a_width' pixels wide.
		require
			positive_width: a_width > 0
		ensure
			counted: word_count = a_revision.word_count
			covers: word_count > 0 implies
				(line_count > 0 and then (line (1).first_word = 1 and line (line_count).last_word = word_count))
			contiguous: across 2 |..| line_count as i all line (i).first_word = line (i - 1).last_word + 1 end
			fits_or_single: across 1 |..| line_count as i all
					line (i).width <= a_width or line (i).first_word = line (i).last_word end
invariant
	lines_fit_words: line_count <= word_count
	empty_consistent: word_count = 0 implies line_count = 0
======== pt_line.e
class
	PT_LINE
create
	make
feature {NONE} -- Initialization
	make (a_first_word, a_last_word: INTEGER; a_width, a_y: REAL_64)
			-- Line holding words `a_first_word'..`a_last_word'.
		require
			first_positive: a_first_word >= 1
			ordered: a_first_word <= a_last_word
			width_non_negative: a_width >= 0
			y_non_negative: a_y >= 0
		ensure
			span_set: first_word = a_first_word and last_word = a_last_word
			width_set: width = a_width
			y_set: y = a_y
feature -- Access
	first_word, last_word: INTEGER
	width: REAL_64
			-- Rendered width in pixels.
	y: REAL_64
			-- Top of the line in the column, pixels.
	word_count: INTEGER
	contains (a_word: INTEGER): BOOLEAN
invariant
	first_positive: first_word >= 1
	ordered: first_word <= last_word
	width_non_negative: width >= 0
	y_non_negative: y >= 0
======== pt_scripted_decoder.e
class
	PT_SCRIPTED_DECODER
inherit
	PT_DECODER
create
	make
feature {NONE} -- Initialization
	make
			-- Decoder with no scripted windows.
		ensure
			nothing_scripted: scripted_count = 0
feature -- Access
	scripted_count: INTEGER
	last_prompt: STRING_32
			-- Prompt of the most recent `decode' (test observation).
	decode_count: INTEGER
			-- Number of `decode' calls (test observation).
feature -- Element change
	script_window (a_window_start: INTEGER_64; a_words: ARRAY [STRING_32])
			-- When the window starting at `a_window_start' is decoded, hear `a_words'
			-- (spread evenly over the first second).
		require
			start_non_negative: a_window_start >= 0
			words_present: across a_words as ic all not ic.is_empty end
		ensure
			scripted: scripted_count >= old scripted_count
feature -- Decoding
	decode (a_samples: SPECIAL [REAL_32]; a_count: INTEGER; a_window_start: INTEGER_64;
			-- Scripted words for `a_window_start'.
======== pt_scripted_vad.e
class
	PT_SCRIPTED_VAD
inherit
	PT_VAD
create
	make
feature {NONE} -- Initialization
	make (a_probabilities: ARRAY [REAL_64])
			-- Frame n (0-based) has probability `a_probabilities' [lower + n].
		require
			all_in_range: across a_probabilities as ic all ic >= 0.0 and ic <= 1.0 end
		ensure
			set: probabilities = a_probabilities
feature -- Access
	probabilities: ARRAY [REAL_64]
feature -- Detection
	speech_probability (a_samples: SPECIAL [REAL_32]; a_offset: INTEGER; a_first_sample: INTEGER_64): REAL_64
			-- Scripted value for frame `a_first_sample' // Frame_samples.
======== pt_scroll_model.e
class
	PT_SCROLL_MODEL
create
	make
feature {NONE} -- Initialization
	make (a_follower: PT_FOLLOWER; a_layout: PT_LAYOUT; a_spring: PT_SPRING)
			-- Scroll driven by `a_follower', mapped by `a_layout', smoothed by `a_spring'.
		ensure
			follower_set: follower = a_follower
			layout_set: layout = a_layout
			spring_set: spring = a_spring
			at_start: position = 0 and last_ms = 0 and not is_started
feature -- Access
	follower: PT_FOLLOWER
	layout: PT_LAYOUT
	spring: PT_SPRING
	position: REAL_64
			-- Smoothed fractional word position.
	last_ms: REAL_64
			-- Clock time of the last `tick'.
	y_offset: REAL_64
			-- Vertical pixel offset for the renderer.
		require
			laid_out: position <= layout.word_count
		ensure
			non_negative: Result >= 0
feature -- Status
	is_started: BOOLEAN
			-- Has the first tick set the time base?
feature -- Element change
	tick (a_now_ms: REAL_64)
			-- Advance the follower and the smoothing to clock time `a_now_ms'.
		require
			not_backward: is_started implies a_now_ms >= last_ms
		ensure
			time_kept: last_ms = a_now_ms
			started: is_started
			snaps_back: follower.target < old position implies position = follower.target
			forward_otherwise: follower.target >= old position implies
					(position >= old position - 1.0e-9 and position <= follower.target + 1.0e-9)
			bounded: position >= 0 and position <= follower.word_count
	jump_to (a_position: REAL_64)
			-- Snap to `a_position' with no smoothing (after a caret change).
		require
			in_range: a_position >= 0 and a_position <= follower.word_count
		ensure
			placed: position = a_position
invariant
	position_non_negative: position >= 0
	time_non_negative: last_ms >= 0
======== pt_speech_codec.e
class
	PT_SPEECH_CODEC
create
	make
feature {NONE} -- Initialization
	make
		ensure
			nothing_decoded: last_frame = Void and last_heard = Void
feature -- Encoding
	encode_frame (a_frame: PT_VOICE_FRAME): STRING_8
		ensure
			tagged: Result.starts_with ("F|")
			one_line: not Result.has ('%N')
	encode_heard (a_heard: PT_HEARD_WORDS): STRING_8
		ensure
			tagged: Result.starts_with ("H|")
			one_line: not Result.has ('%N')
feature -- Decoding
	decode (a_record: READABLE_STRING_8)
			-- Set `last_frame' or `last_heard' (the other becomes Void); both Void on a bad record.
		ensure
			at_most_one: not (attached last_frame and attached last_heard)
	last_frame: detachable PT_VOICE_FRAME
	last_heard: detachable PT_HEARD_WORDS
======== pt_speech_pipeline.e
class
	PT_SPEECH_PIPELINE
create
	make
feature {NONE} -- Initialization
	make (a_vad: PT_VAD; a_decoder: PT_DECODER)
			-- Pipeline using `a_vad' and `a_decoder'; decoding enabled.
		ensure
			vad_set: vad = a_vad
			decoder_set: decoder = a_decoder
			fresh: samples_seen = 0 and pending_frame_count = 0 and pending_heard_count = 0
			decoding: is_decoding_enabled
feature -- Constants
	Sample_rate: INTEGER = 16_000
	Frame_samples: INTEGER = 512
	Step_samples: INTEGER = 4_000
			-- 250 ms between decodes.
	Window_samples: INTEGER = 48_000
			-- 3 s decode window.
	Hangover_frames: INTEGER = 8
			-- Frames of silence (256 ms) before speech is considered over.
	Default_threshold: REAL_64 = 0.5
feature -- Access
	vad: PT_VAD
	decoder: PT_DECODER
	threshold: REAL_64
			-- Speech probability threshold.
	prompt: STRING_32
			-- Already-read script text given to the decoder (never upcoming text).
	samples_seen: INTEGER_64
			-- Samples pushed so far: the recording clock (rt = samples_seen / Sample_rate).
	pending_frame_count: INTEGER
	pending_heard_count: INTEGER
	pending_frame (a_index: INTEGER): PT_VOICE_FRAME
		require
			valid_index: a_index >= 1 and a_index <= pending_frame_count
	pending_heard (a_index: INTEGER): PT_HEARD_WORDS
		require
			valid_index: a_index >= 1 and a_index <= pending_heard_count
feature -- Status
	is_decoding_enabled: BOOLEAN
			-- Decode windows (Tracking mode)? Voice-gated mode needs frames only.
	is_in_speech: BOOLEAN
			-- Is speech current (within the hangover)?
	last_push_had_speech: BOOLEAN
			-- Was speech current at any point during the last `push' (or just before it)?
feature -- Element change
	push (a_samples: SPECIAL [REAL_32]; a_count: INTEGER)
			-- Consume the first `a_count' samples of `a_samples'.
		require
			count_valid: a_count >= 0 and a_count <= a_samples.count
		ensure
			clock_advanced: samples_seen = old samples_seen + a_count
			frames_emitted: pending_frame_count = old pending_frame_count +
					(samples_seen // Frame_samples - old samples_seen // Frame_samples).to_integer_32
			decodes_bounded: pending_heard_count <= old pending_heard_count +
					(samples_seen // Step_samples - old samples_seen // Step_samples).to_integer_32
			no_decode_when_disabled: not is_decoding_enabled implies pending_heard_count = old pending_heard_count
			decode_only_in_speech: pending_heard_count > old pending_heard_count implies last_push_had_speech
	set_prompt (a_text: READABLE_STRING_32)
			-- Already-read text for the next decodes (I-003; spike gotcha 2: never upcoming text).
		ensure
			set: prompt.same_string (a_text)
	set_threshold (a_threshold: REAL_64)
		require
			range: a_threshold > 0.0 and a_threshold < 1.0
		ensure
			set: threshold = a_threshold
	enable_decoding
		ensure
			enabled: is_decoding_enabled
	disable_decoding
		ensure
			disabled: not is_decoding_enabled
	clear_pending
			-- Forget emitted frames and decode results (after the consumer has read them).
		ensure
			cleared: pending_frame_count = 0 and pending_heard_count = 0
			clock_kept: samples_seen = old samples_seen
invariant
	threshold_range: threshold > 0.0 and threshold < 1.0
	clock_non_negative: samples_seen >= 0
	ring_sized: ring.count = Window_samples
	step_divides_window: Window_samples \\ Step_samples = 0
======== pt_spring.e
class
	PT_SPRING
create
	make
feature {NONE} -- Initialization
	make (a_omega: REAL_64)
			-- Spring with angular frequency `a_omega' (1/s); higher = snappier.
		require
			positive: a_omega > 0
		ensure
			omega_set: omega = a_omega
			at_rest: value = 0 and rate = 0
feature -- Access
	omega: REAL_64
	value: REAL_64
	rate: REAL_64
			-- d(value)/dt.
feature -- Element change
	step (a_target, a_dt_s: REAL_64)
			-- Advance `a_dt_s' seconds toward `a_target'.
		require
			non_negative: a_dt_s >= 0
		ensure
			no_time_no_move: a_dt_s = 0 implies value = old value
			not_farther: (a_target - value).abs <= (a_target - old value).abs + 1.0e-9
			no_overshoot: (old value <= a_target implies value <= a_target + 1.0e-9) and
					(old value >= a_target implies value >= a_target - 1.0e-9)
	reset (a_value: REAL_64)
			-- Jump to `a_value' at rest.
		ensure
			placed: value = a_value
			at_rest: rate = 0
invariant
	omega_positive: omega > 0
======== pt_text_measure.e
deferred class
	PT_TEXT_MEASURE
feature -- Measurement
	advance (a_text: READABLE_STRING_32): REAL_64
			-- Horizontal advance of `a_text' in pixels.
		deferred
		ensure
			non_negative: Result >= 0
			empty_is_zero: a_text.is_empty implies Result = 0
	space_advance: REAL_64
			-- Advance of one space.
		deferred
		ensure
			positive: Result > 0
	line_height: REAL_64
			-- Distance between baselines.
		deferred
		ensure
			positive: Result > 0
======== pt_tracking_follower.e
class
	PT_TRACKING_FOLLOWER
inherit
	PT_FOLLOWER
		redefine
			set_caret
		end
create
	make
feature {NONE} -- Initialization
	make (a_word_count: INTEGER; a_fallback_wpm: INTEGER)
			-- Follower over `a_word_count' words; `a_fallback_wpm' until the first alignment.
		require
			words_non_negative: a_word_count >= 0
			wpm_range: a_fallback_wpm >= 40 and a_fallback_wpm <= 400
		ensure
			at_start: target = 0
			held_initially: is_held
			fallback_set: fallback_rate = a_fallback_wpm / 60.0
feature -- Constants
	Coast_limit: REAL_64 = 1.5
	Min_rate: REAL_64 = 1.0
	Max_rate_factor: REAL_64 = 1.6
	Steer_gain: REAL_64 = 1.5
			-- Extra words per second per word of lag behind the aligned word.
feature -- Access
	fallback_rate: REAL_64
			-- Words per second used before the first alignment.
	measured_rate: REAL_64
			-- Speaking rate from alignments (words per second).
	aligned_word: INTEGER
			-- Word index of the latest anchored alignment.
	seconds_since_anchor: REAL_64
			-- Time since the latest anchored alignment.
	has_alignment: BOOLEAN
			-- Has an anchored alignment arrived since the last caret change?
feature -- Input
	on_voice (a_frame: PT_VOICE_FRAME)
			-- Remember whether the reader is speaking.
	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Adopt an anchored estimate as the steering goal.
feature -- Motion
	advance (a_dt_s: REAL_64)
			-- Steer toward the aligned word at the measured rate; coast, then hold.
		ensure then
			coast_limited: (has_alignment and seconds_since_anchor > Coast_limit) implies velocity = 0
			rate_capped: velocity <= Max_rate_factor * measured_rate.max (Min_rate)
			clock_runs: seconds_since_anchor = old seconds_since_anchor + a_dt_s
feature -- Control
	set_caret (a_index: INTEGER)
			-- Restart: forget the old alignment; steer from the caret.
invariant
	rates_positive: fallback_rate > 0 and measured_rate > 0
	aligned_in_script: aligned_word >= 0 and aligned_word <= word_count
	clock_non_negative: seconds_since_anchor >= 0
======== pt_vad.e
deferred class
	PT_VAD
feature -- Constants
	Frame_samples: INTEGER = 512
			-- 32 ms at 16 kHz.
feature -- Detection
	speech_probability (a_samples: SPECIAL [REAL_32]; a_offset: INTEGER; a_first_sample: INTEGER_64): REAL_64
			-- Probability that the frame `a_samples' [a_offset .. a_offset + Frame_samples - 1],
			-- which starts at sample `a_first_sample' of the recording, is speech.
		require
			frame_inside: a_offset >= 0 and a_offset + Frame_samples <= a_samples.count
			position_non_negative: a_first_sample >= 0
		deferred
		ensure
			probability_range: Result >= 0.0 and Result <= 1.0
======== pt_voice_frame.e
class
	PT_VOICE_FRAME
create
	make
feature {NONE} -- Initialization
	make (a_sample_pos: INTEGER_64; a_level, a_speech_probability: REAL_64; a_is_speech: BOOLEAN)
			-- Frame starting at sample `a_sample_pos'.
		require
			position_non_negative: a_sample_pos >= 0
			level_range: a_level >= 0.0 and a_level <= 1.0
			probability_range: a_speech_probability >= 0.0 and a_speech_probability <= 1.0
		ensure
			position_set: sample_pos = a_sample_pos
			level_set: level = a_level
			probability_set: speech_probability = a_speech_probability
			decision_set: is_speech = a_is_speech
feature -- Access
	sample_pos: INTEGER_64
			-- First sample of the frame on the 16 kHz recording clock.
	level: REAL_64
			-- RMS level, 0..1 (drives the glow).
	speech_probability: REAL_64
			-- VAD probability that the frame is speech.
	is_speech: BOOLEAN
			-- VAD decision (probability against the pipeline threshold, with hangover).
	seconds: REAL_64
			-- Frame start in seconds.
		ensure
			non_negative: Result >= 0
invariant
	position_non_negative: sample_pos >= 0
	level_range: level >= 0.0 and level <= 1.0
	probability_range: speech_probability >= 0.0 and speech_probability <= 1.0
======== pt_voice_gated_follower.e
class
	PT_VOICE_GATED_FOLLOWER
inherit
	PT_FOLLOWER
create
	make
feature {NONE} -- Initialization
	make (a_word_count: INTEGER; a_wpm: INTEGER)
			-- Follower over `a_word_count' words at `a_wpm', held at the start.
		require
			words_non_negative: a_word_count >= 0
			wpm_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		ensure
			at_start: target = 0
			held_initially: is_held
			rate_set: words_per_second = a_wpm / 60.0
feature -- Constants
	Min_wpm: INTEGER = 40
	Max_wpm: INTEGER = 400
	Ramp_up_s: REAL_64 = 0.15
	Ramp_down_s: REAL_64 = 0.20
feature -- Access
	words_per_second: REAL_64
			-- Speed while speaking.
feature -- Status
	ramp_finished: BOOLEAN
			-- Has velocity reached its gated goal (full speed while speaking, 0 while silent)?
feature -- Input
	on_voice (a_frame: PT_VOICE_FRAME)
			-- Gate on the VAD decision.
	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Ignored in voice-gated mode.
feature -- Motion
	advance (a_dt_s: REAL_64)
			-- Ramp velocity toward the gate's goal, then move.
		ensure then
			silent_stops: (not is_speaking and ramp_finished) implies velocity = 0
			speed_capped: velocity <= words_per_second
invariant
	rate_positive: words_per_second > 0
======== pt_word_matcher.e
class
	PT_WORD_MATCHER
inherit
	ANY
		redefine
			default_create
		end
create
	default_create
feature {NONE} -- Initialization
	default_create
			-- Matcher with the standard equivalence tables.
feature -- Access
	equivalences: PT_EQUIVALENCES
			-- Homophones, spoken abbreviations, number words, compounds, phonetics (review H7).
feature -- Constants
	Max_distance: INTEGER = 2
			-- Largest edit distance ever tolerated.
feature -- Queries
	distance (a, b: READABLE_STRING_32): INTEGER
			-- Bounded Levenshtein distance; computation stops at `Max_distance' + 1.
		ensure
			non_negative: Result >= 0
			zero_iff_equal: (Result = 0) = a.same_string (b)
			bounded: Result <= Max_distance + 1
	allowed_distance (a_length: INTEGER): INTEGER
			-- Edit distance tolerated for a script word of `a_length' characters.
		require
			non_negative: a_length >= 0
		ensure
			short_strict: a_length <= 4 implies Result = 0
			medium: (a_length >= 5 and a_length <= 7) implies Result = 1
			long: a_length >= 8 implies Result = 2
			within_max: Result <= Max_distance
	is_stem_variant (a_heard, a_script: READABLE_STRING_32): BOOLEAN
			-- Do `a_heard' and `a_script' differ only by a common English suffix (s, es, ed, ing)?
		ensure
			equal_is_not_variant: a_heard.same_string (a_script) implies not Result
	matches (a_heard: READABLE_STRING_32; a_script: PT_WORD): BOOLEAN
			-- Does heard word `a_heard' match script word `a_script'?
		ensure
			exact_matches: (a_heard.same_string (a_script.normalized) and not a_script.is_cue) implies Result
			equivalent_matches: (not a_script.is_cue and equivalences.are_equivalent (a_heard, a_script.normalized)) implies Result
			cue_never: a_script.is_cue implies not Result
			tolerance: Result implies (distance (a_heard, a_script.normalized) <= allowed_distance (a_script.normalized.count)
					or is_stem_variant (a_heard, a_script.normalized)
					or equivalences.are_equivalent (a_heard, a_script.normalized))
======== pt_analysis_codec.e
class
	PT_ANALYSIS_CODEC
create
	make
feature {NONE} -- Initialization
	make
		ensure
			nothing_decoded: not last_analysis.is_success
feature -- Access
	last_analysis: PT_ANALYSIS
feature -- Conversion
	encode (a_analysis: PT_ANALYSIS): STRING_8
		ensure
			object: Result.starts_with ("{") and Result.ends_with ("}")
	decode (a_json: READABLE_STRING_8)
			-- Parse into `last_analysis' (a failed analysis carries the parse error).
======== pt_caption_builder.e
class
	PT_CAPTION_BUILDER
create
	make
feature {NONE} -- Initialization
	make
		ensure
			empty: last_cues.is_empty
feature -- Constants
	Max_cue_chars: INTEGER = 84
			-- Two lines of 42.
	Max_cue_seconds: REAL_64 = 6.0
feature -- Access
	last_cues: ARRAYED_LIST [PT_CAPTION_CUE]
	timecode: PT_TIMECODE
feature -- Basic operations
	build (a_final: PT_SCRIPT_REVISION; a_cuts: PT_CUT_LIST; a_timeline: PT_WORD_TIMELINE)
			-- Cues covering the words of `a_cuts'.
		ensure
			ordered_non_overlapping: across 2 |..| last_cues.count as i all last_cues [i].t0 >= last_cues [i - 1].t1 end
			text_is_final_script: (concatenated_ids (last_cues) |=| a_cuts.words_model)
			within_output: across last_cues as ic all ic.t1 <= a_cuts.output_duration + 0.001 end
			cue_limits: across last_cues as ic all ic.text.count <= Max_cue_chars and ic.t1 - ic.t0 <= Max_cue_seconds end
feature -- Rendering
	srt_text (a_cues: LIST [PT_CAPTION_CUE]): STRING_8
			-- SubRip document (UTF-8).
		ensure
			numbered: a_cues.is_empty or else Result.starts_with ("1%N")
	vtt_text (a_cues: LIST [PT_CAPTION_CUE]): STRING_8
			-- WebVTT document (UTF-8).
		ensure
			header: Result.starts_with ("WEBVTT")
feature -- Contract helpers
	concatenated_ids (a_cues: LIST [PT_CAPTION_CUE]): MML_SEQUENCE [PT_WORD_ID]
			-- All cue word ids, in order.
======== pt_caption_cue.e
class
	PT_CAPTION_CUE
create
	make
feature {NONE} -- Initialization
	make (a_t0, a_t1: REAL_64; a_text: READABLE_STRING_32; a_word_ids: ITERABLE [PT_WORD_ID])
		require
			times_ordered: a_t0 >= 0 and a_t0 < a_t1
			text_present: not a_text.is_empty
		ensure
			times_set: t0 = a_t0 and t1 = a_t1
			text_set: text.same_string (a_text)
feature -- Access
	t0, t1: REAL_64
	text: STRING_32
	word_ids: ARRAYED_LIST [PT_WORD_ID]
invariant
	times_ordered: t0 >= 0 and t0 < t1
	text_present: not text.is_empty
======== pt_chapter_writer.e
class
	PT_CHAPTER_WRITER
create
	make
feature {NONE} -- Initialization
	make
feature -- Access
	timecode: PT_TIMECODE
feature -- Rendering
	text (a_final: PT_SCRIPT_REVISION; a_cuts: PT_CUT_LIST; a_timeline: PT_WORD_TIMELINE; a_journal: PT_JOURNAL): STRING_32
			-- One "M:SS Title" line per chapter.
		ensure
			starts_at_zero: (a_final.section_count > 0 and a_cuts.count > 0) implies Result.starts_with ({STRING_32} "0:00 ")
======== pt_cut_codec.e
class
	PT_CUT_CODEC
create
	make
feature {NONE} -- Initialization
	make
		ensure
			nothing_decoded: not has_cuts and last_error = Void
feature -- Access
	last_cuts: PT_CUT_LIST
	last_error: detachable STRING_32
	has_cuts: BOOLEAN
feature -- Conversion
	encode (a_cuts: PT_CUT_LIST): STRING_8
			-- JSON document for `a_cuts'.
		ensure
			object: Result.starts_with ("{") and Result.ends_with ("}")
	decode (a_json: READABLE_STRING_8)
			-- Parse `a_json' into `last_cuts', or set `last_error'.
		ensure
			outcome: has_cuts xor attached last_error
feature -- Conversion helpers (shared with PT_ANALYSIS_CODEC)
	cuts_object (a_cuts: PT_CUT_LIST): SIMPLE_JSON_OBJECT
			-- {"intervals":[{"src","in","out","words":[ids],"first","last","attempt","tight"}]}.
	read_cuts (a_object: SIMPLE_JSON_OBJECT)
			-- Fill `last_cuts' from `a_object', or set `last_error'.
======== pt_edl_writer.e
class
	PT_EDL_WRITER
create
	make
feature {NONE} -- Initialization
	make
feature -- Access
	timecode: PT_TIMECODE
feature -- Rendering
	write (a_cuts: PT_CUT_LIST; a_fps: INTEGER; a_title, a_reel: READABLE_STRING_8): STRING_8
			-- EDL text.
		require
			fps_positive: a_fps > 0
			title_present: not a_title.is_empty
			reel_present: not a_reel.is_empty
		ensure
			header: Result.starts_with ("TITLE:")
			one_event_per_cut: event_lines (Result) = a_cuts.count
	event_number (a_index: INTEGER): STRING_8
			-- Three-digit event number.
	reel_field (a_reel: READABLE_STRING_8): STRING_8
			-- Reel name padded or cut to eight characters.
	record_in (a_cuts: PT_CUT_LIST; a_index: INTEGER): REAL_64
			-- Output time where cut `a_index' starts.
	event_lines (a_edl: READABLE_STRING_8): INTEGER
			-- Lines starting with a three-digit event number.
======== pt_review_srt_writer.e
class
	PT_REVIEW_SRT_WRITER
create
	make
feature {NONE} -- Initialization
	make
feature -- Constants
	Cue_seconds: REAL_64 = 2.0
			-- Display length of a mark without a natural end.
feature -- Access
	timecode: PT_TIMECODE
	shown_count (a_journal: PT_JOURNAL): INTEGER
			-- Marks that become cues: flub, hold, rewind_to, edit, star, reject, marker, skip, wrap, abort.
	is_shown (a_kind: INTEGER): BOOLEAN
feature -- Rendering
	text (a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY): STRING_8
			-- review.srt document (UTF-8).
		ensure
			one_cue_per_mark: cue_count (Result) = shown_count (a_journal)
	description (a_event: PT_TAKE_EVENT; a_history: PT_SCRIPT_HISTORY): STRING_32
			-- Human-readable text for a shown mark.
	word_text (a_id: PT_WORD_ID; a_history: PT_SCRIPT_HISTORY): STRING_32
			-- Text of word `a_id' in the newest revision that has it.
	safe (a_text: READABLE_STRING_32): STRING_8
			-- UTF-8 of `a_text' with cue separators and line breaks neutralized.
		ensure
			no_separator: not Result.has_substring (" --> ")
	cue_count (a_srt: READABLE_STRING_8): INTEGER
			-- Number of " --> " separators.
======== pt_timecode.e
class
	PT_TIMECODE
feature -- Formatting
	srt (a_seconds: REAL_64): STRING_8
			-- "HH:MM:SS,mmm".
		require
			non_negative: a_seconds >= 0
			below_100_hours: a_seconds < 360_000
		ensure
			shape: Result.count = 12 and Result [9] = ','
			round_trip: (seconds_of_srt (Result) - a_seconds).abs <= 0.0005
	vtt (a_seconds: REAL_64): STRING_8
			-- "HH:MM:SS.mmm".
		require
			non_negative: a_seconds >= 0
			below_100_hours: a_seconds < 360_000
		ensure
			shape: Result.count = 12 and Result [9] = '.'
	chapter (a_seconds: REAL_64): STRING_8
			-- YouTube chapter time: "M:SS" under an hour, else "H:MM:SS" (whole seconds, truncated).
		require
			non_negative: a_seconds >= 0
		ensure
			zero_is_0_00: a_seconds < 1 implies Result.same_string ("0:00")
	edl (a_seconds: REAL_64; a_fps: INTEGER): STRING_8
			-- "HH:MM:SS:FF" at `a_fps' frames per second (frames rounded).
		require
			non_negative: a_seconds >= 0
			fps_positive: a_fps > 0
		ensure
			shape: Result.count = 11
feature -- Parsing
	seconds_of_srt (a_code: READABLE_STRING_8): REAL_64
			-- Seconds denoted by "HH:MM:SS,mmm" (or with '.').
		require
			shape: a_code.count = 12 and a_code [3] = ':' and a_code [6] = ':' and (a_code [9] = ',' or a_code [9] = '.')
			digits: is_digits (a_code.substring (1, 2)) and is_digits (a_code.substring (4, 5))
					and is_digits (a_code.substring (7, 8)) and is_digits (a_code.substring (10, 12))
		ensure
			non_negative: Result >= 0
	is_digits (a_text: READABLE_STRING_8): BOOLEAN
======== pt_capture_plan.e
class
	PT_CAPTURE_PLAN
create
	make_recording, make_audio_only
feature {NONE} -- Initialization
	make_recording (a_ffmpeg: READABLE_STRING_32; a_devices: PT_DEVICE_CHOICE; a_raw_path, a_tee_path: READABLE_STRING_32)
			-- Camera + microphone recording with tee.
		require
			ffmpeg_present: not a_ffmpeg.is_empty
			has_camera: a_devices.has_camera
			raw_present: not a_raw_path.is_empty
			tee_present: not a_tee_path.is_empty
		ensure
			recording: not is_audio_only
	make_audio_only (a_ffmpeg: READABLE_STRING_32; a_devices: PT_DEVICE_CHOICE; a_tee_path: READABLE_STRING_32)
			-- Microphone only, tee file only (practice mode).
		require
			ffmpeg_present: not a_ffmpeg.is_empty
			tee_present: not a_tee_path.is_empty
		ensure
			audio_only: is_audio_only
feature -- Constants
	Tee_rate: INTEGER = 16_000
	Gop_frames: INTEGER = 30
	Audio_buffer_ms: INTEGER = 50
			-- dshow audio device buffer; the device default can be large and adds directly
			-- to tee latency (review H6; measure in spike T-0).
feature -- Access
	ffmpeg: STRING_32
	devices: PT_DEVICE_CHOICE
	raw_path: STRING_32
	tee_path: STRING_32
	arguments: ARRAYED_LIST [STRING_32]
			-- Arguments after the ffmpeg executable.
		ensure
			dshow_input: has_pair (Result, "-f", "dshow")
			small_audio_buffer: has_pair (Result, "-audio_buffer_size", Audio_buffer_ms.out)
			mjpeg_when_recording: not is_audio_only implies has_pair (Result, "-vcodec", "mjpeg")
			pcm_when_recording: not is_audio_only implies has_pair (Result, "-c:a", "pcm_s16le")
			raw_when_recording: not is_audio_only implies across Result as ic some ic.same_string (raw_path) end
			no_raw_in_practice: is_audio_only implies not has_pair (Result, "-c:v", "h264_nvenc")
			tee_format: has_pair (Result, "-f", "f32le") and has_pair (Result, "-ar", "16000") and has_pair (Result, "-ac", "1")
			tee_flushed: has_pair (Result, "-flush_packets", "1")
			tee_last: Result.last.same_string (tee_path)
feature -- Status
	is_audio_only: BOOLEAN
	has_pair (a_args: LIST [STRING_32]; a_flag, a_value: READABLE_STRING_GENERAL): BOOLEAN
			-- Does `a_flag' appear immediately followed by `a_value'?
invariant
	raw_iff_recording: is_audio_only = raw_path.is_empty
	tee_present: not tee_path.is_empty
======== pt_device_choice.e
class
	PT_DEVICE_CHOICE
create
	make, make_default
feature {NONE} -- Initialization
	make (a_camera, a_microphone: READABLE_STRING_32; a_width, a_height, a_fps: INTEGER)
		require
			microphone_present: not a_microphone.is_empty
			size_positive: a_width > 0 and a_height > 0
			fps_range: a_fps >= 1 and a_fps <= 120
		ensure
			devices_set: camera.same_string (a_camera) and microphone.same_string (a_microphone)
			mode_set: width = a_width and height = a_height and fps = a_fps
	make_default
			-- Decided defaults (Larry, 2026-10-05: "use defaults").
feature -- Access
	camera: STRING_32
			-- dshow video device name (empty = audio only).
	microphone: STRING_32
			-- dshow audio device name.
	width, height, fps: INTEGER
feature -- Status
	has_camera: BOOLEAN
invariant
	microphone_present: not microphone.is_empty
	size_positive: width > 0 and height > 0
	fps_range: fps >= 1 and fps <= 120
======== pt_preflight.e
class
	PT_PREFLIGHT
create
	make
feature {NONE} -- Initialization
	make
		ensure
			no_problems: problems.is_empty
feature -- Constants
	Margin_minutes: INTEGER = 10
feature -- Access
	problems: ARRAYED_LIST [STRING_32]
			-- Human-readable problems from the last `check_ready'.
	required_bytes (a_bitrate_bps: INTEGER_64; a_minutes: INTEGER): INTEGER_64
			-- Disk needed for `a_minutes' plus the margin at `a_bitrate_bps'.
		require
			bitrate_positive: a_bitrate_bps > 0
			minutes_non_negative: a_minutes >= 0
		ensure
			positive: Result > 0
feature -- Status
	is_ready: BOOLEAN
feature -- Basic operations
	check_ready (a_ffmpeg_found, a_devices_present, a_model_needed, a_model_found: BOOLEAN;
			-- Evaluate readiness.
		require
			free_non_negative: a_free_bytes >= 0
			bitrate_positive: a_bitrate_bps > 0
			minutes_non_negative: a_minutes >= 0
		ensure
			ready_iff_no_problems: is_ready = problems.is_empty
			ffmpeg_reported: not a_ffmpeg_found implies not is_ready
			disk_reported: a_free_bytes < required_bytes (a_bitrate_bps, a_minutes) implies not is_ready
======== pt_recorder_health.e
class
	PT_RECORDER_HEALTH
create
	make
feature {NONE} -- Initialization
	make (a_alive: BOOLEAN; a_tee_bytes_per_s, a_drop_ratio: REAL_64; a_last_error: detachable READABLE_STRING_32)
		require
			rate_non_negative: a_tee_bytes_per_s >= 0
			drop_range: a_drop_ratio >= 0.0 and a_drop_ratio <= 1.0
		ensure
			alive_set: is_alive = a_alive
			rate_set: tee_bytes_per_s = a_tee_bytes_per_s
			drop_set: drop_ratio = a_drop_ratio
feature -- Constants
	Drop_warning: REAL_64 = 0.005
	Expected_bytes_per_s: REAL_64 = 64_000.0
feature -- Access
	tee_bytes_per_s: REAL_64
	drop_ratio: REAL_64
	last_error: detachable STRING_32
feature -- Status
	is_alive: BOOLEAN
	is_stalled: BOOLEAN
			-- Alive but the tee is not flowing.
	needs_drop_warning: BOOLEAN
invariant
	rate_non_negative: tee_bytes_per_s >= 0
	drop_range: drop_ratio >= 0.0 and drop_ratio <= 1.0
======== pt_render_plan.e
class
	PT_RENDER_PLAN
create
	make
feature {NONE} -- Initialization
	make (a_ffmpeg: READABLE_STRING_32; a_fade_ms: INTEGER; a_punch_in: BOOLEAN)
		require
			ffmpeg_present: not a_ffmpeg.is_empty
			fade_range: a_fade_ms >= 0 and a_fade_ms <= 200
		ensure
			fade_set: fade_ms = a_fade_ms
			punch_set: is_punch_in = a_punch_in
feature -- Access
	ffmpeg: STRING_32
	fade_ms: INTEGER
			-- 20 ms by default (spike).
	is_punch_in: BOOLEAN
			-- Alternate 100% / 108% zoom at joints (default off: plain cuts decided).
feature -- Rendering
	filter_script (a_cuts: PT_CUT_LIST): STRING_8
			-- filter_complex graph for `a_cuts' (single source, input 0).
		require
			non_empty: a_cuts.count >= 1
		ensure
			trims: occurrences (Result, "]trim=") = a_cuts.count and occurrences (Result, "]atrim=") = a_cuts.count
			one_concat: occurrences (Result, "concat=n=" + a_cuts.count.out) = 1
			fades_at_joints: fade_ms > 0 implies occurrences (Result, "afade=") = 2 * a_cuts.count - 2
	arguments (a_input, a_script_path, a_output: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- Arguments after the ffmpeg executable.
		ensure
			output_last: not Result.is_empty implies Result.last.same_string_general (a_output)
feature -- Formatting
	seconds (a_value: REAL_64): STRING_8
			-- `a_value' with exactly three decimals ("4.200").
		require
			non_negative: a_value >= 0
		ensure
			three_decimals: Result.count >= 5 and Result [Result.count - 3] = '.'
feature -- Contract helpers
	occurrences (a_text, a_part: READABLE_STRING_8): INTEGER
			-- Non-overlapping occurrences of `a_part' in `a_text'.
		require
			part_present: not a_part.is_empty
invariant
	fade_range: fade_ms >= 0 and fade_ms <= 200
======== pt_id_source.e
class
	PT_ID_SOURCE
create
	make, make_after
feature {NONE} -- Initialization
	make
			-- Fresh source; the first issued id will be 1.
		ensure
			nothing_issued: last_issued = 0
	make_after (a_last: INTEGER_64)
			-- Source resuming after `a_last' (session recovery).
		require
			non_negative: a_last >= 0
		ensure
			resumed: last_issued = a_last
feature -- Access
	last_issued: INTEGER_64
			-- Most recently issued id value (0 = none yet).
	last_id: PT_WORD_ID
			-- Most recently issued id.
		require
			issued: last_issued > 0
		ensure
			matches: Result.value = last_issued
feature -- Element change
	issue
			-- Issue the next id; read it with `last_id'.
		ensure
			incremented: last_issued = old last_issued + 1
invariant
	non_negative: last_issued >= 0
======== pt_normalizer.e
class
	PT_NORMALIZER
feature -- Conversion
	normalized (a_text: READABLE_STRING_32): STRING_32
			-- Normal form of `a_text': lowercase letters and digits, plus an apostrophe
			-- between letters (don't, they're); typographic apostrophes count as an apostrophe.
		ensure
			not_longer: Result.count <= a_text.count
			no_upper: Result.same_string (Result.as_lower)
			no_spaces: not Result.has (' ')
======== pt_passage.e
class
	PT_PASSAGE
create
	make
feature {NONE} -- Initialization
	make (a_index, a_first_word, a_last_word, a_paragraph, a_section: INTEGER)
			-- Passage `a_index' covering words `a_first_word'..`a_last_word'.
		require
			index_positive: a_index >= 1
			first_positive: a_first_word >= 1
			ordered: a_first_word <= a_last_word
			paragraph_positive: a_paragraph >= 1
			section_non_negative: a_section >= 0
		ensure
			index_set: index = a_index
			span_set: first_word = a_first_word and last_word = a_last_word
			structure_set: paragraph_index = a_paragraph and section_index = a_section
feature -- Access
	index: INTEGER
			-- Position among the revision's passages.
	first_word, last_word: INTEGER
			-- Word index span (inclusive).
	paragraph_index, section_index: INTEGER
			-- Enclosing paragraph and section.
	word_count: INTEGER
			-- Number of words in the passage.
		ensure
			definition: Result = last_word - first_word + 1
	contains (a_word: INTEGER): BOOLEAN
			-- Is word index `a_word' inside this passage?
		ensure
			definition: Result = (first_word <= a_word and a_word <= last_word)
invariant
	index_positive: index >= 1
	first_positive: first_word >= 1
	ordered: first_word <= last_word
	paragraph_positive: paragraph_index >= 1
	section_non_negative: section_index >= 0
======== pt_script_edit.e
class
	PT_SCRIPT_EDIT
create
	make
feature {NONE} -- Initialization
	make (a_from_revision, a_first, a_last: INTEGER; a_new_text: READABLE_STRING_GENERAL)
			-- Edit of revision `a_from_revision', words `a_first'..`a_last'.
		require
			revision_positive: a_from_revision >= 1
			first_positive: a_first >= 1
			range_ordered: a_first <= a_last + 1
		ensure
			revision_set: from_revision = a_from_revision
			range_set: first = a_first and last = a_last
			text_set: new_text.same_string_general (a_new_text)
feature -- Access
	from_revision: INTEGER
	first, last: INTEGER
	new_text: STRING_32
feature -- Status
	is_insertion: BOOLEAN
			-- Does this edit insert without replacing?
	is_strike: BOOLEAN
			-- Does this edit delete words?
invariant
	revision_positive: from_revision >= 1
	first_positive: first >= 1
	range_ordered: first <= last + 1
======== pt_script_history.e
class
	PT_SCRIPT_HISTORY
create
	make
feature {NONE} -- Initialization
	make (a_ids: PT_ID_SOURCE; a_parser: PT_SCRIPT_PARSER)
			-- Empty history issuing ids from `a_ids' and tokenizing edits with `a_parser'.
		ensure
			empty: revision_count = 0
			ids_set: ids = a_ids
			parser_set: parser = a_parser
feature -- Access
	ids: PT_ID_SOURCE
			-- Id source shared with the parser for this session.
	parser: PT_SCRIPT_PARSER
			-- Parser used to tokenize replacement text.
	revision_count: INTEGER
			-- Number of revisions.
	current_revision: PT_SCRIPT_REVISION
			-- Latest revision.
		require
			has_revision: revision_count >= 1
	revision (a_number: INTEGER): PT_SCRIPT_REVISION
			-- Revision `a_number'.
		require
			valid: a_number >= 1 and a_number <= revision_count
		ensure
			numbered: Result.number = a_number
feature -- Model
	revisions_model: MML_SEQUENCE [PT_SCRIPT_REVISION]
			-- Revisions in order.
		ensure
			same_count: Result.count = revision_count
feature -- Element change
	start (a_first: PT_SCRIPT_REVISION)
			-- Begin the history with `a_first'.
		require
			empty: revision_count = 0
			first_numbered: a_first.number = 1
		ensure
			one: revision_count = 1
			current_is_first: current_revision = a_first
	apply_edit (a_first, a_last: INTEGER; a_new_text: READABLE_STRING_32)
			-- Replace words `a_first'..`a_last' of the current revision with `a_new_text'
			-- (`a_first' = `a_last' + 1 inserts; empty text strikes).
		require
			has_revision: revision_count >= 1
			range_low: a_first >= 1
			range_high: a_last <= current_revision.word_count
			range_ordered: a_first <= a_last + 1
		ensure
			one_more: revision_count = old revision_count + 1
			numbered: current_revision.number = old current_revision.number + 1
			history_kept: (revisions_model.front (old revision_count) |=| old revisions_model)
			prefix_ids_kept: (current_revision.ids_model.front (a_first - 1)
					|=| (old current_revision.ids_model).front (a_first - 1))
			suffix_ids_kept: (current_revision.ids_model.tail (current_revision.word_count - (old current_revision.word_count - a_last) + 1)
					|=| (old current_revision.ids_model).tail (a_last + 1))
			ids_unique: current_revision.ids_model.range.count = current_revision.word_count
invariant
	current_consistent: revision_count >= 1 implies current_revision.number = revision_count
======== pt_script_parser.e
class
	PT_SCRIPT_PARSER
create
	make
feature {NONE} -- Initialization
	make
			-- Parser with default stop words and normalizer.
		ensure
			nothing_parsed: not has_parsed
feature -- Access
	last_revision: PT_SCRIPT_REVISION
			-- Result of the last `parse' (an empty placeholder before the first).
	has_parsed: BOOLEAN
			-- Has `parse' run at least once?
	stop_words: PT_STOP_WORDS
	normalizer: PT_NORMALIZER
feature -- Basic operations
	parse (a_title, a_text: READABLE_STRING_32; a_number: INTEGER; a_ids: PT_ID_SOURCE)
			-- Parse `a_text' as revision `a_number', issuing ids from `a_ids'.
		require
			number_positive: a_number >= 1
		ensure
			parsed: has_parsed
			numbered: last_revision.number = a_number
			ids_unique: last_revision.ids_model.range.count = last_revision.word_count
			ids_fresh: across 1 |..| last_revision.word_count as i all
					last_revision.word (i).id.value > old a_ids.last_issued end
			ids_consumed: a_ids.last_issued = old a_ids.last_issued + last_revision.word_count
			words_found: has_words (a_text) implies last_revision.word_count > 0
			optional_not_required: across 1 |..| last_revision.word_count as i all
					not last_revision.word (i).is_required implies not last_revision.spoken_ids_model.has (last_revision.word (i).id) end
			headings_flagged: across 1 |..| last_revision.section_count as i all
					last_revision.word (last_revision.section (i).first_word).is_heading end
feature -- Classification
	Abbreviations: ARRAY [STRING_32]
			-- Single-period abbreviations that do not end a sentence (lowercase, with the period).
	ends_sentence (a_token: READABLE_STRING_32): BOOLEAN
			-- Does `a_token' end a sentence (. ! ? or the ellipsis, ignoring closing quotes and
			-- brackets), unless it is an abbreviation ("Dr.", "e.g.", "U.S.")?
	is_abbreviation (a_core: READABLE_STRING_32): BOOLEAN
			-- Is `a_core' (ending in '.') an abbreviation: an inner period ("e.g.", "U.S.") or a known title?
feature -- Status
	has_words (a_text: READABLE_STRING_32): BOOLEAN
			-- Does `a_text' contain at least one non-whitespace character?
======== pt_script_revision.e
class
	PT_SCRIPT_REVISION
create
	make
feature {NONE} -- Initialization
	make (a_number: INTEGER; a_title, a_source: READABLE_STRING_32;
			-- Revision `a_number' of script `a_title' with the given structure.
		require
			number_positive: a_number >= 1
			ids_unique: ids_are_unique (a_words)
			passages_partition: passages_partition (a_words.count, a_passages)
			sections_fit: a_sections.count <= a_passages.count
		ensure
			number_set: number = a_number
			title_set: title.same_string (a_title)
			counts_set: word_count = a_words.count and passage_count = a_passages.count and section_count = a_sections.count
feature -- Access
	number: INTEGER
			-- Revision number (1 = as loaded).
	title: STRING_32
			-- Script title.
	source_text: STRING_32
			-- Plain text the words were taken from (char spans refer to it).
	word_count: INTEGER
			-- Number of words.
	passage_count: INTEGER
			-- Number of passages.
	section_count: INTEGER
			-- Number of sections.
	word (a_index: INTEGER): PT_WORD
			-- Word at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= word_count
	passage (a_index: INTEGER): PT_PASSAGE
			-- Passage at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= passage_count
	section (a_index: INTEGER): PT_SECTION
			-- Section at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= section_count
	index_of (a_id: PT_WORD_ID): INTEGER
			-- Index of the word with id `a_id', or 0 if absent.
		ensure
			zero_or_found: Result = 0 or else word (Result).id ~ a_id
			found_if_present: ids_model.has (a_id) implies Result > 0
	passage_of (a_index: INTEGER): INTEGER
			-- Index of the passage containing word `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= word_count
		ensure
			contains: passage (Result).contains (a_index)
	text_of_range (a_first, a_last: INTEGER): STRING_32
			-- Words `a_first'..`a_last' joined by single spaces (empty when `a_first' > `a_last').
		require
			first_valid: a_first >= 1
			last_valid: a_last <= word_count
			ordered: a_first <= a_last + 1
		ensure
			empty_range: a_first > a_last implies Result.is_empty
feature -- Model
	ids_model: MML_SEQUENCE [PT_WORD_ID]
			-- Word ids in script order.
		ensure
			same_count: Result.count = word_count
	spoken_ids_model: MML_SEQUENCE [PT_WORD_ID]
			-- Ids of words required in the final cut (cue and heading words excluded), in order.
		ensure
			not_longer: Result.count <= word_count
	passage_bounds_model: MML_SEQUENCE [INTEGER]
			-- First word index of every passage, in order.
		ensure
			same_count: Result.count = passage_count
feature -- Validation (exported for preconditions)
	ids_are_unique (a_words: ARRAYED_LIST [PT_WORD]): BOOLEAN
			-- Are all ids in `a_words' distinct?
	passages_partition (a_word_count: INTEGER; a_passages: ARRAYED_LIST [PT_PASSAGE]): BOOLEAN
			-- Do `a_passages' cover words 1..`a_word_count' contiguously, in order, indexed 1..n?
invariant
	number_positive: number >= 1
	passages_fit: passage_count <= word_count
	sections_fit: section_count <= passage_count
	empty_consistent: word_count = 0 implies passage_count = 0
	index_sized: index_by_id.count = word_count
======== pt_section.e
class
	PT_SECTION
create
	make
feature {NONE} -- Initialization
	make (a_index: INTEGER; a_heading: READABLE_STRING_32; a_first_word: INTEGER)
			-- Section `a_index' titled `a_heading' starting at word `a_first_word'.
		require
			index_positive: a_index >= 1
			heading_present: not a_heading.is_empty
			first_positive: a_first_word >= 1
		ensure
			index_set: index = a_index
			heading_set: heading.same_string (a_heading)
			first_set: first_word = a_first_word
feature -- Access
	index: INTEGER
			-- Position among the revision's sections.
	heading: STRING_32
			-- Heading text without the leading '#' marks.
	first_word: INTEGER
			-- First word index of the section.
invariant
	index_positive: index >= 1
	heading_present: not heading.is_empty
	first_positive: first_word >= 1
======== pt_stop_words.e
class
	PT_STOP_WORDS
feature -- Status
	has (a_normalized: READABLE_STRING_32): BOOLEAN
			-- Is `a_normalized' a stop word?
feature -- Access
	count: INTEGER
			-- Number of stop words.
invariant
	non_empty: count > 0
======== pt_word.e
class
	PT_WORD
create
	make
feature {NONE} -- Initialization
	make (a_id: PT_WORD_ID; a_text, a_normalized: READABLE_STRING_32;
			-- Create word `a_text' with identity `a_id'.
		require
			real_id: not a_id.is_none
			text_present: not a_text.is_empty
			span_ordered: a_char_start >= 1 and a_char_start <= a_char_end
			structure_positive: a_passage >= 1 and a_paragraph >= 1 and a_section >= 0
			normalized_not_longer: a_normalized.count <= a_text.count
			cue_not_heading: not (a_is_cue and a_is_heading)
		ensure
			id_set: id ~ a_id
			text_set: text.same_string (a_text)
			normalized_set: normalized.same_string (a_normalized)
			span_set: char_start = a_char_start and char_end = a_char_end
			structure_set: passage_index = a_passage and paragraph_index = a_paragraph and section_index = a_section
			flags_set: is_stop_word = a_is_stop and is_cue = a_is_cue and is_heading = a_is_heading
feature -- Access
	id: PT_WORD_ID
			-- Stable identity.
	text: STRING_32
			-- Text as written in the script.
	normalized: STRING_32
			-- Lowercase, punctuation stripped, digits kept (PT_NORMALIZER).
	char_start, char_end: INTEGER
			-- Character span in the revision's source text.
	passage_index, paragraph_index, section_index: INTEGER
			-- Structure indexes (section 0 = before the first heading).
feature -- Status
	is_stop_word: BOOLEAN
			-- Is this a stop word (never moves alignment alone)?
	is_cue: BOOLEAN
			-- Is this inside a [CUE] marker (shown dimmed, never spoken)?
	is_heading: BOOLEAN
			-- Is this part of a heading? Optional: matchable if read aloud, never required
			-- for exact cover (real-voice evidence: Larry read the headings; review M24).
	is_required: BOOLEAN
			-- Must this word appear in the final cut?
		ensure
			definition: Result = (not is_cue and not is_heading)
invariant
	real_id: not id.is_none
	text_present: not text.is_empty
	span_ordered: char_start >= 1 and char_start <= char_end
	structure_positive: passage_index >= 1 and paragraph_index >= 1 and section_index >= 0
	normalized_not_longer: normalized.count <= text.count
	cue_not_heading: not (is_cue and is_heading)
======== pt_word_id.e
expanded class
inherit
	ANY
		redefine
			default_create
		end
create
	default_create, make
feature {NONE} -- Initialization
	default_create
			-- The "no word" id.
		ensure then
			none: value = 0
	make (a_value: INTEGER_64)
			-- Identity `a_value'.
		require
			positive: a_value > 0
		ensure
			set: value = a_value
feature -- Access
	value: INTEGER_64
			-- Raw identity.
feature -- Status
	is_none: BOOLEAN
			-- Is this the "no word" id?
		ensure
			definition: Result = (value = 0)
invariant
	non_negative: value >= 0
======== simple_prompter.e
class
	SIMPLE_PROMPTER
create
	make_with_settings
feature {NONE} -- Initialization
	make_with_settings (a_settings: PT_SETTINGS)
			-- Prompter using `a_settings'; no script yet.
		ensure
			settings_set: settings = a_settings
			no_script: not has_script
			mode_from_settings: mode = a_settings.default_mode (False)
feature -- Configuration (fluent)
	with_mode (a_mode: INTEGER): like Current
			-- Follow mode for the next script load.
		require
			known: a_mode >= {PT_FOLLOW_MODE}.Constant and a_mode <= {PT_FOLLOW_MODE}.Tracking
			no_script_yet: not has_script
		ensure
			set: mode = a_mode
			chained: Result = Current
	with_speed_wpm (a_wpm: INTEGER): like Current
		require
			range: a_wpm >= 40 and a_wpm <= 400
			no_script_yet: not has_script
		ensure
			set: speed_wpm = a_wpm
			chained: Result = Current
	with_clock (a_clock: PT_CLOCK): like Current
		require
			no_script_yet: not has_script
		ensure
			set: clock = a_clock
			chained: Result = Current
	with_measure (a_measure: PT_TEXT_MEASURE; a_width: REAL_64): like Current
		require
			width_positive: a_width > 0
			no_script_yet: not has_script
		ensure
			set: measure = a_measure
			chained: Result = Current
feature -- Access
	settings: PT_SETTINGS
	mode: INTEGER
	speed_wpm: INTEGER
	clock: PT_CLOCK
	measure: PT_TEXT_MEASURE
	column_width: INTEGER
	layout: PT_LAYOUT
	recording_clock: PT_RECORDING_CLOCK
	history: PT_SCRIPT_HISTORY
		require
			loaded: has_script
	follower: PT_FOLLOWER
		require
			loaded: has_script
	scroll: PT_SCROLL_MODEL
		require
			loaded: has_script
	controller: PT_TAKE_CONTROLLER
		require
			loaded: has_script
	aligner: PT_ALIGNER
		require
			loaded: has_script
	last_error: detachable STRING_32
	Prompt_words: INTEGER = 40
			-- Already-read words given to the decoder.
	prompt_text: STRING_32
			-- The last `Prompt_words' words already read (never upcoming text: spike gotcha 2).
		require
			loaded: has_script
		ensure
			already_read_only: history.current_revision.text_of_range (1, (controller.reader_position - 1).max (0)).ends_with (Result)
feature -- Status
	has_script: BOOLEAN
feature -- Script
	open_script (a_path: READABLE_STRING_32)
			-- Load a .txt or .md script.
		require
			path_present: not a_path.is_empty
		ensure
			loaded_or_error: has_script or attached last_error
	load_script_text (a_title, a_text: READABLE_STRING_32)
			-- Load script text as revision 1 and wire follower, layout, scroll, aligner and controller.
		require
			not_recording: not has_script or else not controller.is_recording
		ensure
			loaded: has_script
			first_revision: history.revision_count = 1
			follower_sized: follower.word_count = history.current_revision.word_count
			idle: controller.state = {PT_TAKE_STATE}.Idle
feature -- Following
	feed_voice (a_frame: PT_VOICE_FRAME)
		require
			loaded: has_script
	feed_heard (a_heard: PT_HEARD_WORDS)
			-- Decode result: align, steer the follower, sample into the controller.
		require
			loaded: has_script
	tick (a_now_ms: REAL_64)
		require
			loaded: has_script
			not_backward: scroll.is_started implies a_now_ms >= scroll.last_ms
		ensure
			ticked: scroll.last_ms = a_now_ms
feature -- Take Studio
	perform (a_action: INTEGER)
			-- Take Studio action; rewires after a revision (Skip) and reanchors the aligner on resume.
		require
			loaded: has_script
			known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
			no_argument: not controller.needs_argument (a_action)
			allowed: controller.is_allowed (a_action)
		ensure
			reanchored_on_resume: a_action = {PT_ACTION}.Count_in_done implies
				(aligner.position = (controller.caret - 1).max (0) and aligner.reanchored_at = recording_clock.sample_count)
	commit_edit (a_new_text: READABLE_STRING_32)
			-- Live edit through the facade, so aligner, layout and follower follow the new revision (review H4).
		require
			loaded: has_script
			editing: controller.state = {PT_TAKE_STATE}.Editing
		ensure
			follows_revision: aligner.revision = history.current_revision
invariant
	mode_known: mode >= {PT_FOLLOW_MODE}.Constant and mode <= {PT_FOLLOW_MODE}.Tracking
	speed_range: speed_wpm >= 40 and speed_wpm <= 400
	width_positive: column_width > 0
	loaded_consistently: has_script implies (attached follower_cell and attached controller_cell and attached scroll_cell and attached aligner_cell)
	follows_current_revision: (attached history_cell as al_h and attached aligner_cell as al_a and attached follower_cell as al_f) implies
		(al_a.revision = al_h.current_revision and layout.word_count = al_h.current_revision.word_count and al_f.word_count = layout.word_count)
======== pt_action.e
class
	PT_ACTION
feature -- Constants
	Play: INTEGER = 1
			-- Practice: count in without recording; no journal.
	Record: INTEGER = 2
	Again: INTEGER = 3
	Hold: INTEGER = 4
	Go: INTEGER = 5
	Back: INTEGER = 6
	Forward: INTEGER = 7
	Back_paragraph: INTEGER = 8
	Forward_paragraph: INTEGER = 9
	Pick_word: INTEGER = 10
			-- Via PT_TAKE_CONTROLLER.pick_word (needs an index).
	Edit_open: INTEGER = 11
	Edit_commit: INTEGER = 12
			-- Via PT_TAKE_CONTROLLER.commit_edit (needs text).
	Edit_cancel: INTEGER = 13
	Star: INTEGER = 14
	Reject: INTEGER = 15
	Marker: INTEGER = 16
			-- Via PT_TAKE_CONTROLLER.add_marker (optional text).
	Skip: INTEGER = 17
	Wrap: INTEGER = 18
			-- Recording: stop and analyze.
	Stop: INTEGER = 19
			-- Practice: back to idle.
	Abort: INTEGER = 20
			-- Recording: stop, keep files, no analysis.
	Count_in_done: INTEGER = 21
	Analysis_done: INTEGER = 22
======== pt_event_kind.e
class
	PT_EVENT_KIND
feature -- Constants
	Session_start: INTEGER = 1
	Resume: INTEGER = 2
	Hold: INTEGER = 3
	Flub: INTEGER = 4
	Rewind_to: INTEGER = 5
	Count_in: INTEGER = 6
	Edit: INTEGER = 7
	Star: INTEGER = 8
	Reject: INTEGER = 9
	Marker: INTEGER = 10
	Skip: INTEGER = 11
	Align: INTEGER = 12
	Wrap: INTEGER = 13
	Abort: INTEGER = 14
feature -- Names
	name (a_kind: INTEGER): STRING_8
			-- JSONL "t" value for `a_kind'.
		require
			known: a_kind >= Session_start and a_kind <= Abort
		ensure
			named: not Result.is_empty
======== pt_journal.e
class
	PT_JOURNAL
create
	make_in_memory, make_on_file
feature {NONE} -- Initialization
	make_in_memory
			-- Journal without persistence (practice log off, tests).
		ensure
			empty: count = 0
			memory_only: not is_persistent
	make_on_file (a_path: READABLE_STRING_32)
			-- Journal appending to `a_path' (created if absent).
		require
			path_present: not a_path.is_empty
		ensure
			empty: count = 0
			persistent: is_persistent
feature -- Access
	count: INTEGER
			-- Number of events.
	event (a_index: INTEGER): PT_TAKE_EVENT
			-- Event at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= count
	last_event: PT_TAKE_EVENT
			-- Most recent event.
		require
			not_empty: count > 0
	last_rt: REAL_64
			-- Recording time of the most recent event (0 when empty).
	lines_written: INTEGER
			-- JSONL lines written and flushed (persistent journals only).
	skipped_lines: INTEGER
			-- Unreadable lines skipped by `replay_from'.
	path: detachable STRING_32
			-- JSONL file, when persistent.
	codec: PT_JOURNAL_CODEC
	count_of (a_kind: INTEGER): INTEGER
			-- Number of events of `a_kind'.
		require
			kind_known: a_kind >= {PT_EVENT_KIND}.Session_start and a_kind <= {PT_EVENT_KIND}.Abort
		ensure
			bounded: Result >= 0 and Result <= count
feature -- Status
	is_open: BOOLEAN = True
			-- May events be appended?
	is_persistent: BOOLEAN
			-- Does `append' write to a file?
feature -- Model
	events_model: MML_SEQUENCE [PT_TAKE_EVENT]
			-- Events in order.
		ensure
			same_count: Result.count = count
feature -- Element change
	append (a_event: PT_TAKE_EVENT)
			-- Append `a_event' and, when persistent, write and flush one JSONL line.
		require
			rt_ordered: a_event.rt >= last_rt
			open: is_open
		ensure
			appended: (events_model |=| (old events_model & a_event))
			last_updated: last_rt = a_event.rt
			persisted: is_persistent implies lines_written = old lines_written + 1
			memory_only_unwritten: not is_persistent implies lines_written = old lines_written
	replay_from (a_lines: ITERABLE [READABLE_STRING_8])
			-- Rebuild from JSONL lines; unreadable lines (a torn last line after a crash) are skipped.
		require
			empty: count = 0
		ensure
			ordered: across 2 |..| count as i all event (i).rt >= event (i - 1).rt end
			skips_counted: skipped_lines >= old skipped_lines
invariant
	last_rt_non_negative: last_rt >= 0
	empty_zero: count = 0 implies last_rt = 0
	writes_bounded: lines_written <= count
======== pt_journal_codec.e
class
	PT_JOURNAL_CODEC
create
	make
feature {NONE} -- Initialization
	make
			-- Codec with nothing decoded.
		ensure
			nothing_decoded: not has_event and not has_error
feature -- Encoding
	encode (a_event: PT_TAKE_EVENT): STRING_8
			-- One-line JSON object for `a_event' (UTF-8, no newline).
		ensure
			one_line: not Result.has ('%N') and not Result.has ('%R')
			object: Result.starts_with ("{") and Result.ends_with ("}")
feature -- Decoding
	decode (a_line: READABLE_STRING_8)
			-- Parse `a_line'; set `last_event' or `last_error'.
		ensure
			exactly_one_outcome: has_event xor has_error
	last_event: detachable PT_TAKE_EVENT
			-- Event from the last successful `decode'.
	last_error: detachable STRING_32
			-- Reason the last `decode' failed.
	has_event: BOOLEAN
			-- Did the last `decode' succeed?
	has_error: BOOLEAN
			-- Did the last `decode' fail?
invariant
	event_when_success: has_event implies attached last_event
======== pt_recording_clock.e
class
	PT_RECORDING_CLOCK
create
	make
feature {NONE} -- Initialization
	make
			-- Clock at rt 0.
		ensure
			at_zero: rt = 0 and byte_count = 0 and observed_at_ms = 0
feature -- Constants
	Bytes_per_second: INTEGER = 64_000
	Max_interpolation_s: REAL_64 = 0.25
			-- To be confirmed from spike T-0 (tail flush granularity).
feature -- Access
	byte_count: INTEGER_64
			-- Tee file size at the last observation.
	observed_at_ms: REAL_64
			-- Monotone clock time of the last observation.
	rt: REAL_64
			-- Recording time at the last observation, seconds.
	sample_count: INTEGER_64
			-- Samples (16 kHz) at the last observation: the clock the speech pipeline counts in.
		ensure
			non_negative: Result >= 0
	rt_at (a_now_ms: REAL_64): REAL_64
			-- Recording time at clock time `a_now_ms', interpolated.
		require
			after: a_now_ms >= observed_at_ms
		ensure
			not_before: Result >= rt
			bounded: Result <= rt + Max_interpolation_s
feature -- Element change
	observe_bytes (a_total: INTEGER_64; a_at_ms: REAL_64)
			-- The tee file holds `a_total' bytes at clock time `a_at_ms'.
		require
			monotone: a_total >= byte_count
			time_ok: a_at_ms >= observed_at_ms
		ensure
			counted: byte_count = a_total
			time_set: observed_at_ms = a_at_ms
			rt_exact: (rt - a_total / Bytes_per_second).abs < 1.0e-9
invariant
	rt_non_negative: rt >= 0
	bytes_non_negative: byte_count >= 0
	time_non_negative: observed_at_ms >= 0
======== pt_restart_policy.e
class
	PT_RESTART_POLICY
feature -- Constants
	Early_words: INTEGER = 2
	Unit_passage: INTEGER = 1
	Unit_paragraph: INTEGER = 2
feature -- Queries
	passage_start (a_revision: PT_SCRIPT_REVISION; a_word: INTEGER): INTEGER
			-- First word of the passage containing `a_word'.
		require
			valid: a_word >= 1 and a_word <= a_revision.word_count
		ensure
			not_after: Result <= a_word
			in_same_passage: a_revision.passage_of (Result) = a_revision.passage_of (a_word)
	again_caret (a_revision: PT_SCRIPT_REVISION; a_position: INTEGER; a_confident: BOOLEAN;
			-- Caret for Again with the reader at `a_position'; `a_last_confident' is the last
			-- confidently aligned word (used when not `a_confident').
		require
			valid_position: a_position >= 1 and a_position <= a_revision.word_count
			valid_fallback: a_last_confident >= 1 and a_last_confident <= a_position
		ensure
			valid: Result >= 1 and Result <= a_revision.word_count
			at_passage_start: Result = passage_start (a_revision, Result)
			not_after: Result <= a_position
			previous_if_early: (a_confident and a_position - passage_start (a_revision, a_position) < Early_words
					and a_revision.passage_of (a_position) > 1)
				implies a_revision.passage_of (Result) = a_revision.passage_of (a_position) - 1
			fallback_when_unsure: not a_confident implies Result = passage_start (a_revision, a_last_confident)
	step_back (a_revision: PT_SCRIPT_REVISION; a_caret, a_unit: INTEGER): INTEGER
			-- Caret one `a_unit' back from `a_caret' (stays at word 1 at the start).
		require
			valid_caret: a_caret >= 1 and a_caret <= a_revision.word_count
			known_unit: a_unit = Unit_passage or a_unit = Unit_paragraph
		ensure
			valid: Result >= 1 and Result <= a_revision.word_count
			not_after: Result <= a_caret
			moves_unless_first: a_revision.passage_of (a_caret) > 1 implies Result < a_caret
			at_passage_start: Result = passage_start (a_revision, Result)
	step_forward (a_revision: PT_SCRIPT_REVISION; a_caret, a_unit: INTEGER): INTEGER
			-- Caret one `a_unit' forward from `a_caret' (stays put in the last unit).
		require
			valid_caret: a_caret >= 1 and a_caret <= a_revision.word_count
			known_unit: a_unit = Unit_passage or a_unit = Unit_paragraph
		ensure
			valid: Result >= 1 and Result <= a_revision.word_count
			not_before: Result >= a_caret
			moves_unless_last: a_revision.passage_of (a_caret) < a_revision.passage_count implies Result > a_caret
			at_passage_start: Result > a_caret implies Result = passage_start (a_revision, Result)
======== pt_session.e
class
	PT_SESSION
create
	make
feature {NONE} -- Initialization
	make (a_folder: PT_SESSION_FOLDER; a_history: PT_SCRIPT_HISTORY; a_journal: PT_JOURNAL)
		require
			has_revision: a_history.revision_count >= 1
		ensure
			folder_set: folder = a_folder
			history_set: history = a_history
			journal_set: journal = a_journal
			not_analyzed: analysis = Void and cuts = Void
feature -- Access
	folder: PT_SESSION_FOLDER
	history: PT_SCRIPT_HISTORY
	journal: PT_JOURNAL
	analysis: detachable PT_ANALYSIS
	cuts: detachable PT_CUT_LIST
feature -- Status
	is_analyzed: BOOLEAN
feature -- Element change
	set_analysis (a_analysis: PT_ANALYSIS)
		ensure
			set: analysis = a_analysis
			cuts_from_success: a_analysis.is_success implies cuts = a_analysis.cuts
	set_cuts (a_cuts: PT_CUT_LIST)
			-- The Edit Floor's edited choice.
		ensure
			set: cuts = a_cuts
			analysis_kept: analysis = old analysis
======== pt_session_folder.e
class
	PT_SESSION_FOLDER
create
	make
feature {NONE} -- Initialization
	make (a_root: READABLE_STRING_32)
			-- Session rooted at `a_root' (e.g. ...\Videos\simple_prompter\2026-10-05-episode-12.take).
		require
			root_present: not a_root.is_empty
			no_trailing_separator: a_root [a_root.count] /= '\' and a_root [a_root.count] /= '/'
		ensure
			root_set: root.same_string (a_root)
feature -- Access
	root: STRING_32
	raw_path: STRING_32 do Result := under ("raw.mkv") end
	tee_path: STRING_32 do Result := under ("tee.f32") end
	journal_path: STRING_32 do Result := under ("journal.jsonl") end
	session_settings_path: STRING_32 do Result := under ("session.toml") end
	review_srt_path: STRING_32 do Result := under ("review.srt") end
	cut_path: STRING_32 do Result := under ("cut.json") end
	script_dir: STRING_32 do Result := under ("script") end
	analysis_dir: STRING_32 do Result := under ("analysis") end
	out_dir: STRING_32 do Result := under ("out") end
	revision_path (a_number: INTEGER): STRING_32
			-- File of script revision `a_number'.
		require
			positive: a_number >= 1
		ensure
			inside: Result.starts_with (script_dir)
invariant
	root_present: not root.is_empty
======== pt_take_controller.e
class
	PT_TAKE_CONTROLLER
create
	make
feature {NONE} -- Initialization
	make (a_history: PT_SCRIPT_HISTORY; a_journal: PT_JOURNAL; a_recording_clock: PT_RECORDING_CLOCK;
			-- Idle controller over `a_history'.
		require
			has_revision: a_history.revision_count >= 1
			follower_sized: a_follower.word_count = a_history.current_revision.word_count
		ensure
			idle: state = {PT_TAKE_STATE}.Idle
			not_recording: not is_recording
			caret_at_start: caret = a_history.current_revision.word_count.min (1)
			history_set: history = a_history
			journal_set: journal = a_journal
			follower_set: follower = a_follower
feature -- Constants
	Default_count_in: REAL_64 = 2.0
			-- Seconds.
feature -- Access
	history: PT_SCRIPT_HISTORY
	journal: PT_JOURNAL
	recording_clock: PT_RECORDING_CLOCK
	clock: PT_CLOCK
	follower: PT_FOLLOWER
	policy: PT_RESTART_POLICY
	transitions: PT_TRANSITIONS
	state: INTEGER
			-- Current {PT_TAKE_STATE}.
	caret: INTEGER
			-- Restart word (0 only when the script is empty).
	count_in_seconds: REAL_64
			-- Count-in length.
	edit_first, edit_last: INTEGER
			-- Word range opened by Edit_open (the caret's passage).
	last_again_target: INTEGER
			-- Caret chosen by the most recent Again (review M7: computed only for Again).
	alignment_confidence: REAL_64
			-- Confidence of the latest sampled alignment.
	last_confident_word: INTEGER
			-- Latest word aligned with confidence >= Confident_level.
	Confident_level: REAL_64 = 0.6
	revision: PT_SCRIPT_REVISION
			-- Current script revision.
	current_rt: REAL_64
			-- Recording time now.
		ensure
			non_negative: Result >= 0
	reader_position: INTEGER
			-- Word the follower is on (1..word_count; 0 for an empty script).
		ensure
			in_script: Result >= 0 and Result <= revision.word_count
	again_target: INTEGER
			-- Caret Again would choose now (0 for an empty script).
		ensure
			in_script: Result >= 0 and Result <= revision.word_count
feature -- Status
	is_recording: BOOLEAN
			-- Is a recording session rolling (journal active)?
	is_allowed (a_action: INTEGER): BOOLEAN
			-- May `a_action' be performed now?
		require
			known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		ensure
			table_rules: Result implies transitions.is_allowed (state, a_action, is_recording)
			nothing_to_read: (revision.word_count = 0 and (a_action = {PT_ACTION}.Play or a_action = {PT_ACTION}.Record)) implies not Result
	needs_argument (a_action: INTEGER): BOOLEAN
			-- Must `a_action' go through its own command (pick_word, commit_edit, add_marker)?
	is_browse (a_action: INTEGER): BOOLEAN
			-- Does `a_action' only move the caret?
feature -- Commands
	perform (a_action: INTEGER)
			-- Carry out `a_action' (events and follower effects per spec 07 section 2.12).
		require
			known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
			no_argument: not needs_argument (a_action)
			allowed: is_allowed (a_action)
		ensure
			transitioned: state = transitions.next_state (old state, a_action)
			recording_starts: a_action = {PT_ACTION}.Record implies is_recording
			recording_ends: (a_action = {PT_ACTION}.Wrap or a_action = {PT_ACTION}.Abort) implies not is_recording
			journal_monotone: journal.count >= old journal.count
			practice_not_journaled: (not old is_recording and a_action /= {PT_ACTION}.Record) implies journal.count = old journal.count
			again_caret: a_action = {PT_ACTION}.Again implies (caret = last_again_target and last_again_target >= 1)
			browse_not_journaled: is_browse (a_action) implies journal.count = old journal.count
			resumes_at_caret: a_action = {PT_ACTION}.Count_in_done implies follower.target = (caret - 1).to_double
			frozen_unless_reading: (state = {PT_TAKE_STATE}.Count_in or state = {PT_TAKE_STATE}.Held) implies follower.is_held
			reading_runs: state = {PT_TAKE_STATE}.Reading implies not follower.is_held
			skip_revises: a_action = {PT_ACTION}.Skip implies history.revision_count = old history.revision_count + 1
	pick_word (a_index: INTEGER)
			-- Put the caret on word `a_index' (mouse click or badge digit while held).
		require
			held: state = {PT_TAKE_STATE}.Held
			valid: a_index >= 1 and a_index <= revision.word_count
		ensure
			placed: caret = a_index
			not_journaled: journal.count = old journal.count
			still_held: state = {PT_TAKE_STATE}.Held
	commit_edit (a_new_text: READABLE_STRING_32)
			-- Replace words `edit_first'..`edit_last' with `a_new_text' (revision n+1).
		require
			editing: state = {PT_TAKE_STATE}.Editing
		ensure
			new_revision: history.revision_count = old history.revision_count + 1
			back_to_held: state = {PT_TAKE_STATE}.Held
			journaled_when_recording: is_recording implies journal.count = old journal.count + 1
			follower_resized: follower.word_count = revision.word_count
			caret_at_edit: revision.word_count > 0 implies caret = policy.passage_start (revision,
					(old edit_first).max (1).min (revision.word_count))
	add_marker (a_text: READABLE_STRING_32)
			-- Drop a marker (chapter or reminder) now.
		require
			allowed: is_allowed ({PT_ACTION}.Marker)
		ensure
			journaled: journal.count = old journal.count + 1
			state_kept: state = old state
	sample_alignment (a_alignment: PT_ALIGNMENT)
			-- Record the live aligner estimate (confidence, last confident word; Align events <= 4/s while recording).
		ensure
			confidence_taken: alignment_confidence = a_alignment.confidence
			at_most_one_event: journal.count <= old journal.count + 1
			not_journaled_in_practice: not is_recording implies journal.count = old journal.count
	set_count_in (a_seconds: REAL_64)
		require
			range: a_seconds >= 0 and a_seconds <= 5
		ensure
			set: count_in_seconds = a_seconds
invariant
	state_known: state >= {PT_TAKE_STATE}.Idle and state <= {PT_TAKE_STATE}.Wrapped
	caret_valid: revision.word_count > 0 implies (caret >= 1 and caret <= revision.word_count)
	caret_zero_when_empty: revision.word_count = 0 implies caret = 0
	confidence_range: alignment_confidence >= 0.0 and alignment_confidence <= 1.0
	count_in_range: count_in_seconds >= 0 and count_in_seconds <= 5
	last_confident_in_script: last_confident_word >= 0 and last_confident_word <= revision.word_count
	again_target_in_script: last_again_target >= 0 and last_again_target <= revision.word_count
======== pt_take_event.e
class
	PT_TAKE_EVENT
create
	make_session_start, make_resume, make_hold, make_flub, make_rewind_to, make_count_in,
	make_edit, make_star, make_reject, make_marker, make_skip, make_align, make_wrap, make_abort
feature {NONE} -- Initialization
	make_session_start (a_rt: REAL_64; a_revision: INTEGER; a_mode: READABLE_STRING_32)
			-- Session begins with script revision `a_revision' in follow mode `a_mode'.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_revision >= 1
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Session_start
			rt_set: rt = a_rt
			revision_set: to_rev = a_revision
	make_resume (a_rt: REAL_64; a_caret: PT_WORD_ID; a_revision: INTEGER)
			-- Reading resumes at `a_caret' under revision `a_revision'.
		require
			rt_ok: a_rt >= 0
			real_caret: not a_caret.is_none
			revision_ok: a_revision >= 1
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Resume
			rt_set: rt = a_rt
			caret_set: caret ~ a_caret
			revision_set: to_rev = a_revision
	make_hold (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Hold
			rt_set: rt = a_rt
	make_flub (a_rt: REAL_64; a_word: PT_WORD_ID; a_by: READABLE_STRING_8)
			-- Reader flubbed at `a_word'.
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Flub
			rt_set: rt = a_rt
			word_set: word ~ a_word
	make_rewind_to (a_rt: REAL_64; a_caret: PT_WORD_ID; a_reason: READABLE_STRING_32)
			-- Caret placed at `a_caret' for a restart (`a_reason': again_default, browse, pick).
		require
			rt_ok: a_rt >= 0
			real_caret: not a_caret.is_none
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Rewind_to
			caret_set: caret ~ a_caret
	make_count_in (a_rt: REAL_64; a_seconds: REAL_64)
		require
			rt_ok: a_rt >= 0
			seconds_ok: a_seconds >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Count_in
			seconds_set: seconds = a_seconds
	make_edit (a_rt: REAL_64; a_from_rev: INTEGER; a_first, a_last: PT_WORD_ID;
			-- Script edit creating revision `a_from_rev' + 1.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_from_rev >= 1
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Edit
			next_revision: to_rev = a_from_rev + 1
			old_kept: attached old_text as al_old and then al_old.same_string (a_old)
	make_star (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Star
	make_reject (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Reject
	make_marker (a_rt: REAL_64; a_text: READABLE_STRING_32; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Marker
	make_skip (a_rt: REAL_64; a_from_rev: INTEGER; a_first, a_last: PT_WORD_ID)
			-- Words `a_first'..`a_last' struck from revision `a_from_rev'.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_from_rev >= 1
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Skip
			next_revision: to_rev = a_from_rev + 1
	make_align (a_rt: REAL_64; a_word: PT_WORD_ID; a_confidence: REAL_64)
			-- Sampled live alignment (recovery and fallback only; analysis recomputes).
		require
			rt_ok: a_rt >= 0
			confidence_range: a_confidence >= 0.0 and a_confidence <= 1.0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Align
			confidence_set: confidence = a_confidence
	make_wrap (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Wrap
	make_abort (a_rt: REAL_64; a_reason: READABLE_STRING_32)
		require
			rt_ok: a_rt >= 0
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Abort
feature -- Access
	kind: INTEGER
	rt: REAL_64
			-- Recording time, seconds.
	word: PT_WORD_ID
	caret: PT_WORD_ID
	from_rev, to_rev: INTEGER
	range_first, range_last: PT_WORD_ID
	old_text, new_text: detachable STRING_32
	new_ids: detachable ARRAYED_LIST [PT_WORD_ID]
	text: detachable STRING_32
			-- Note text, follow mode name, rewind reason, abort reason.
	by: STRING_8
			-- "hotkey", "mouse", "clicker", "user", "system".
	confidence: REAL_64
	seconds: REAL_64
			-- Count-in length.
invariant
	kind_known: kind >= {PT_EVENT_KIND}.Session_start and kind <= {PT_EVENT_KIND}.Abort
	rt_non_negative: rt >= 0
	edit_complete: kind = {PT_EVENT_KIND}.Edit implies
			(attached old_text and attached new_text and to_rev = from_rev + 1)
	resume_has_caret: kind = {PT_EVENT_KIND}.Resume implies not caret.is_none
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	seconds_non_negative: seconds >= 0
======== pt_take_state.e
class
	PT_TAKE_STATE
feature -- Constants
	Idle: INTEGER = 1
	Count_in: INTEGER = 2
	Reading: INTEGER = 3
	Held: INTEGER = 4
	Editing: INTEGER = 5
	Analyzing: INTEGER = 6
	Wrapped: INTEGER = 7
======== pt_transitions.e
class
	PT_TRANSITIONS
create
	make
feature {NONE} -- Initialization
	make
			-- Fill the table.
		ensure
			sized: table.height = State_count and table.width = Action_count
feature -- Constants
	State_count: INTEGER = 7
	Action_count: INTEGER = 22
feature -- Queries
	table_entry (a_state, a_action: INTEGER): INTEGER
			-- Next state for (`a_state', `a_action'), 0 if the pair is not listed.
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		ensure
			zero_or_state: Result = 0 or (Result >= {PT_TAKE_STATE}.Idle and Result <= {PT_TAKE_STATE}.Wrapped)
	is_recording_only (a_action: INTEGER): BOOLEAN
			-- Is `a_action' meaningful only while recording?
	is_practice_only (a_action: INTEGER): BOOLEAN
			-- Is `a_action' meaningful only while not recording?
	is_allowed (a_state, a_action: INTEGER; a_recording: BOOLEAN): BOOLEAN
			-- May `a_action' be performed in `a_state'?
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		ensure
			listed: Result implies table_entry (a_state, a_action) /= 0
			recording_only: (is_recording_only (a_action) and not a_recording) implies not Result
			practice_only: (is_practice_only (a_action) and a_recording) implies not Result
	next_state (a_state, a_action: INTEGER): INTEGER
			-- State after `a_action' in `a_state'.
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
			listed: table_entry (a_state, a_action) /= 0
		ensure
			known: Result >= {PT_TAKE_STATE}.Idle and Result <= {PT_TAKE_STATE}.Wrapped
invariant
	sized: table.height = State_count and table.width = Action_count
```
