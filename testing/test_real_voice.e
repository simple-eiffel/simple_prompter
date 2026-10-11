note
	description: "[
		Task 24: replay Larry's real recording (larry_read_01, whisper word times saved in
		testing/fixtures/larry_read_01.words.tsv) through PT_ALIGNER over the parsed
		read_test_01.md, in 3 s windows every 250 ms as the live pipeline would decode.
		Acceptance for Tracking (approved intent Q5): within one line (8 words) of
		distinctive words, hold during the ad-lib, never move backward (Larry made no
		restarts). 0.5.2: the text never skips (Larry, 2026-10-11), so at the skipped
		paragraph it waits instead of jumping; checkpoints stop before the skip.
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
				{STRING_32} "gigabytes", {STRING_32} "watching", {STRING_32} "repeated", {STRING_32} "waits" >> as ic loop
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

	test_tracking_waits_at_the_skipped_paragraph
			-- Larry read on past a paragraph; the text never skips it, it waits there to the end.
		local
			l_steps: ARRAYED_LIST [INTEGER]
			l_revision: PT_SCRIPT_REVISION
		do
			l_revision := script
			l_steps := replay (l_revision)
			assert_true ("never past 'skipped' (start of the skipped paragraph)",
				l_steps.last < index_of_word (l_revision, {STRING_32} "skipped"))
			assert_true ("followed up to the skip", position_at (l_steps, heard_time ({STRING_32} "waits") + 1.0)
				>= index_of_word (l_revision, {STRING_32} "waits") - 8)
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

	test_devils_half_right_never_jumps_to_the_echo
			-- Take 2026-10-11 08:07 (0.5.1): at 4.9 s the re-heard first sentence moved the text to
			-- its echo "he got it exactly half right" two lines down. Replayed from the journal's
			-- heard lines, the text never reaches the echo.
		local
			l_revision: PT_SCRIPT_REVISION
			l_steps: ARRAYED_LIST [INTEGER]
			l_most: INTEGER
		do
			l_revision := devils_script
			l_steps := replay_heard ("testing/fixtures/devils_half_right_0807.heard.tsv", l_revision)
			across l_steps as ic loop
				l_most := l_most.max (ic)
			end
			assert_true ("never as far as 'quoted' (he stopped at 'what do I mean'): " + l_most.out,
				l_most < index_of_word (l_revision, {STRING_32} "quoted"))
		end

	test_devils_half_right_follows_to_the_end
			-- Take 2026-10-11 08:39 (0.5.2): the text stopped at "Jesus" (18.6 s) while Larry read on
			-- to "concerning" (27.6 s). Replayed from the journal's heard lines, it follows him there.
		local
			l_revision: PT_SCRIPT_REVISION
			l_steps: ARRAYED_LIST [INTEGER]
		do
			l_revision := devils_script
			l_steps := replay_heard ("testing/fixtures/devils_half_right_0839.heard.tsv", l_revision)
			assert_true ("within a line of 'concerning' at the end: " + l_steps.last.out,
				l_steps.last >= index_of_word (l_revision, {STRING_32} "concerning") - 8
				and l_steps.last <= index_of_word (l_revision, {STRING_32} "concerning") + 4)
		end

	test_devils_half_right_0903_follows_without_the_wheel
			-- Take 2026-10-11 09:03 (0.5.3): the text never moved by itself; Larry turned the
			-- wheel 23 times. Replayed from the journal's heard lines with their real word times,
			-- and no wheel, the text follows him: past "further" (said at 41.9 s) by 42.5 s, and
			-- at the end between "glorify" (58 s) and "jump" (not yet said at the wrap).
		local
			l_revision: PT_SCRIPT_REVISION
			l_steps: ARRAYED_LIST [TUPLE [t: REAL_64; position: INTEGER]]
			l_at_further: INTEGER
		do
			l_revision := devils_script
			l_steps := replay_timed ("testing/fixtures/devils_half_right_0903.heard.tsv", l_revision, False)
			across l_steps as ic loop
				if ic.t <= 42.5 then
					l_at_further := ic.position
				end
			end
			assert_true ("near 'further' at 42.5 s: " + l_at_further.out,
				l_at_further >= index_of_word (l_revision, {STRING_32} "further") - 8)
			assert_true ("at the end, after 'glorify' and before 'jump': " + l_steps.last.position.out,
				l_steps.last.position >= index_of_word (l_revision, {STRING_32} "glorify")
				and l_steps.last.position < index_of_word (l_revision, {STRING_32} "jump"))
		end

	test_devils_half_right_0947_keeps_up
			-- Take 2026-10-11 09:47 (0.5.4): the text followed by itself but waited about 3 s
			-- for each catch-up, 15 times (the merged word list kept about half the words said).
			-- Replayed with the real word times, against the take analyzer's timeline of when
			-- each word was said: how far the aligner trails the reader, in spoken words.
		local
			l_revision: PT_SCRIPT_REVISION
			l_steps: ARRAYED_LIST [TUPLE [t: REAL_64; position: INTEGER]]
			l_said: ARRAYED_LIST [TUPLE [w: INTEGER; t0, t1: REAL_64]]
			l_fields: LIST [STRING_32]
			l_truth, l_lag, l_count, l_far, l_ahead: INTEGER
			l_sum: REAL_64
		do
			l_revision := devils_script
			create l_said.make (400)
			across file_text ("testing/fixtures/devils_half_right_0947.said.tsv").split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 3 and then l_fields [1].is_integer and then l_fields [2].is_double then
					l_said.extend ([l_fields [1].to_integer, l_fields [2].to_double, l_fields [3].to_double])
				end
			end
			l_steps := replay_timed ("testing/fixtures/devils_half_right_0947.heard.tsv", l_revision, True)
			across l_steps as ic loop
				l_truth := 0
				across l_said as s loop
					if s.t1 <= ic.t - 0.3 then
						l_truth := l_truth.max (s.w)
					end
				end
				if l_truth > 0 then
					if l_truth >= ic.position then
						l_lag := spoken_between (l_revision, ic.position, l_truth)
					else
						l_lag := -spoken_between (l_revision, l_truth, ic.position)
					end
					l_sum := l_sum + l_lag.max (0)
					l_count := l_count + 1
					if l_lag >= 8 then
						l_far := l_far + 1
					end
					l_ahead := l_ahead.max (-l_lag)
				end
			end
			assert_true ("keeps up: mean lag " + (l_sum / l_count.max (1)).out + " words, " + l_far.out + " of "
				+ l_count.out + " decodes a line (8+) behind, at most " + l_ahead.out + " ahead",
				l_sum / l_count.max (1) <= Mean_lag_limit and l_far <= Far_limit and l_ahead <= Ahead_limit)
		end

	Mean_lag_limit: REAL_64 = 1.6
	Far_limit: INTEGER = 15
	Ahead_limit: INTEGER = 5
			-- Measured 2026-10-11 on this replay with a five-line pill: 0.5.4 trailed by 1.63
			-- words on average with 18 of 476 decodes a line behind; 0.5.5 1.58 and 14, never
			-- more than 5 words ahead.

	spoken_between (a_revision: PT_SCRIPT_REVISION; a_from, a_to: INTEGER): INTEGER
			-- Spoken (non-cue) words in `a_from' + 1 .. `a_to'.
		local
			i: INTEGER
		do
			from i := a_from + 1 until i > a_to loop
				if not a_revision.word (i).is_cue then
					Result := Result + 1
				end
				i := i + 1
			end
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

	devils_script: PT_SCRIPT_REVISION
			-- Reel 2 "Devil's Half Right" (2026-10-11).
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "devils_half_right", file_text ("testing/fixtures/devils_half_right.md"), 1, create {PT_ID_SOURCE}.make)
			Result := p.last_revision
		end

	replay_heard (a_fixture: READABLE_STRING_GENERAL; a_revision: PT_SCRIPT_REVISION): ARRAYED_LIST [INTEGER]
			-- Aligner position after each decode of `a_fixture' (a take's journal "heard" lines:
			-- window start and end in seconds, the words). The journal keeps no word times, so the
			-- words are spaced 0.3 s apart ending 0.2 s before the window ends, as live decodes
			-- place the newest speech.
		local
			a: PT_ALIGNER
			n: PT_NORMALIZER
			l_fields, l_texts: LIST [STRING_32]
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_w0, l_span, l_t0: REAL_64
			i: INTEGER
		do
			create a.make (a_revision, create {PT_WORD_MATCHER})
			create n
			create Result.make (128)
			across file_text (a_fixture).split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 3 and then l_fields [1].is_double and then l_fields [2].is_double then
					l_w0 := l_fields [1].to_double
					l_span := l_fields [2].to_double - l_w0
					create l_words.make (8)
					l_texts := l_fields [3].split (' ')
					from i := 1 until i > l_texts.count loop
						if not n.normalized (l_texts [i]).is_empty then
							l_t0 := (l_span - 0.2 - (l_texts.count - i) * 0.3).max (0.0)
							l_words.extend (create {PT_HEARD_WORD}.make (l_texts [i], n.normalized (l_texts [i]), l_t0, l_t0 + 0.25, 0.9))
						end
						i := i + 1
					end
					a.update (create {PT_HEARD_WORDS}.make ((l_w0 * 16_000).truncated_to_integer_64, 48_000, l_words))
					Result.extend (a.position)
				end
			end
		end

	replay_timed (a_fixture: READABLE_STRING_GENERAL; a_revision: PT_SCRIPT_REVISION; a_paged: BOOLEAN): ARRAYED_LIST [TUPLE [t: REAL_64; position: INTEGER]]
			-- Aligner position after each decode of `a_fixture' (a take's journal "heard" lines
			-- with word times, 0.5.3 on: window start, window end, words, their start times in
			-- the window; a first "# resume" line gives the resume time), at each window's end.
			-- `a_paged': show the aligner a five-line pill of `Page_line' words a line, the
			-- reading row second, as the prompter does.
		local
			a: PT_ALIGNER
			n: PT_NORMALIZER
			l_fields, l_texts, l_times: LIST [STRING_32]
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_w0, l_t0: REAL_64
			i, l_line: INTEGER
		do
			create a.make (a_revision, create {PT_WORD_MATCHER})
			create n
			create Result.make (256)
			across file_text (a_fixture).split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 2 and then l_fields [1].same_string ({STRING_32} "# resume") and then l_fields [2].is_double then
					a.reanchor (0, (l_fields [2].to_double * 16_000).truncated_to_integer_64)
				elseif l_fields.count = 4 and then l_fields [1].is_double and then l_fields [2].is_double then
					l_w0 := l_fields [1].to_double
					create l_words.make (8)
					l_texts := l_fields [3].split (' ')
					l_times := l_fields [4].split (' ')
					from i := 1 until i > l_texts.count or i > l_times.count loop
						if not n.normalized (l_texts [i]).is_empty and then l_times [i].is_double then
							l_t0 := l_times [i].to_double
							l_words.extend (create {PT_HEARD_WORD}.make (l_texts [i], n.normalized (l_texts [i]), l_t0, l_t0 + 0.25, 0.9))
						end
						i := i + 1
					end
					if a_paged then
						l_line := a.position // Page_line
						a.set_visible (((l_line - 1).max (0) * Page_line + 1).min (a_revision.word_count),
							((l_line + 3) * Page_line).min (a_revision.word_count))
					end
					a.update (create {PT_HEARD_WORDS}.make ((l_w0 * 16_000).truncated_to_integer_64,
						((l_fields [2].to_double - l_w0) * 16_000).truncated_to_integer.max (1), l_words))
					Result.extend ([l_fields [2].to_double, a.position])
				end
			end
		end

	Page_line: INTEGER = 8
			-- Words on a line of the imitated pill.

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
