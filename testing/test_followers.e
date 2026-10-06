note
	description: "Follow cluster: followers, spring, layout, scroll model, matcher, aligner."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_FOLLOWERS

inherit
	PT_TEST_SET

feature -- Tests: constant follower

	test_constant_one_word_per_second_at_60_wpm
		local
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (100, 60)
			f.release
			f.advance (1.0)
			assert_reals_equal ("one word", 1.0, f.target, 1.0e-9)
			assert_reals_equal ("velocity", 1.0, f.velocity, 1.0e-9)
		end

	test_held_follower_does_not_move
		local
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (100, 120)
			f.advance (5.0)
			assert_reals_equal ("still at start", 0.0, f.target, 1.0e-9)
			assert_reals_equal ("no velocity", 0.0, f.velocity, 1.0e-9)
		end

	test_constant_clamps_at_end
		local
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (3, 120)
			f.release
			f.advance (10.0)
			assert_reals_equal ("clamped", 3.0, f.target, 1.0e-9)
		end

	test_caret_is_the_only_backward_move
		local
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (100, 120)
			f.release
			f.advance (5.0)
			f.set_caret (2)
			assert_reals_equal ("moved back", 2.0, f.target, 1.0e-9)
			assert_true ("flagged", f.caret_changed)
		end

	test_rescale_clamps_target
		local
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (100, 120)
			f.set_caret (90)
			f.rescale (50)
			assert_reals_equal ("clamped to new length", 50.0, f.target, 1.0e-9)
		end

feature -- Tests: voice-gated and tracking (Phase 4 behavior)

	test_voice_gated_moves_only_while_speaking
		local
			f: PT_VOICE_GATED_FOLLOWER
			i: INTEGER
		do
			create f.make (100, 120)
			f.release
			f.on_voice (frame (0, True))
			from i := 1 until i > 30 loop
				f.advance (0.033)
				i := i + 1
			end
			assert_real_greater_than ("moved while speaking", f.target, 1.0)
		end

	test_voice_gated_stops_within_250_ms
		local
			f: PT_VOICE_GATED_FOLLOWER
			i: INTEGER
		do
			create f.make (100, 120)
			f.release
			f.on_voice (frame (0, True))
			from i := 1 until i > 30 loop
				f.advance (0.033)
				i := i + 1
			end
			assert_real_greater_than ("moving before the pause (review L19)", f.velocity, 0.0)
			f.on_voice (frame (16_000, False))
			from i := 1 until i > 8 loop
				f.advance (0.033)
				i := i + 1
			end
			assert_reals_equal ("stopped after <= 264 ms", 0.0, f.velocity, 1.0e-9)
		end

	test_tracking_holds_after_coast_limit
		local
			f: PT_TRACKING_FOLLOWER
		do
			create f.make (100, 120)
			f.release
			f.on_voice (frame (0, True))
			f.on_alignment (create {PT_ALIGNMENT}.make (10, 0.9, 4, 3, 2.0, 16_000))
			f.advance (2.0)
			assert_true ("has alignment", f.has_alignment)
			assert_reals_equal ("held still after coasting", 0.0, f.velocity, 1.0e-9)
		end

feature -- Tests: spring, layout, scroll

	test_spring_moves_toward_target
		local
			s: PT_SPRING
		do
			create s.make (12.0)
			s.step (10.0, 0.1)
			assert_real_greater_than ("moved", s.value, 0.0)
			assert_real_less_than ("no overshoot", s.value, 10.0 + 1.0e-9)
		end

	test_fixed_measure
		local
			m: PT_FIXED_MEASURE
		do
			create m.make (10.0, 20.0)
			assert_reals_equal ("five chars", 50.0, m.advance ({STRING_32} "Moody"), 1.0e-9)
		end

	test_layout_wraps_every_word
		local
			l: PT_LAYOUT
			r: PT_SCRIPT_REVISION
		do
			r := moody
			create l.make
			l.build (r, create {PT_FIXED_MEASURE}.make (10.0, 20.0), 300.0)
			assert_greater_than ("several lines", l.line_count, 3)
			assert_integers_equal ("last word on last line", r.word_count, l.line (l.line_count).last_word)
		end

	test_scroll_tick_keeps_time
		local
			s: PT_SCROLL_MODEL
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (10, 60)
			create s.make (f, create {PT_LAYOUT}.make, create {PT_SPRING}.make (12.0))
			s.tick (100.0)
			s.tick (116.7)
			assert_reals_equal ("time kept", 116.7, s.last_ms, 1.0e-9)
			assert_true ("started", s.is_started)
		end

	test_restart_snaps_scroll_back
			-- Review H2: after a caret moves back, the display jumps there (no visible rewind).
		local
			s: PT_SCROLL_MODEL
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (100, 120)
			create s.make (f, create {PT_LAYOUT}.make, create {PT_SPRING}.make (12.0))
			s.tick (0.0)
			f.set_caret (40)
			s.jump_to (40.0)
			f.set_caret (12)
			s.tick (16.0)
			assert_reals_equal ("snapped to the caret", 12.0, s.position, 1.0e-9)
		end

