note
	description: "[
		PT_HEARD_STABILIZER: local agreement between consecutive decodes, and the tail
		guard. Cases from the live replay of larry_read_01 (2026-10-06).
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_HEARD_STABILIZER

inherit
	PT_TEST_SET

feature -- Tests

	test_first_decode_trusts_nothing
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			s.accept (timed_window (0, <<["some", 0.5], ["numbers", 1.0]>>))
			assert_integers_equal ("nothing agreed yet", 0, s.last_stable.count)
			assert_integers_equal ("remembered", 2, s.remembered_count)
		end

	test_agreed_words_pass
			-- The next window (250 ms later) hears the same words a little earlier in its own time.
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			s.accept (timed_window (0, <<["some", 0.5], ["numbers", 1.0]>>))
			s.accept (timed_window (4_000, <<["some", 0.27], ["numbers", 0.74], ["twenty", 1.6]>>))
			assert_integers_equal ("two agreed", 2, s.last_stable.count)
			assert_strings_equal ("first", "some", s.last_stable.word (1).normalized)
			assert_strings_equal ("second", "numbers", s.last_stable.word (2).normalized)
		end

	test_invented_tail_is_dropped
			-- Inventions at the window's end: "going to be in the middle" at the last instant.
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			s.accept (timed_window (0, <<["are", 2.0], ["going", 2.99], ["middle", 2.99]>>))
			s.accept (timed_window (4_000, <<["are", 1.75], ["going", 2.74], ["year", 2.99]>>))
			assert_integers_equal ("only the real word", 1, s.last_stable.count)
			assert_strings_equal ("real", "are", s.last_stable.word (1).normalized)
			assert_integers_equal ("tail not remembered", 1, s.remembered_count)
		end

	test_disagreeing_words_are_dropped
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			s.accept (timed_window (0, <<["sixteen", 1.0], ["gigabytes", 1.5]>>))
			s.accept (timed_window (4_000, <<["sixteen", 0.75], ["gb", 1.25]>>))
			assert_integers_equal ("one agreed", 1, s.last_stable.count)
			assert_strings_equal ("agreed", "sixteen", s.last_stable.word (1).normalized)
		end

	test_same_word_far_away_is_not_agreement
			-- "the" said twice: agreement needs about the same time, not just the same word.
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			s.accept (timed_window (0, <<["the", 0.2]>>))
			s.accept (timed_window (4_000, <<["the", 1.8]>>))
			assert_integers_equal ("too far apart", 0, s.last_stable.count)
		end

	test_reset_forgets
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			s.accept (timed_window (0, <<["some", 0.5]>>))
			s.reset
			assert_integers_equal ("forgotten", 0, s.remembered_count)
			s.accept (timed_window (4_000, <<["some", 0.25]>>))
			assert_integers_equal ("nothing to agree with", 0, s.last_stable.count)
		end

	test_constants
		local
			s: PT_HEARD_STABILIZER
		do
			create s.make
			assert_true ("tail guard and tolerance", s.Tail_guard = 0.3 and s.Time_tolerance = 0.4)
		end

feature {NONE} -- Fixtures

	timed_window (a_start: INTEGER_64; a_words: ARRAY [TUPLE [text: STRING_8; t0: REAL_64]]): PT_HEARD_WORDS
			-- A 3 s window starting at sample `a_start'.
		local
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
		do
			create l_words.make (a_words.count)
			across a_words as ic loop
				l_words.extend (create {PT_HEARD_WORD}.make (ic.text.to_string_32, ic.text.to_string_32, ic.t0, (ic.t0 + 0.2).min (3.0), 0.9))
			end
			create Result.make (a_start, 48_000, l_words)
		end

end
