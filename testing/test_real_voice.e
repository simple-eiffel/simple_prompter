note
	description: "[
		Task 24: replay Larry's real recording (larry_read_01, whisper word times saved in
		testing/fixtures/larry_read_01.words.tsv) through PT_ALIGNER over the parsed
		read_test_01.md, in 3 s windows every 250 ms as the live pipeline would decode.
		Acceptance for Tracking (approved intent Q5): within one line (8 words) of
		distinctive words, hold during the ad-lib, jump the skipped paragraph, never move
		backward (Larry made no restarts).
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_REAL_VOICE

inherit
	PT_TEST_SET

feature -- Tests

	test_tracking_follows_larry_within_a_line
		local
			l_steps: ARRAYED_LIST [INTEGER]
			l_revision: PT_SCRIPT_REVISION
			l_failures: STRING_32
		do
			l_revision := script
			l_steps := replay (l_revision)
			create l_failures.make_empty
			across << {STRING_32} "teleprompter", {STRING_32} "camera", {STRING_32} "specification",
				{STRING_32} "gigabytes", {STRING_32} "watching", {STRING_32} "repeated", {STRING_32} "waits",
				{STRING_32} "processors", {STRING_32} "construction", {STRING_32} "patience" >> as ic loop
				check_point (l_revision, l_steps, ic, l_failures)
			end
			assert_true ({STRING_32} "within one line at every checkpoint" + l_failures, l_failures.is_empty)
		end

	test_tracking_holds_during_the_ad_lib
		local
			l_steps: ARRAYED_LIST [INTEGER]
		do
			l_steps := replay (script)
			assert_integers_equal ("no movement from 83 s to 93.5 s", position_at (l_steps, 83.0), position_at (l_steps, 93.5))
		end

	test_tracking_jumps_the_skipped_paragraph
		local
			l_steps: ARRAYED_LIST [INTEGER]
			l_revision: PT_SCRIPT_REVISION
		do
			l_revision := script
			l_steps := replay (l_revision)
			assert_greater_than ("past 'lost' (end of the skipped paragraph) one second after 'processors' (the third content word after the skip)",
				position_at (l_steps, heard_time ({STRING_32} "processors") + 1.0), index_of_word (l_revision, {STRING_32} "lost"))
		end

	test_tracking_never_moves_backward
		local
			l_steps: ARRAYED_LIST [INTEGER]
			i, l_back: INTEGER
		do
			l_steps := replay (script)
			from i := 2 until i > l_steps.count loop
				if l_steps [i] < l_steps [i - 1] then
					l_back := l_back + 1
				end
				i := i + 1
			end
			assert_integers_equal ("no backward moves", 0, l_back)
		end

	test_aligner_meets_frame_budget
			-- NFR-003: one aligner update over the whole replay costs less than a 60 Hz GUI frame
			-- (16 ms), even in this contract-checked build. Measured 2026-10-05: 2.5 ms here,
			-- 0.11 ms in the lean build.
		local
			a: PT_ALIGNER
			n: PT_NORMALIZER
			t, l_start, l_t0, l_update: REAL_64
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_windows: ARRAYED_LIST [PT_HEARD_WORDS]
			l_revision: PT_SCRIPT_REVISION
		do
			l_revision := script
			create n
			create l_windows.make (600)
			from t := Step_s until t > 145.0 loop
				l_start := (t - Window_s).max (0)
				create l_words.make (8)
				across heard_words as ic loop
					if ic.t0 >= l_start and ic.t0 < t then
						l_words.extend (create {PT_HEARD_WORD}.make (ic.text, n.normalized (ic.text), ic.t0 - l_start, (ic.t1 - l_start).max (ic.t0 - l_start), 0.9))
					end
				end
				l_windows.extend (create {PT_HEARD_WORDS}.make ((l_start * 16_000).truncated_to_integer_64, 48_000, l_words))
				t := t + Step_s
			end
			create a.make (l_revision, create {PT_WORD_MATCHER})
			l_t0 := now_ms
			across l_windows as ic loop
				a.update (ic)
			end
			l_update := now_ms - l_t0
			assert_true ("under one frame per update: " + (l_update / l_windows.count).out + " ms", l_update / l_windows.count < Frame_budget_ms)
		end

	Frame_budget_ms: REAL_64 = 16.0
			-- One 60 Hz frame.

	now_ms: REAL_64
			-- High-resolution clock (QueryPerformanceCounter), milliseconds.
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

	test_misreads_on_larry_read_01
			-- T18: on the real recording, "5070" heard as "55070" is a misread; equivalence-class
			-- matches (homophones, "for example" for "e.g.", number words) never are.
		local
			l_aligner: PT_ATTEMPT_ALIGNER
			l_revision: PT_SCRIPT_REVISION
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
			l_found_55070, l_none_equivalent: BOOLEAN
		do
			l_revision := script
			create l_attempts.make (1)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, create {PT_TIME_SPAN}.make (0, 144.02), l_revision.word (1).id,
				1, 1, l_revision.word_count, False, False))
			create l_aligner.make (create {PT_WORD_MATCHER})
			l_aligner.align (l_attempts, history_of (l_revision), whole_recording)
			l_none_equivalent := True
			across l_aligner.last_misreads as ic loop
				if ic.heard_text.same_string ({STRING_32} "55070") and ic.script_text.has_substring ({STRING_32} "5070") then
					l_found_55070 := True
				end
				if l_aligner.matcher.equivalences.are_equivalent (ic.heard_text, (create {PT_NORMALIZER}).normalized (ic.script_text)) then
					l_none_equivalent := False
				end
			end
			assert_true ("55070 flagged", l_found_55070)
			assert_true ("no equivalence-class match flagged", l_none_equivalent)
			assert_integers_equal ("exactly one misread (no false flags)", 1, l_aligner.last_misreads.count)
				-- 102 occurrences before the Phase 5 fixes (a long cue line stopped alignment), 214 after.
			assert_true ("timeline covers the read: " + l_aligner.last_timeline.count.out, l_aligner.last_timeline.count >= 200)
		end

	test_analysis_of_larry_read_01
			-- The whole automatic editor on the real recording, one take from start to wrap.
		local
			an: PT_SESSION_ANALYZER
			j: PT_JOURNAL
			l_revision: PT_SCRIPT_REVISION
			l_i, l_skipped: INTEGER
			l_pause_flagged: BOOLEAN
		do
			l_revision := script
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_resume (0.0, l_revision.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_wrap (144.0, "user"))
			create an.make (create {PT_SCRIPTED_TRANSCRIBER}.make (vad_map, whole_recording),
				create {PT_ATTEMPT_BUILDER}.make, create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
				create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
				create {PT_FLAGGER}.make (2.0))
			an.analyze ({STRING_32} "raw.mkv", 144.02, j, history_of (l_revision))
			assert_true ("analyzed", an.last_analysis.is_success)
			assert_integers_equal ("one misread", 1, an.flagger.count_of ({PT_FLAG_KIND}.Misread))
			across an.last_analysis.flags as ic loop
				if ic.kind = {PT_FLAG_KIND}.Misread then
					assert_true ("the 55070 misread", ic.message.has_substring ({STRING_32} "55070"))
				elseif ic.kind = {PT_FLAG_KIND}.Long_pause and then (ic.span.t0 - 19.17).abs < 0.05 then
					l_pause_flagged := True
				end
			end
			assert_true ("instructed pause flagged", l_pause_flagged)
				-- Missing: exactly the paragraph the cue said to skip.
			l_skipped := index_of_word (l_revision, {STRING_32} "skipped")
			assert_integers_equal ("only the skipped paragraph is missing", 30, an.solver.missing_words.count)
			across an.solver.missing_words as ic loop
				assert_true ("missing word in the skipped paragraph",
					l_revision.passage (l_revision.passage_of (l_revision.index_of (ic))).paragraph_index
						= l_revision.word (l_skipped).paragraph_index)
			end
			from l_i := 1 until l_i > an.last_analysis.cuts.count loop
				assert_false ("the ad-lib is cut out", an.last_analysis.cuts.cut (l_i).span.contains (88.0))
				if l_i > 1 then
					assert_true ("cuts never overlap", an.last_analysis.cuts.cut (l_i).span.t0 >= an.last_analysis.cuts.cut (l_i - 1).span.t1)
				end
				l_i := l_i + 1
			end
			assert_true ("about two minutes of output: " + an.last_analysis.cuts.output_duration.out,
				an.last_analysis.cuts.output_duration > 120.0 and an.last_analysis.cuts.output_duration < 130.0)
		end

	vad_map: PT_SPEECH_MAP
			-- VAD speech map of larry_read_01 (144.02 s).
		local
			l_fields: LIST [STRING_32]
		do
			create Result.make (144.02)
			across file_text ("testing/fixtures/larry_read_01.vad.tsv").split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 2 and then l_fields [1].is_double and then l_fields [2].is_double
					and then l_fields [1].to_double >= Result.last_end then
					Result.extend_span (create {PT_TIME_SPAN}.make (l_fields [1].to_double, l_fields [2].to_double))
				end
			end
		end

	whole_recording: PT_HEARD_WORDS
			-- Every heard word of larry_read_01 in one window (absolute seconds).
		local
			n: PT_NORMALIZER
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
		do
			create n
			create l_words.make (heard_words.count)
			across heard_words as ic loop
				if not ic.text.is_empty then
					l_words.extend (create {PT_HEARD_WORD}.make (ic.text, n.normalized (ic.text), ic.t0, ic.t1.max (ic.t0), 0.9))
				end
			end
			create Result.make (0, 145 * 16_000, l_words)
		end

