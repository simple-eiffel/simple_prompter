note
	description: "[
		Fixes found by the live replay of larry_read_01 (2026-10-06): cue text
		is no distance, words of one window are never duplicates of each other, and a
		window re-stamping words already buffered adds only what follows them.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_LIVE_ALIGNMENT

inherit
	PT_TEST_SET

feature -- Tests

	test_spoken_distance_skips_cues
		local
			a: PT_ALIGNER
			r: PT_SCRIPT_REVISION
		do
			r := parsed ({STRING_32} "One two three.%N%N[CUE: talk about anything for ten seconds]%N%NFour five six.")
			create a.make (r, create {PT_WORD_MATCHER})
			assert_integers_equal ("three spoken words after the cue", 3, a.spoken_distance (3, r.word_count))
			assert_integers_equal ("nothing between", 0, a.spoken_distance (3, 3))
			assert_true ("cue counted as words", r.word_count > 6)
		end

	test_cue_is_not_a_jump
			-- After "whole" and a twelve-word cue, "now a phrase" (one anchor) is a small step.
		local
			a: PT_ALIGNER
			r: PT_SCRIPT_REVISION
			l_phrase: INTEGER
		do
			r := parsed ({STRING_32} "Hold hole whole.%N%N[CUE: talk off script about anything for about ten seconds then continue reading]%N%NNow a repeated phrase. So when you stop.")
			l_phrase := script_index (r, {STRING_32} "phrase")
			create a.make (r, create {PT_WORD_MATCHER})
			a.reanchor (3, 0)
			a.update (timed_window (16_000, <<[{STRING_32} "now", 0.1], [{STRING_32} "a", 0.4], [{STRING_32} "phrase", 0.6]>>))
			assert_integers_equal ("followed past the cue", l_phrase, a.position)
		end

	test_close_words_of_one_window_all_count
			-- "so I keep natural": "keep" starts 0.08 s after "I" and is still a new word.
		local
			a: PT_ALIGNER
		do
			create a.make (parsed ({STRING_32} "So I keep natural eye contact."), create {PT_WORD_MATCHER})
			a.update (timed_window (0, <<[{STRING_32} "so", 0.10], [{STRING_32} "i", 0.25], [{STRING_32} "keep", 0.33], [{STRING_32} "natural", 0.60]>>))
			assert_true ("keep buffered", across a.heard_tail as ic some ic.same_string ({STRING_32} "keep") end)
			assert_integers_equal ("four words", 4, a.heard_tail.count)
		end

	test_restamped_words_are_not_buffered_twice
			-- The next window stamps "this is a test" up to a second later; only "prompter" is new.
		local
			a: PT_ALIGNER
		do
			create a.make (parsed ({STRING_32} "This is a test of simple prompter."), create {PT_WORD_MATCHER})
			a.update (timed_window (0, <<[{STRING_32} "this", 0.2], [{STRING_32} "is", 0.6], [{STRING_32} "a", 0.9],
				[{STRING_32} "test", 1.2], [{STRING_32} "of", 1.5], [{STRING_32} "simple", 1.6]>>))
			a.update (timed_window (4_000, <<[{STRING_32} "this", 0.75], [{STRING_32} "is", 1.2], [{STRING_32} "a", 1.4],
				[{STRING_32} "test", 1.5], [{STRING_32} "of", 1.65], [{STRING_32} "simple", 1.85], [{STRING_32} "prompter", 2.4]>>))
			assert_integers_equal ("seven words once each", 7, a.heard_tail.count)
			assert_strings_equal ("newest", "prompter", a.heard_tail.last)
			assert_integers_equal ("at the end", 7, a.position)
		end

	test_column_width_relays_out_in_place
			-- Sizing the pill narrower lays the script out on more lines and keeps the reader's place.
		local
			p: SIMPLE_PROMPTER
			l_lines, l_reader: INTEGER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p := p.with_measure (create {PT_FIXED_MEASURE}.make (10.0, 20.0), 400.0)
			p.load_script_text ({STRING_32} "t", {STRING_32} "One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen fifteen sixteen.")
			p.perform ({PT_ACTION}.Play)
			p.perform ({PT_ACTION}.Count_in_done)
			p.controller.follower.advance (2.0)
			l_lines := p.layout.line_count
			l_reader := p.controller.reader_position
			p.set_column_width (120.0)
			assert_integers_equal ("width kept", 120, p.column_width)
			assert_true ("more lines when narrower", p.layout.line_count > l_lines)
			assert_integers_equal ("every word laid out", p.history.current_revision.word_count, p.layout.word_count)
			assert_integers_equal ("reader kept", l_reader, p.controller.reader_position)
		end

feature {NONE} -- Fixtures

	parsed (a_text: READABLE_STRING_32): PT_SCRIPT_REVISION
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "t", a_text, 1, create {PT_ID_SOURCE}.make)
			Result := p.last_revision
		end

	timed_window (a_start: INTEGER_64; a_words: ARRAY [TUPLE [text: STRING_32; t0: REAL_64]]): PT_HEARD_WORDS
			-- A 3 s window starting at sample `a_start'.
		local
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
		do
			create l_words.make (a_words.count)
			across a_words as ic loop
				l_words.extend (create {PT_HEARD_WORD}.make (ic.text, ic.text, ic.t0, ic.t0 + 0.1, 0.9))
			end
			create Result.make (a_start, 48_000, l_words)
		end

	script_index (a_revision: PT_SCRIPT_REVISION; a_normalized: READABLE_STRING_32): INTEGER
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

end
