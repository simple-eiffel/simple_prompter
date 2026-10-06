note
	description: "[
		Plan Step 1 library additions for the pill: word geometry and hit
		testing (PT_PILL_GEOMETRY), the remembered pill position
		(PT_SETTINGS), and the bindings list the app registers (PT_KEYMAP).
	]"
	author: "Larry Rix"

class
	TEST_PILL

inherit
	PT_TEST_SET

feature -- Geometry

	test_word_positions_match_the_layout
			-- Fixed measure: 10 px per character, 30 px lines; padding 12, reading line 30.
			-- "This is Moody." -> This at 12 (40 wide), is at 12 + 40 + 10 = 62.
		local
			g: PT_PILL_GEOMETRY
		do
			g := geometry (0.0)
			assert_reals_equal ("first word inset", 12.0, g.word_x (1), 1.0e-9)
			assert_reals_equal ("first word width", 40.0, g.word_width (1), 1.0e-9)
			assert_reals_equal ("second word after one space", 62.0, g.word_x (2), 1.0e-9)
				-- 12 padding + 30 reading line; the reading point is centred half a line down,
				-- and until the reader is half a line in the first line sits in the reading row.
			assert_reals_equal ("line 1 in the reading row before reading", 42.0, g.line_top (1, 0.0), 1.0e-9)
			assert_reals_equal ("line 2 one line lower", 72.0, g.line_top (2, 0.0), 1.0e-9)
			assert_reals_equal ("scrolling moves lines up", 27.0, g.line_top (1, 30.0), 1.0e-9)
			assert_reals_equal ("halfway through line 1 it fills the reading row", 42.0, g.line_top (1, 15.0), 1.0e-9)
		end

	test_hit_testing
		local
			g: PT_PILL_GEOMETRY
		do
			g := geometry (0.0)
			assert_integers_equal ("on This", 1, g.word_at (15.0, 65.0, 0.0))
			assert_integers_equal ("on is", 2, g.word_at (65.0, 65.0, 0.0))
			assert_integers_equal ("in the gap between words", 0, g.word_at (55.0, 65.0, 0.0))
			assert_integers_equal ("above the first line", 0, g.word_at (15.0, 10.0, 0.0))
			assert_integers_equal ("same point after scrolling one line: line 2's first word",
				g.layout.line (2).first_word, g.word_at (15.0, 65.0, 30.0))
		end

	test_visible_lines
		local
			g: PT_PILL_GEOMETRY
		do
			g := geometry (0.0)
			assert_integers_equal ("first visible", 1, g.first_visible_line (0.0))
			assert_integers_equal ("three lines start above 132 px", 3, g.last_visible_line (0.0, 132.0))
			assert_integers_equal ("scrolled past line 1: it has left the top", 2, g.first_visible_line (90.0))
		end

feature -- Hold

	test_hold_offers_the_passage_start
			-- F-01: holding offers a restart point - the start of the passage being read -
			-- so Go restarts that sentence instead of jumping back to where reading began.
		local
			c: PT_TAKE_CONTROLLER
			l_expected: INTEGER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Play)
			c.perform ({PT_ACTION}.Count_in_done)
			c.follower.advance (12.0)
			l_expected := moody.passage (moody.passage_of (c.reader_position)).first_word
			assert_true ("well past the first passage", c.reader_position > moody.passage (2).first_word)
			c.perform ({PT_ACTION}.Hold)
			assert_integers_equal ("caret offered at the start of the passage being read", l_expected, c.caret)
		end

	test_hold_never_offers_a_cue
			-- Just past a cue line, the restart point is the next sentence, not the cue
			-- (a cue is never read aloud) and not the sentence before it.
		local
			c: PT_TAKE_CONTROLLER
			r: PT_SCRIPT_REVISION
			p: PT_SCRIPT_PARSER
			l_four: INTEGER
		do
			create p.make
			p.parse ({STRING_32} "t", {STRING_32} "One two three.%N%N[CUE: take a breath here]%N%NFour five six seven.", 1, create {PT_ID_SOURCE}.make)
			r := p.last_revision
			c := controller_for (r)
			c.perform ({PT_ACTION}.Play)
			c.perform ({PT_ACTION}.Count_in_done)
				-- Put the reader inside the cue line (a constant follower reads through cues).
			c.follower.set_caret (4)
			c.perform ({PT_ACTION}.Hold)
			from l_four := 1 until r.word (l_four).normalized.same_string ({STRING_32} "four") loop
				l_four := l_four + 1
			end
			assert_integers_equal ("restart at Four", l_four, c.caret)
		end

feature -- Settings and keys

	test_pill_position_survives_a_restart
		local
			s: PT_SETTINGS
			l_path: STRING_32
			l_ok: BOOLEAN
		do
			l_path := {STRING_32} "testing/out/pill_settings.toml"
			if (create {SIMPLE_FILE}.make (l_path)).exists then
				l_ok := (create {SIMPLE_FILE}.make (l_path)).delete
			end
			ensure_out_dir
			create s.make_with_file (l_path)
			assert_false ("not placed yet", s.has_pill_position)
			s.set_pill_position (-1200, 24)
			s.set_last_script ({STRING_32} "C:\Scripts\Episode 12 - caf%/233/.md")
			create s.make_with_file (l_path)
			assert_true ("placed after reload", s.has_pill_position)
			assert_true ("last script after reload (non-ASCII kept)", s.last_script.same_string ({STRING_32} "C:\Scripts\Episode 12 - caf%/233/.md"))
			assert_integers_equal ("x", -1200, s.pill_x)
			assert_integers_equal ("y", 24, s.pill_y)
		end

	test_all_bindings_lists_every_binding
		local
			k: PT_KEYMAP
		do
			create k.make_default
			assert_integers_equal ("every default binding", k.binding_count, k.all_bindings.count)
			assert_true ("each has a modifier", across k.all_bindings as ic all not ic.is_bare end)
		end

feature {NONE} -- Fixtures

	geometry (a_unused: REAL_64): PT_PILL_GEOMETRY
			-- Moody laid out 300 px wide with a 10 px / 30 px fixed measure.
		local
			l_layout: PT_LAYOUT
			l_measure: PT_FIXED_MEASURE
		do
			create l_measure.make (10.0, 30.0)
			create l_layout.make
			l_layout.build (moody, l_measure, 300.0)
			create Result.make (moody, l_layout, l_measure, 12.0, 30.0)
		end

	ensure_out_dir
		local
			l_dir: DIRECTORY
		do
			create l_dir.make ("testing/out")
			if not l_dir.exists then
				l_dir.create_dir
			end
		end

end
