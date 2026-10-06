note
	description: "Assembly cluster: spans, speech map, cut list, attempt builder, solver, snapper, flagger, analyzer."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_ASSEMBLY

inherit
	PT_TEST_SET

feature -- Tests: values

	test_speech_map_silence
		local
			m: PT_SPEECH_MAP
		do
			create m.make (10.0)
			m.extend_span (span (1.0, 3.0))
			m.extend_span (span (4.0, 9.0))
			assert_true ("silent before", m.is_silent_at (0.5))
			assert_false ("speech", m.is_silent_at (2.0))
			assert_true ("gap", m.is_silent_at (3.5))
		end

	test_cut_list_output_mapping
		local
			l: PT_CUT_LIST
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 4.2), <<id (1), id (2)>>, 1, 2, 1, False))
			l.extend (create {PT_CUT}.make (0, span (9.5, 17.0), <<id (3)>>, 3, 3, 2, False))
			assert_reals_equal ("duration", 11.7, l.output_duration, 1.0e-9)
			assert_true ("9.6 kept", l.is_kept (0, 9.6))
			assert_false ("5.0 on the floor", l.is_kept (0, 5.0))
			assert_reals_equal ("maps like the spike", 4.3, l.to_output_time (0, 9.6), 1.0e-9)
			assert_integers_equal ("words in order", 3, l.words_model.count)
		end

	test_cut_list_refuses_script_disorder
		local
			l: PT_CUT_LIST
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 2.0), <<id (5)>>, 5, 5, 1, False))
			assert_refused ("earlier words refused", agent l.extend (create {PT_CUT}.make (0, span (3.0, 4.0), <<id (2)>>, 2, 2, 2, False)))
		end

	test_floor_is_the_complement
		local
			l: PT_CUT_LIST
			f: ARRAYED_LIST [PT_TIME_SPAN]
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (2.0, 5.0), <<id (1)>>, 1, 1, 1, False))
			f := l.floor_spans (0, 10.0)
			assert_integers_equal ("two floor pieces", 2, f.count)
		end

feature -- Tests: attempts and solver (Phase 4 behavior)

	test_attempt_per_resume
		local
			b: PT_ATTEMPT_BUILDER
			j: PT_JOURNAL
			r: PT_SCRIPT_REVISION
		do
			r := moody
			j := cough_journal (r)
			create b.make
			b.build (j, history_of (r), 20.0)
			assert_integers_equal ("two attempts", 2, b.last_attempts.count)
		end

	test_solver_exact_cover_after_cough
		local
			s: PT_TAKE_SOLVER
			r: PT_SCRIPT_REVISION
			h: PT_SCRIPT_HISTORY
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
		do
			r := revision_of (<<{STRING_32} "One two three.", {STRING_32} "Four five six.">>)
			h := history_of (r)
			create l_attempts.make (2)
				-- Attempt 1 read sentence 1 and part of 2, then a cough; attempt 2 re-read sentence 2.
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (1.0, 4.0), r.word (1).id, 1, 1, 5, False, False))
			l_attempts.extend (create {PT_ATTEMPT}.make (2, span (6.0, 8.0), r.word (4).id, 1, 4, 6, False, False))
			create s.make (1.0, 0.1, 0.5)
			s.solve (h, l_attempts, create {PT_WORD_TIMELINE}.make)
			assert_true ("complete", s.is_complete)
			assert_integers_equal ("two cuts", 2, s.last_result.count)
			assert_integers_equal ("sentence 2 from the retake", 2, s.last_result.cut (2).attempt)
		end

	test_analyzer_reports_transcriber_failure
		local
			a: PT_SESSION_ANALYZER
			r: PT_SCRIPT_REVISION
		do
			r := moody
			create a.make (create {PT_SCRIPTED_TRANSCRIBER}.make_failing ({STRING_32} "model missing"),
				create {PT_ATTEMPT_BUILDER}.make, create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
				create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
				create {PT_FLAGGER}.make (2.0))
			a.analyze ({STRING_32} "raw.mkv", 20.0, cough_journal (r), history_of (r))
			assert_false ("failed analysis", a.last_analysis.is_success)
		end

	test_flagger_flags_every_tight_cut
		local
			f: PT_FLAGGER
			l: PT_CUT_LIST
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 2.0), <<id (1)>>, 1, 1, 1, True))
			create f.make (2.0)
			f.flag (l, create {ARRAYED_LIST [PT_WORD_ID]}.make (0), create {PT_WORD_TIMELINE}.make, create {PT_SPEECH_MAP}.make (5.0))
			assert_integers_equal ("one tight flag", 1, f.count_of ({PT_FLAG_KIND}.Tight_splice))
		end

feature {NONE} -- Fixtures

	cough_journal (a_revision: PT_SCRIPT_REVISION): PT_JOURNAL
			-- Resume at 1 s; flub at 6 s; resume at 8 s from sentence 4; wrap at 18 s.
		do
			create Result.make_in_memory
			Result.append (create {PT_TAKE_EVENT}.make_session_start (0.0, 1, {STRING_32} "tracking"))
			Result.append (create {PT_TAKE_EVENT}.make_resume (1.0, a_revision.word (1).id, 1))
			Result.append (create {PT_TAKE_EVENT}.make_flub (6.0, a_revision.word (a_revision.passage (4).first_word + 3).id, "clicker"))
			Result.append (create {PT_TAKE_EVENT}.make_rewind_to (6.0, a_revision.word (a_revision.passage (4).first_word).id, {STRING_32} "again_default"))
			Result.append (create {PT_TAKE_EVENT}.make_count_in (6.0, 2.0))
			Result.append (create {PT_TAKE_EVENT}.make_resume (8.0, a_revision.word (a_revision.passage (4).first_word).id, 1))
			Result.append (create {PT_TAKE_EVENT}.make_wrap (18.0, "hotkey"))
		end

end
