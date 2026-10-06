note
	description: "Take cluster: transitions table, controller, journal, codec, recording clock, restart policy."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_TAKE

inherit
	PT_TEST_SET

feature -- Tests: transitions (single choice)

	test_table_lists_34_pairs
		local
			t: PT_TRANSITIONS
			s, a, n: INTEGER
		do
			create t.make
			from s := 1 until s > t.State_count loop
				from a := 1 until a > t.Action_count loop
					if t.table_entry (s, a) /= 0 then
						n := n + 1
					end
					a := a + 1
				end
				s := s + 1
			end
			assert_integers_equal ("pairs in spec 07 section 2.6 (2+6+8+15+2+1)", 34, n)
		end

	test_recording_only_and_practice_only
		local
			t: PT_TRANSITIONS
		do
			create t.make
			assert_false ("no Star in practice", t.is_allowed ({PT_TAKE_STATE}.Reading, {PT_ACTION}.Star, False))
			assert_true ("Star while recording", t.is_allowed ({PT_TAKE_STATE}.Reading, {PT_ACTION}.Star, True))
			assert_false ("no Stop while recording", t.is_allowed ({PT_TAKE_STATE}.Reading, {PT_ACTION}.Stop, True))
			assert_true ("Stop in practice", t.is_allowed ({PT_TAKE_STATE}.Reading, {PT_ACTION}.Stop, False))
		end

	test_editing_allows_only_commit_or_cancel
		local
			t: PT_TRANSITIONS
			a, n: INTEGER
		do
			create t.make
			from a := 1 until a > t.Action_count loop
				if t.table_entry ({PT_TAKE_STATE}.Editing, a) /= 0 then
					n := n + 1
				end
				a := a + 1
			end
			assert_integers_equal ("two exits", 2, n)
		end

feature -- Tests: controller

	test_record_then_count_in_done_reads
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			assert_integers_equal ("count-in", {PT_TAKE_STATE}.Count_in, c.state)
			assert_true ("recording", c.is_recording)
			c.perform ({PT_ACTION}.Count_in_done)
			assert_integers_equal ("reading", {PT_TAKE_STATE}.Reading, c.state)
			assert_false ("follower released", c.follower.is_held)
		end

	test_again_counts_in_from_sentence_start
		local
			c: PT_TAKE_CONTROLLER
			r: PT_SCRIPT_REVISION
		do
			r := moody
			c := controller_for (r)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Count_in_done)
			c.follower.set_caret (r.passage (4).first_word + 5)
			c.perform ({PT_ACTION}.Again)
			assert_integers_equal ("count-in again", {PT_TAKE_STATE}.Count_in, c.state)
			assert_integers_equal ("caret at sentence 4 start", r.passage (4).first_word, c.caret)
		end

	test_resume_puts_reader_on_the_caret
			-- Review H1: after Go from caret word 20, the reader is on word 20 (not 21).
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Hold)
			c.pick_word (20)
			c.perform ({PT_ACTION}.Go)
			c.perform ({PT_ACTION}.Count_in_done)
			assert_integers_equal ("reader on the caret word", 20, c.reader_position)
		end

	test_empty_script_cannot_start
			-- Review M8.
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (revision_of (<<>>))
			assert_false ("no Play", c.is_allowed ({PT_ACTION}.Play))
			assert_false ("no Record", c.is_allowed ({PT_ACTION}.Record))
		end

	test_pick_word_moves_caret_without_journal
		local
			c: PT_TAKE_CONTROLLER
			l_count: INTEGER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Hold)
			l_count := c.journal.count
			c.pick_word (20)
			assert_integers_equal ("caret", 20, c.caret)
			assert_integers_equal ("not journaled", l_count, c.journal.count)
		end

	test_practice_writes_no_journal
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Play)
			c.perform ({PT_ACTION}.Count_in_done)
			c.perform ({PT_ACTION}.Hold)
			c.perform ({PT_ACTION}.Stop)
			assert_integers_equal ("idle", {PT_TAKE_STATE}.Idle, c.state)
			assert_integers_equal ("no events", 0, c.journal.count)
		end

	test_disallowed_action_is_refused
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			assert_refused ("Go from idle refused", agent c.perform ({PT_ACTION}.Go))
		end

	test_commit_edit_makes_a_revision
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Hold)
			c.perform ({PT_ACTION}.Edit_open)
			c.commit_edit ({STRING_32} "This is simple prompter.")
			assert_integers_equal ("revision 2", 2, c.history.revision_count)
			assert_integers_equal ("back to held", {PT_TAKE_STATE}.Held, c.state)
		end

feature -- Tests: journal and codec

	test_journal_append_keeps_order
		local
			j: PT_JOURNAL
		do
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_hold (1.5, "hotkey"))
			j.append (create {PT_TAKE_EVENT}.make_flub (2.0, id (3), "clicker"))
			assert_integers_equal ("two", 2, j.count)
			assert_reals_equal ("last rt", 2.0, j.last_rt, 1.0e-9)
			assert_integers_equal ("one flub", 1, j.count_of ({PT_EVENT_KIND}.Flub))
		end

	test_journal_refuses_time_travel
		local
			j: PT_JOURNAL
		do
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_hold (5.0, "hotkey"))
			assert_refused ("earlier rt refused", agent j.append (create {PT_TAKE_EVENT}.make_hold (4.0, "hotkey")))
		end

	test_codec_round_trip
		local
			k: PT_JOURNAL_CODEC
			l_line: STRING_8
		do
			create k.make
			l_line := k.encode (create {PT_TAKE_EVENT}.make_flub (102.31, id (141), "clicker"))
			assert_true ("one line", not l_line.has ('%N'))
			k.decode (l_line)
			assert_true ("decoded", k.has_event)
			if attached k.last_event as al_e then
				assert_integers_equal ("kind", {PT_EVENT_KIND}.Flub, al_e.kind)
				assert_reals_equal ("rt", 102.31, al_e.rt, 0.0005)
			end
		end

feature -- Tests: recording clock and restart policy

	test_64000_bytes_is_one_second
		local
			k: PT_RECORDING_CLOCK
		do
			create k.make
			k.observe_bytes (64_000, 1000.0)
			assert_reals_equal ("1 s", 1.0, k.rt, 1.0e-9)
			assert_reals_equal ("interpolated", 1.1, k.rt_at (1100.0), 1.0e-9)
			assert_reals_equal ("interpolation bounded", 1.25, k.rt_at (9000.0), 1.0e-9)
		end

	test_clock_refuses_shrinking_file
		local
			k: PT_RECORDING_CLOCK
		do
			create k.make
			k.observe_bytes (64_000, 1000.0)
			assert_refused ("shrink refused", agent k.observe_bytes (100, 2000.0))
		end

	test_again_caret_rules
		local
			p: PT_RESTART_POLICY
			r: PT_SCRIPT_REVISION
		do
			create p
			r := moody
			assert_integers_equal ("mid-sentence: its start", r.passage (4).first_word,
				p.again_caret (r, r.passage (4).first_word + 5, True, 1))
			assert_integers_equal ("first word: previous sentence", r.passage (3).first_word,
				p.again_caret (r, r.passage (4).first_word, True, 1))
		end

end
