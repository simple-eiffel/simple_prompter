note
	description: "[
		SCOOP consumer compatibility (Phase 1 gate): library types used through
		separate references, as the speech worker processor will use them.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_SCOOP_CONSUMER

inherit
	PT_TEST_SET

feature -- Tests

	test_separate_recording_clock
		local
			l_clock: separate PT_RECORDING_CLOCK
		do
			create l_clock.make
			observe (l_clock)
			assert_reals_equal ("one second across processors", 1.0, rt_of (l_clock), 1.0e-9)
		end

feature {NONE} -- Separate calls

	observe (a_clock: separate PT_RECORDING_CLOCK)
		do
			a_clock.observe_bytes (64_000, 1000.0)
		end

	rt_of (a_clock: separate PT_RECORDING_CLOCK): REAL_64
		do
			Result := a_clock.rt
		end

end
