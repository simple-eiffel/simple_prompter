note
	description: "Facade tests for SIMPLE_PROMPTER: what a client of the library sees first."
	author: "Larry Rix"
	testing: "covers"

class
	LIB_TESTS

inherit
	PT_TEST_SET

feature -- Tests

	test_load_wires_everything
		local
			p: SIMPLE_PROMPTER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			assert_false ("nothing loaded", p.has_script)
			p.load_script_text ({STRING_32} "t", {STRING_32} "This is Moody.")
			assert_true ("loaded", p.has_script)
			assert_integers_equal ("one revision", 1, p.history.revision_count)
			assert_integers_equal ("idle", {PT_TAKE_STATE}.Idle, p.controller.state)
		end

	test_fluent_configuration
		local
			p: SIMPLE_PROMPTER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.with_mode ({PT_FOLLOW_MODE}.Constant).with_speed_wpm (60).with_clock (create {PT_FAKE_CLOCK}.make).do_nothing
			assert_integers_equal ("mode", {PT_FOLLOW_MODE}.Constant, p.mode)
			assert_integers_equal ("speed", 60, p.speed_wpm)
		end

	test_constant_practice_read_moves
		local
			p: SIMPLE_PROMPTER
			c: PT_FAKE_CLOCK
		do
			create c.make
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.with_mode ({PT_FOLLOW_MODE}.Constant).with_speed_wpm (60).with_clock (c).do_nothing
			p.load_script_text ({STRING_32} "t", {STRING_32} "One two three. Four five six.")
			p.perform ({PT_ACTION}.Play)
			p.perform ({PT_ACTION}.Count_in_done)
			p.tick (c.now_ms)
			c.advance (1000)
			p.tick (c.now_ms)
			assert_reals_equal ("one word per second", 1.0, p.follower.target, 1.0e-6)
		end

	test_prompt_is_already_read_text_only
		local
			p: SIMPLE_PROMPTER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.load_script_text ({STRING_32} "t", {STRING_32} "This is Moody.")
			assert_true ("never upcoming text (spike gotcha 2)",
				p.history.current_revision.text_of_range (1, p.controller.reader_position).ends_with (p.prompt_text))
		end

end