feature {NONE} -- Replay

	Step_s: REAL_64 = 0.25
	Window_s: REAL_64 = 3.0

	script: PT_SCRIPT_REVISION
			-- read_test_01.md parsed.
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "read_test_01", file_text ("testing/fixtures/read_test_01.md"), 1, create {PT_ID_SOURCE}.make)
			Result := p.last_revision
		end

	heard_words: ARRAYED_LIST [TUPLE [t0, t1: REAL_64; text: STRING_32]]
			-- The recording's word times.
		local
			l_fields: LIST [STRING_32]
		once
			create Result.make (256)
			across file_text ("testing/fixtures/larry_read_01.words.tsv").split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 3 and then l_fields [1].is_double and then l_fields [2].is_double then
					Result.extend ([l_fields [1].to_double, l_fields [2].to_double, l_fields [3]])
				end
			end
		end

	replay (a_revision: PT_SCRIPT_REVISION): ARRAYED_LIST [INTEGER]
			-- Aligner position after every 250 ms step.
		local
			a: PT_ALIGNER
			n: PT_NORMALIZER
			t, l_start: REAL_64
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_norm: STRING_32
		do
			create a.make (a_revision, create {PT_WORD_MATCHER})
			create n
			create Result.make (600)
			from t := Step_s until t > 145.0 loop
				l_start := (t - Window_s).max (0)
				create l_words.make (8)
				across heard_words as ic loop
					if ic.t0 >= l_start and ic.t0 < t then
						l_norm := n.normalized (ic.text)
						if not ic.text.is_empty then
							l_words.extend (create {PT_HEARD_WORD}.make (ic.text, l_norm, ic.t0 - l_start, (ic.t1 - l_start).max (ic.t0 - l_start), 0.9))
						end
					end
				end
				a.update (create {PT_HEARD_WORDS}.make ((l_start * 16_000).truncated_to_integer_64, 48_000, l_words))
				Result.extend (a.position)
				t := t + Step_s
			end
		end

	position_at (a_steps: ARRAYED_LIST [INTEGER]; a_t: REAL_64): INTEGER
			-- Position after the step at time `a_t'.
		do
			Result := a_steps [((a_t / Step_s).truncated_to_integer).max (1).min (a_steps.count)]
		end

	heard_time (a_normalized: READABLE_STRING_32): REAL_64
			-- End time of the first heard word whose normal form is `a_normalized'.
		local
			n: PT_NORMALIZER
			l_found: BOOLEAN
		do
			create n
			across heard_words as ic until l_found loop
				if n.normalized (ic.text).same_string (a_normalized) then
					Result := ic.t1
					l_found := True
				end
			end
		end

	index_of_word (a_revision: PT_SCRIPT_REVISION; a_normalized: READABLE_STRING_32): INTEGER
			-- First word index with normal form `a_normalized'.
		local
			i: INTEGER
		do
			from i := 1 until Result > 0 or i > a_revision.word_count loop
				if a_revision.word (i).normalized.same_string (a_normalized) then
					Result := i
				end
				i := i + 1
			end
		end

	check_point (a_revision: PT_SCRIPT_REVISION; a_steps: ARRAYED_LIST [INTEGER]; a_word: READABLE_STRING_32; a_failures: STRING_32)
			-- One second after `a_word' is heard, the position is within 8 words of it.
		local
			l_expected, l_actual: INTEGER
		do
			l_expected := index_of_word (a_revision, a_word)
			l_actual := position_at (a_steps, heard_time (a_word) + 1.0)
			if l_expected = 0 or (l_actual - l_expected).abs > 8 then
				a_failures.append ({STRING_32} " [" + a_word + {STRING_32} ": expected ~" + l_expected.out + {STRING_32} ", got " + l_actual.out + {STRING_32} "]")
			end
		end

	file_text (a_path: READABLE_STRING_GENERAL): STRING_32
			-- UTF-8 text of `a_path'.
		local
			l_raw: STRING_8
		do
			create l_raw.make (4096)
			across (create {SIMPLE_FILE}.make (a_path)).binary_content as ic loop
				l_raw.append_character (ic.to_character_8)
			end
			Result := (create {SIMPLE_ENCODING}.make).utf_8_to_utf_32 (l_raw)
			Result.prune_all ('%R')
		end

end
