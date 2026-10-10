note
	description: "[
		Console test runner for simple_prompter (generated from the test classes,
		so no test is left unregistered).

		Phase 1 (contracts) state: every library class exists with its full
		contracts; behavior the spec leaves as a Phase 4 comment is a stub.
		Tests of that behavior are written now from the contracts and are
		expected to FAIL until Phase 4 implements it; the run reports them
		honestly. Output is flushed per line, so a crash still shows the last
		test that started.
	]"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run every test set.
		do
			say ("Running simple_prompter tests...%N")
			run_script_tests
			run_followers_tests
			run_equivalences_tests
			run_pipeline_tests
			run_take_tests
			run_assembly_tests
			run_outputs_tests
			run_capture_health_tests
			run_config_tests
			run_acceptance_tests
			run_real_voice_tests
			run_lib_tests_tests
			run_scoop_consumer_tests
			run_attempt_alignment_tests
			run_coverage_take_tests
			run_coverage_core_tests
			run_pill_tests
			run_heard_stabilizer_tests
			run_live_alignment_tests
			run_sessions_tests
			say ("%N========================%N")
			say ("Results: " + passed.out + " passed, " + failed.out + " failed%N")
			if failed > 0 then
				say ("TESTS FAILED%N")
			else
				say ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test sets

	run_script_tests
		local
			t: TEST_SCRIPT
		do
			section ("script")
			create t
			run_test (agent t.test_word_id_default_is_none, "word_id_default_is_none")
			run_test (agent t.test_revision_structure_from_fixture, "revision_structure_from_fixture")
			run_test (agent t.test_index_of_and_passage_of, "index_of_and_passage_of")
			run_test (agent t.test_revision_rejects_duplicate_ids, "revision_rejects_duplicate_ids")
			run_test (agent t.test_id_source_is_monotone, "id_source_is_monotone")
			run_test (agent t.test_stop_words, "stop_words")
			run_test (agent t.test_parser_finds_words_and_passages, "parser_finds_words_and_passages")
			run_test (agent t.test_parser_cues_are_not_spoken, "parser_cues_are_not_spoken")
			run_test (agent t.test_history_edit_keeps_untouched_ids, "history_edit_keeps_untouched_ids")
			run_test (agent t.test_normalizer, "normalizer")
		end

	run_followers_tests
		local
			t: TEST_FOLLOWERS
		do
			section ("followers, layout, matcher, aligner")
			create t
			run_test (agent t.test_constant_one_word_per_second_at_60_wpm, "constant_one_word_per_second_at_60_wpm")
			run_test (agent t.test_held_follower_does_not_move, "held_follower_does_not_move")
			run_test (agent t.test_constant_clamps_at_end, "constant_clamps_at_end")
			run_test (agent t.test_caret_is_the_only_backward_move, "caret_is_the_only_backward_move")
			run_test (agent t.test_rescale_clamps_target, "rescale_clamps_target")
			run_test (agent t.test_voice_gated_moves_only_while_speaking, "voice_gated_moves_only_while_speaking")
			run_test (agent t.test_voice_gated_stops_within_250_ms, "voice_gated_stops_within_250_ms")
			run_test (agent t.test_tracking_holds_after_coast_limit, "tracking_holds_after_coast_limit")
			run_test (agent t.test_spring_moves_toward_target, "spring_moves_toward_target")
			run_test (agent t.test_fixed_measure, "fixed_measure")
			run_test (agent t.test_layout_wraps_every_word, "layout_wraps_every_word")
			run_test (agent t.test_scroll_tick_keeps_time, "scroll_tick_keeps_time")
			run_test (agent t.test_restart_snaps_scroll_back, "restart_snaps_scroll_back")
			run_test (agent t.test_allowed_distance_tiers, "allowed_distance_tiers")
			run_test (agent t.test_matcher_exact_and_tolerant, "matcher_exact_and_tolerant")
			run_test (agent t.test_equivalent_word_matches, "equivalent_word_matches")
			run_test (agent t.test_reanchor_places_position, "reanchor_places_position")
			run_test (agent t.test_stop_words_alone_never_move, "stop_words_alone_never_move")
			run_test (agent t.test_stale_window_is_ignored, "stale_window_is_ignored")
			run_test (agent t.test_aligner_follows_reading, "aligner_follows_reading")
			run_test (agent t.test_repeated_phrase_picks_the_forward_occurrence, "repeated_phrase_picks_the_forward_occurrence")
		end

	run_equivalences_tests
		local
			t: TEST_EQUIVALENCES
		do
			section ("equivalences (real voice)")
			create t
			run_test (agent t.test_homophones_from_the_recording, "homophones_from_the_recording")
			run_test (agent t.test_spoken_abbreviations_from_the_recording, "spoken_abbreviations_from_the_recording")
			run_test (agent t.test_numbers_from_the_recording, "numbers_from_the_recording")
			run_test (agent t.test_compounds_from_the_recording, "compounds_from_the_recording")
			run_test (agent t.test_phonetics_from_the_recording, "phonetics_from_the_recording")
			run_test (agent t.test_unrelated_words_differ, "unrelated_words_differ")
		end

	run_pipeline_tests
		local
			t: TEST_PIPELINE
		do
			section ("speech pipeline")
			create t
			run_test (agent t.test_push_advances_recording_clock, "push_advances_recording_clock")
			run_test (agent t.test_one_frame_per_512_samples, "one_frame_per_512_samples")
			run_test (agent t.test_no_decode_when_disabled, "no_decode_when_disabled")
			run_test (agent t.test_decodes_while_speaking_with_prompt, "decodes_while_speaking_with_prompt")
			run_test (agent t.test_clear_pending_keeps_clock, "clear_pending_keeps_clock")
			run_test (agent t.test_scripted_doubles, "scripted_doubles")
			run_test (agent t.test_speech_codec_round_trip, "speech_codec_round_trip")
		end

	run_take_tests
		local
			t: TEST_TAKE
		do
			section ("take studio state machine and journal")
			create t
			run_test (agent t.test_table_lists_34_pairs, "table_lists_34_pairs")
			run_test (agent t.test_recording_only_and_practice_only, "recording_only_and_practice_only")
			run_test (agent t.test_editing_allows_only_commit_or_cancel, "editing_allows_only_commit_or_cancel")
			run_test (agent t.test_record_then_count_in_done_reads, "record_then_count_in_done_reads")
			run_test (agent t.test_again_counts_in_from_sentence_start, "again_counts_in_from_sentence_start")
			run_test (agent t.test_resume_puts_reader_on_the_caret, "resume_puts_reader_on_the_caret")
			run_test (agent t.test_empty_script_cannot_start, "empty_script_cannot_start")
			run_test (agent t.test_pick_word_moves_caret_without_journal, "pick_word_moves_caret_without_journal")
			run_test (agent t.test_practice_writes_no_journal, "practice_writes_no_journal")
			run_test (agent t.test_disallowed_action_is_refused, "disallowed_action_is_refused")
			run_test (agent t.test_commit_edit_makes_a_revision, "commit_edit_makes_a_revision")
			run_test (agent t.test_journal_append_keeps_order, "journal_append_keeps_order")
			run_test (agent t.test_journal_refuses_time_travel, "journal_refuses_time_travel")
			run_test (agent t.test_codec_round_trip, "codec_round_trip")
			run_test (agent t.test_64000_bytes_is_one_second, "64000_bytes_is_one_second")
			run_test (agent t.test_clock_refuses_shrinking_file, "clock_refuses_shrinking_file")
			run_test (agent t.test_again_caret_rules, "again_caret_rules")
		end

	run_assembly_tests
		local
			t: TEST_ASSEMBLY
		do
			section ("assembly")
			create t
			run_test (agent t.test_speech_map_silence, "speech_map_silence")
			run_test (agent t.test_cut_list_output_mapping, "cut_list_output_mapping")
			run_test (agent t.test_cut_list_refuses_script_disorder, "cut_list_refuses_script_disorder")
			run_test (agent t.test_floor_is_the_complement, "floor_is_the_complement")
			run_test (agent t.test_attempt_per_resume, "attempt_per_resume")
			run_test (agent t.test_solver_exact_cover_after_cough, "solver_exact_cover_after_cough")
			run_test (agent t.test_analyzer_reports_transcriber_failure, "analyzer_reports_transcriber_failure")
			run_test (agent t.test_flagger_flags_every_tight_cut, "flagger_flags_every_tight_cut")
		end

	run_outputs_tests
		local
			t: TEST_OUTPUTS
		do
			section ("outputs and plans")
			create t
			run_test (agent t.test_srt_and_vtt, "srt_and_vtt")
			run_test (agent t.test_chapter_and_edl, "chapter_and_edl")
			run_test (agent t.test_review_srt_one_cue_per_mark, "review_srt_one_cue_per_mark")
			run_test (agent t.test_edl_has_one_event_per_cut, "edl_has_one_event_per_cut")
			run_test (agent t.test_render_plan_follows_the_spike_recipe, "render_plan_follows_the_spike_recipe")
			run_test (agent t.test_cut_codec_round_trip, "cut_codec_round_trip")
			run_test (agent t.test_capture_plan_recording_arguments, "capture_plan_recording_arguments")
			run_test (agent t.test_capture_plan_sets_a_small_audio_buffer, "capture_plan_sets_a_small_audio_buffer")
			run_test (agent t.test_capture_plan_practice_is_audio_only, "capture_plan_practice_is_audio_only")
			run_test (agent t.test_webcam_is_recorded_as_mjpeg, "webcam_is_recorded_as_mjpeg")
			run_test (agent t.test_obs_virtual_camera_uses_its_own_mode, "obs_virtual_camera_uses_its_own_mode")
			run_test (agent t.test_empty_listing_uses_device_mode, "empty_listing_uses_device_mode")
			run_test (agent t.test_preflight_disk_check, "preflight_disk_check")
		end

	run_capture_health_tests
		local
			t: TEST_CAPTURE_HEALTH
		do
			section ("camera check and recording progress")
			create t
			run_test (agent t.test_obs_placeholder_is_still, "obs_placeholder_is_still")
			run_test (agent t.test_live_webcam_in_a_dark_room, "live_webcam_in_a_dark_room")
			run_test (agent t.test_busy_camera_is_not_called_missing, "busy_camera_is_not_called_missing")
			run_test (agent t.test_missing_camera, "missing_camera")
			run_test (agent t.test_no_frames_is_no_picture, "no_frames_is_no_picture")
			run_test (agent t.test_black_picture, "black_picture")
			run_test (agent t.test_probe_opens_the_camera_as_the_recording_will, "probe_opens_the_camera_as_the_recording_will")
			run_test (agent t.test_progress_counts_frames_across_chunks, "progress_counts_frames_across_chunks")
			run_test (agent t.test_progress_stalls_when_frames_stop, "progress_stalls_when_frames_stop")
			run_test (agent t.test_progress_waits_for_the_first_frame, "progress_waits_for_the_first_frame")
			run_test (agent t.test_progress_reports_drops, "progress_reports_drops")
		end

	run_config_tests
		local
			t: TEST_CONFIG
		do
			section ("keymap, controls and settings")
			create t
			run_test (agent t.test_defaults_need_modifiers, "defaults_need_modifiers")
			run_test (agent t.test_bare_key_needs_the_recording_flag, "bare_key_needs_the_recording_flag")
			run_test (agent t.test_bare_keys_only_while_recording, "bare_keys_only_while_recording")
			run_test (agent t.test_activation_refused_outside_recording, "activation_refused_outside_recording")
			run_test (agent t.test_two_keys_for_one_control, "two_keys_for_one_control")
			run_test (agent t.test_rebinding_a_combo_replaces_it, "rebinding_a_combo_replaces_it")
			run_test (agent t.test_clicker_back_depends_on_state, "clicker_back_depends_on_state")
			run_test (agent t.test_hold_toggle_and_wrap_by_mode, "hold_toggle_and_wrap_by_mode")
			run_test (agent t.test_setters_save_and_clamp_by_contract, "setters_save_and_clamp_by_contract")
			run_test (agent t.test_default_mode_waits_for_proof, "default_mode_waits_for_proof")
		end

	run_acceptance_tests
		local
			t: TEST_ACCEPTANCE
		do
			section ("phase 4 acceptance")
			create t
			run_test (agent t.test_read_test_parses_into_sections_and_sentences, "read_test_parses_into_sections_and_sentences")
			run_test (agent t.test_edit_insert_strike_and_edges, "edit_insert_strike_and_edges")
			run_test (agent t.test_step_back_and_forward_edges, "step_back_and_forward_edges")
			run_test (agent t.test_cough_session_journal, "cough_session_journal")
			run_test (agent t.test_journal_writes_and_replays, "journal_writes_and_replays")
			run_test (agent t.test_silence_around_the_instructed_pause, "silence_around_the_instructed_pause")
			run_test (agent t.test_star_marks_exactly_one_attempt, "star_marks_exactly_one_attempt")
			run_test (agent t.test_starred_older_take_wins, "starred_older_take_wins")
			run_test (agent t.test_edited_passage_needs_the_newer_take, "edited_passage_needs_the_newer_take")
			run_test (agent t.test_missing_passage_is_reported, "missing_passage_is_reported")
			run_test (agent t.test_snapper_places_cuts_in_silence, "snapper_places_cuts_in_silence")
			run_test (agent t.test_analyzer_success_path, "analyzer_success_path")
			run_test (agent t.test_captions_respect_limits, "captions_respect_limits")
			run_test (agent t.test_chapters_start_at_zero, "chapters_start_at_zero")
			run_test (agent t.test_analysis_codec_round_trip, "analysis_codec_round_trip")
			run_test (agent t.test_settings_round_trip, "settings_round_trip")
			run_test (agent t.test_open_read_test_from_disk, "open_read_test_from_disk")
		end

	run_real_voice_tests
		local
			t: TEST_REAL_VOICE
		do
			section ("real voice: larry_read_01")
			create t
			run_test (agent t.test_tracking_follows_larry_within_a_line, "tracking_follows_larry_within_a_line")
			run_test (agent t.test_tracking_holds_during_the_ad_lib, "tracking_holds_during_the_ad_lib")
			run_test (agent t.test_tracking_jumps_the_skipped_paragraph, "tracking_jumps_the_skipped_paragraph")
			run_test (agent t.test_tracking_never_moves_backward, "tracking_never_moves_backward")
			run_test (agent t.test_aligner_meets_frame_budget, "aligner_meets_frame_budget")
			run_test (agent t.test_misreads_on_larry_read_01, "misreads_on_larry_read_01")
			run_test (agent t.test_analysis_of_larry_read_01, "analysis_of_larry_read_01")
		end

	run_lib_tests_tests
		local
			t: LIB_TESTS
		do
			section ("facade")
			create t
			run_test (agent t.test_load_wires_everything, "load_wires_everything")
			run_test (agent t.test_fluent_configuration, "fluent_configuration")
			run_test (agent t.test_constant_practice_read_moves, "constant_practice_read_moves")
			run_test (agent t.test_prompt_is_already_read_text_only, "prompt_is_already_read_text_only")
		end

	run_scoop_consumer_tests
		local
			t: TEST_SCOOP_CONSUMER
		do
			section ("SCOOP consumer")
			create t
			run_test (agent t.test_separate_recording_clock, "separate_recording_clock")
		end

	run_attempt_alignment_tests
		local
			t: TEST_ATTEMPT_ALIGNMENT
		do
			section ("attempt aligner and misreads (phase 5)")
			create t
			run_test (agent t.test_long_cue_does_not_stop_alignment, "long_cue_does_not_stop_alignment")
			run_test (agent t.test_stop_word_does_not_skip_ahead, "stop_word_does_not_skip_ahead")
			run_test (agent t.test_two_heard_words_for_one_script_word, "two_heard_words_for_one_script_word")
			run_test (agent t.test_one_heard_token_for_three_script_words, "one_heard_token_for_three_script_words")
			run_test (agent t.test_one_for_one_substitution_is_a_misread, "one_for_one_substitution_is_a_misread")
			run_test (agent t.test_homophones_are_not_misreads, "homophones_are_not_misreads")
			run_test (agent t.test_uneven_gap_is_not_a_misread, "uneven_gap_is_not_a_misread")
			run_test (agent t.test_digits_are_not_sound_alikes, "digits_are_not_sound_alikes")
			run_test (agent t.test_ad_lib_word_does_not_pull_the_pointer, "ad_lib_word_does_not_pull_the_pointer")
			run_test (agent t.test_skipped_paragraph_is_recovered, "skipped_paragraph_is_recovered")
			run_test (agent t.test_misread_flags_only_inside_the_final_video, "misread_flags_only_inside_the_final_video")
			run_test (agent t.test_analyzer_raises_the_misread_flag, "analyzer_raises_the_misread_flag")
			run_test (agent t.test_run_up_lookahead_and_substitution_limits, "run_up_lookahead_and_substitution_limits")
		end

	run_coverage_take_tests
		local
			t: TEST_COVERAGE_TAKE
		do
			section ("coverage: take studio, config, recording, facade (phase 5)")
			create t
			run_test (agent t.test_session_folder_paths, "session_folder_paths")
			run_test (agent t.test_recorder_health, "recorder_health")
			run_test (agent t.test_camera_anchor, "camera_anchor")
			run_test (agent t.test_scripted_transcriber, "scripted_transcriber")
			run_test (agent t.test_settings_defaults_and_setters, "settings_defaults_and_setters")
			run_test (agent t.test_key_binding_codes, "key_binding_codes")
			run_test (agent t.test_keymap_bare_keys_follow_recording, "keymap_bare_keys_follow_recording")
			run_test (agent t.test_win32_virtual_key_codes, "win32_virtual_key_codes")
			run_test (agent t.test_control_resolver_routes, "control_resolver_routes")
			run_test (agent t.test_controller_marker_count_in_and_queries, "controller_marker_count_in_and_queries")
			run_test (agent t.test_controller_edit_range_again_and_wrap, "controller_edit_range_again_and_wrap")
			run_test (agent t.test_transitions_partition_actions, "transitions_partition_actions")
			run_test (agent t.test_recording_clock_samples_and_interpolation, "recording_clock_samples_and_interpolation")
			run_test (agent t.test_preflight_reports_problems, "preflight_reports_problems")
			run_test (agent t.test_capture_plan_fields, "capture_plan_fields")
			run_test (agent t.test_session_analysis_and_cuts, "session_analysis_and_cuts")
			run_test (agent t.test_facade_feeds_voice_and_heard, "facade_feeds_voice_and_heard")
		end

	run_coverage_core_tests
		local
			t: TEST_COVERAGE_CORE
		do
			section ("coverage: following, pipeline, assembly, outputs, script (phase 5)")
			create t
			run_test (agent t.test_time_span_queries, "time_span_queries")
			run_test (agent t.test_word_timeline_queries, "word_timeline_queries")
			run_test (agent t.test_equivalence_tables, "equivalence_tables")
			run_test (agent t.test_matcher_queries, "matcher_queries")
			run_test (agent t.test_aligner_reanchor_and_constants, "aligner_reanchor_and_constants")
			run_test (agent t.test_alignment_record, "alignment_record")
			run_test (agent t.test_constant_follower_speed, "constant_follower_speed")
			run_test (agent t.test_voice_gated_ramps, "voice_gated_ramps")
			run_test (agent t.test_tracking_follower_steers_and_coasts, "tracking_follower_steers_and_coasts")
			run_test (agent t.test_layout_lines_and_scroll, "layout_lines_and_scroll")
			run_test (agent t.test_spring_rate_and_reset, "spring_rate_and_reset")
			run_test (agent t.test_pipeline_threshold_decoding_and_frames, "pipeline_threshold_decoding_and_frames")
			run_test (agent t.test_speech_codec_heard_round_trip, "speech_codec_heard_round_trip")
			run_test (agent t.test_voice_frame_seconds_and_fakes, "voice_frame_seconds_and_fakes")
			run_test (agent t.test_cut_and_cut_list_queries, "cut_and_cut_list_queries")
			run_test (agent t.test_attempt_and_builder, "attempt_and_builder")
			run_test (agent t.test_take_solver_queries, "take_solver_queries")
			run_test (agent t.test_flagger_low_confidence_restart_and_pause, "flagger_low_confidence_restart_and_pause")
			run_test (agent t.test_snapper_pads_and_words_inside, "snapper_pads_and_words_inside")
			run_test (agent t.test_analysis_records, "analysis_records")
			run_test (agent t.test_snapper_steps_over_vad_margins, "snapper_steps_over_vad_margins")
			run_test (agent t.test_silence_searches_and_speech_map, "silence_searches_and_speech_map")
			run_test (agent t.test_captions_vtt_and_cue_words, "captions_vtt_and_cue_words")
			run_test (agent t.test_edl_helpers, "edl_helpers")
			run_test (agent t.test_cut_codec_errors_and_objects, "cut_codec_errors_and_objects")
			run_test (agent t.test_render_plan_fields, "render_plan_fields")
			run_test (agent t.test_review_srt_helpers, "review_srt_helpers")
			run_test (agent t.test_chapter_and_timecode_helpers, "chapter_and_timecode_helpers")
			run_test (agent t.test_script_edit_kinds, "script_edit_kinds")
			run_test (agent t.test_restart_policy_units, "restart_policy_units")
			run_test (agent t.test_script_parser_classification, "script_parser_classification")
			run_test (agent t.test_revision_and_structure_queries, "revision_and_structure_queries")
			run_test (agent t.test_history_ids_and_journal_status, "history_ids_and_journal_status")
			run_test (agent t.test_event_names_and_edit_fields, "event_names_and_edit_fields")
			run_test (agent t.test_fixed_measure_and_heard_word, "fixed_measure_and_heard_word")
		end

	run_pill_tests
		local
			t: TEST_PILL
		do
			section ("pill geometry, placement, keys (plan step 1)")
			create t
			run_test (agent t.test_word_positions_match_the_layout, "word_positions_match_the_layout")
			run_test (agent t.test_hit_testing, "hit_testing")
			run_test (agent t.test_visible_lines, "visible_lines")
			run_test (agent t.test_hold_offers_the_passage_start, "hold_offers_the_passage_start")
			run_test (agent t.test_hold_never_offers_a_cue, "hold_never_offers_a_cue")
			run_test (agent t.test_pill_position_survives_a_restart, "pill_position_survives_a_restart")
			run_test (agent t.test_all_bindings_lists_every_binding, "all_bindings_lists_every_binding")
			run_test (agent t.test_transport_bar_hits_every_button, "transport_bar_hits_every_button")
			run_test (agent t.test_transport_bar_narrows_to_fit, "transport_bar_narrows_to_fit")
			run_test (agent t.test_transport_bar_progress_and_jump, "transport_bar_progress_and_jump")
			run_test (agent t.test_transport_bar_signature_tracks_what_is_drawn, "transport_bar_signature_tracks_what_is_drawn")
			run_test (agent t.test_transport_bar_tooltips, "transport_bar_tooltips")
		end

	run_heard_stabilizer_tests
		local
			t: TEST_HEARD_STABILIZER
		do
			section ("Heard stabilizer (live local agreement)")
			create t
			run_test (agent t.test_first_decode_trusts_nothing, "first_decode_trusts_nothing")
			run_test (agent t.test_agreed_words_pass, "agreed_words_pass")
			run_test (agent t.test_invented_tail_is_dropped, "invented_tail_is_dropped")
			run_test (agent t.test_disagreeing_words_are_dropped, "disagreeing_words_are_dropped")
			run_test (agent t.test_same_word_far_away_is_not_agreement, "same_word_far_away_is_not_agreement")
			run_test (agent t.test_reset_forgets, "reset_forgets")
			run_test (agent t.test_constants, "constants")
		end

	run_live_alignment_tests
		local
			t: TEST_LIVE_ALIGNMENT
		do
			section ("Aligner fixes from the live replay")
			create t
			run_test (agent t.test_spoken_distance_skips_cues, "spoken_distance_skips_cues")
			run_test (agent t.test_cue_is_not_a_jump, "cue_is_not_a_jump")
			run_test (agent t.test_close_words_of_one_window_all_count, "close_words_of_one_window_all_count")
			run_test (agent t.test_restamped_words_are_not_buffered_twice, "restamped_words_are_not_buffered_twice")
			run_test (agent t.test_column_width_relays_out_in_place, "column_width_relays_out_in_place")
		end

	run_sessions_tests
		local
			t: TEST_SESSIONS
		do
			section ("Take Studio sessions (Step 4a)")
			create t
			run_test (agent t.test_session_on_disk, "session_on_disk")
			run_test (agent t.test_recording_clock_restarts, "recording_clock_restarts")
			run_test (agent t.test_raw_recording_has_small_clusters, "raw_recording_has_small_clusters")
			run_test (agent t.test_loader_reads_a_session_back, "loader_reads_a_session_back")
		end

feature {NONE} -- Implementation

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run one test, counting the outcome. A failing assertion or a
			-- contract violation raises; the rescue reports it and goes on.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				say ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			say ("  FAIL: " + a_name + failure_detail + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

	failure_detail: STRING
			-- " [EXCEPTION: tag]" of the exception being rescued, when there is one.
		local
			l_factory: EXCEPTION_MANAGER_FACTORY
			l_utf: UTF_CONVERTER
		do
			create Result.make_empty
			create l_factory
			if attached l_factory.exception_manager.last_exception as al_exception then
				Result.append (" [")
				Result.append (al_exception.generator)
				if attached al_exception.description as al_text then
					Result.append (": ")
					Result.append (l_utf.string_32_to_utf_8_string_8 (al_text))
				end
				Result.append ("]")
			end
		end

	section (a_name: STRING)
			-- Print a section heading.
		do
			say ("%N-- " + a_name + " --%N")
		end

	say (a_text: STRING)
			-- Print `a_text' and flush, so a crash cannot swallow it.
		do
			io.put_string (a_text)
			io.output.flush
		end

end
