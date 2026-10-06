note
	description: "[
		Monotone millisecond clock. The app supplies a QPC-backed clock
		(SHELL_DESKTOP.now_ms); tests and replays use PT_FAKE_CLOCK.
		Monotonicity across calls is a tested property of each descendant.
	]"
	author: "Larry Rix"

deferred class
	PT_CLOCK

feature -- Access

	now_ms: REAL_64
			-- Current time in milliseconds.
		deferred
		ensure
			non_negative: Result >= 0
		end

end
