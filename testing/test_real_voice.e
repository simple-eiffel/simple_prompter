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