feature -- Tests: matcher

	test_allowed_distance_tiers
		local
			m: PT_WORD_MATCHER
		do
			create m
			assert_integers_equal ("short strict", 0, m.allowed_distance (4))
			assert_integers_equal ("medium", 1, m.allowed_distance (6))
			assert_integers_equal ("long", 2, m.allowed_distance (12))
		end

	test_matcher_exact_and_tolerant
		local
			m: PT_WORD_MATCHER
			r: PT_SCRIPT_REVISION
		do
			create m
			r := moody
			assert_true ("exact", m.matches ({STRING_32} "teleprompter", r.word (8)))
			assert_true ("one edit on a long word", m.matches ({STRING_32} "teleprompters", r.word (8)))
			assert_false ("unrelated", m.matches ({STRING_32} "camera", r.word (8)))
		end

	test_equivalent_word_matches
			-- Review H7: a homophone counts as the script word.
		local
			m: PT_WORD_MATCHER
			r: PT_SCRIPT_REVISION
		do
			create m
			r := revision_of (<<{STRING_32} "Their idea.">>)
			assert_true ("there for their", m.matches ({STRING_32} "there", r.word (1)))
		end

feature -- Tests: aligner

	test_reanchor_places_position
		local
			a: PT_ALIGNER
		do
			create a.make (moody, create {PT_WORD_MATCHER})
			a.reanchor (12, 0)
			assert_integers_equal ("placed", 12, a.position)
			assert_reals_equal ("certain", 1.0, a.confidence, 1.0e-9)
		end

	test_stop_words_alone_never_move
		local
			a: PT_ALIGNER
		do
			create a.make (moody, create {PT_WORD_MATCHER})
			a.update (heard (0, <<{STRING_32} "is", {STRING_32} "a", {STRING_32} "the">>))
			assert_integers_equal ("unmoved", 0, a.position)
		end

	test_stale_window_is_ignored
			-- Review H3: a window decoded before a restart must not move the aligner.
		local
			a: PT_ALIGNER
		do
			create a.make (moody, create {PT_WORD_MATCHER})
			a.reanchor (10, 32_000)
			a.update (heard (16_000, <<{STRING_32} "notch", {STRING_32} "teleprompter", {STRING_32} "for", {STRING_32} "Mac">>))
			assert_integers_equal ("unmoved by the stale window", 10, a.position)
		end

	test_aligner_follows_reading
		local
			a: PT_ALIGNER
		do
			create a.make (moody, create {PT_WORD_MATCHER})
			a.update (heard (0, <<{STRING_32} "This", {STRING_32} "is", {STRING_32} "Moody", {STRING_32} "Moody", {STRING_32} "is", {STRING_32} "a", {STRING_32} "notch">>))
			assert_integers_equal ("on 'notch'", 7, a.position)
		end

	test_repeated_phrase_picks_the_forward_occurrence
			-- "So when you" opens sentences 5 and 6 of the reel script.
		local
			a: PT_ALIGNER
			r: PT_SCRIPT_REVISION
		do
			r := moody
			create a.make (r, create {PT_WORD_MATCHER})
			a.reanchor (r.passage (6).first_word - 1, 0)
			a.update (heard (0, <<{STRING_32} "So", {STRING_32} "when", {STRING_32} "you", {STRING_32} "stop", {STRING_32} "speaking">>))
			assert_integers_equal ("in sentence 6", 6, r.passage_of (a.position.max (1)))
		end

end
