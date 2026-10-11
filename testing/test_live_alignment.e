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

	test_reheard_words_never_move_twice
			-- Reel 2 "Devil's Half Right" (2026-10-11, 4.9 s): the next window re-heard "the devil
			-- got it half right" with nothing new, and the aligner moved those used words on to the
			-- echo "he got it exactly half right" 23 words later, two lines down.
		local
			a: PT_ALIGNER
			r: PT_SCRIPT_REVISION
			l_first: INTEGER
		do
			r := parsed ({STRING_32} "The Devil got it half right. What do I mean? Simply that the devil quoted the Bible to Jesus, word for word. And he got it exactly half right.")
			l_first := script_index (r, {STRING_32} "right")
			create a.make (r, create {PT_WORD_MATCHER})
			a.update (timed_window (24_000, <<[{STRING_32} "well", 0.1], [{STRING_32} "the", 0.4], [{STRING_32} "devil", 0.7],
				[{STRING_32} "got", 1.3], [{STRING_32} "it", 1.6], [{STRING_32} "half", 2.0], [{STRING_32} "right", 2.4]>>))
			assert_integers_equal ("on the first 'right'", l_first, a.position)
			a.update (timed_window (28_000, <<[{STRING_32} "well", 0.0], [{STRING_32} "devil", 0.45],
				[{STRING_32} "got", 1.05], [{STRING_32} "it", 1.35], [{STRING_32} "half", 1.75], [{STRING_32} "right", 2.15]>>))
			assert_integers_equal ("re-heard words stay put", l_first, a.position)
			a.update (timed_window (36_000, <<[{STRING_32} "half", 1.25], [{STRING_32} "right", 1.65], [{STRING_32} "what", 2.1],
				[{STRING_32} "do", 2.3], [{STRING_32} "i", 2.45], [{STRING_32} "mean", 2.6]>>))
			assert_integers_equal ("follows the new words", script_index (r, {STRING_32} "mean"), a.position)
		end

	test_few_new_anchors_still_follow
			-- Take 2026-10-11 08:39, 18.6 s (0.5.2): after "Jesus" the buffer gained only "the the
			-- and and says" (one new anchor), the move to "says" needed two, and 0.5.2 counted new
			-- anchors only, so the text stopped there for good while Larry read on. Old words give
			-- the context; new words bound how far the text may go.
		local
			a: PT_ALIGNER
			r: PT_SCRIPT_REVISION
		do
			r := parsed ({STRING_32} "Matthew chapter four. The devil takes Jesus to the pinnacle of the temple and says, If You are the Son of God, throw Yourself down.")
			create a.make (r, create {PT_WORD_MATCHER})
			a.update (timed_window (0, <<[{STRING_32} "matthew", 0.3], [{STRING_32} "chapter", 0.7], [{STRING_32} "four", 1.1],
				[{STRING_32} "the", 1.5], [{STRING_32} "devil", 1.8], [{STRING_32} "takes", 2.2], [{STRING_32} "jesus", 2.6]>>))
			assert_integers_equal ("on 'Jesus'", script_index (r, {STRING_32} "jesus"), a.position)
			a.update (timed_window (48_000, <<[{STRING_32} "the", 0.3], [{STRING_32} "the", 0.8], [{STRING_32} "and", 1.4],
				[{STRING_32} "and", 1.9], [{STRING_32} "says", 2.4]>>))
			assert_integers_equal ("on to 'says'", script_index (r, {STRING_32} "says"), a.position)
		end

	test_search_ends_at_the_visible_words
			-- Larry, 2026-10-11: the reader is on the visible words or off script. A phrase read
			-- past the last visible word never moves the text; the same phrase on the page does.
		local
			a: PT_ALIGNER
			r: PT_SCRIPT_REVISION
		do
			r := parsed ({STRING_32} "Alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec.")
			create a.make (r, create {PT_WORD_MATCHER})
			a.reanchor (script_index (r, {STRING_32} "hotel"), 0)
			a.set_visible_last (script_index (r, {STRING_32} "india"))
			a.update (timed_window (0, <<[{STRING_32} "india", 0.5], [{STRING_32} "juliet", 0.9], [{STRING_32} "kilo", 1.3]>>))
			assert_true ("no further than the page", a.position <= script_index (r, {STRING_32} "india"))
			a.set_visible_last (r.word_count)
			a.update (timed_window (32_000, <<[{STRING_32} "juliet", 0.5], [{STRING_32} "kilo", 0.9], [{STRING_32} "lima", 1.3]>>))
			assert_integers_equal ("on the page: follows", script_index (r, {STRING_32} "lima"), a.position)
		end

	test_nudge_puts_text_and_pointer_on_the_next_line
			-- Larry, 2026-10-11: "allow me to force the scroll forward ... and force the pointer in
			-- the software to where I am reading". While reading, a nudge moves both to the line
			-- after the reading row, and the reading goes on.
		local
			p: SIMPLE_PROMPTER
			l_next: INTEGER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p := p.with_measure (create {PT_FIXED_MEASURE}.make (10.0, 20.0), 200.0)
			p.load_script_text ({STRING_32} "t", {STRING_32} "One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen.")
			p.perform ({PT_ACTION}.Play)
			p.perform ({PT_ACTION}.Count_in_done)
			assert_true ("more than one line", p.layout.line_count >= 3)
			l_next := p.layout.line (2).first_word - 1
			p.nudge_forward
			assert_integers_equal ("pointer on the next line", l_next, p.aligner.position)
			assert_true ("text on the next line", p.follower.target = l_next.to_double)
			assert_integers_equal ("still reading", {PT_TAKE_STATE}.Reading, p.controller.state)
			p.nudge_forward
			assert_integers_equal ("and the one after", p.layout.line (3).first_word - 1, p.aligner.position)
		end

	test_visible_words_stop_above_the_fade
			-- Larry, 2026-10-11: only fully shown words count; the faded bottom line is the next
			-- line coming into view. Five lines show: the reading row (second) and the two under
			-- it are clear, the fifth sits in the fade.
		local
			p: SIMPLE_PROMPTER
			s: PT_SETTINGS
		do
			create s.make_in_memory
			s.set_lines_visible (5)
			create p.make_with_settings (s)
			p := p.with_measure (create {PT_FIXED_MEASURE}.make (10.0, 20.0), 200.0)
			p.load_script_text ({STRING_32} "t", {STRING_32} "One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty. Twenty-one twenty-two twenty-three twenty-four twenty-five twenty-six.")
			assert_true ("enough lines", p.layout.line_count >= 5)
			assert_integers_equal ("three clear lines from the top", p.layout.line (3).last_word, p.visible_last_word)
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
