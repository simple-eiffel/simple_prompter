note
	description: "Settable clock for tests and journal replay (the simple_speed_reader scripted-clock pattern)."
	author: "Larry Rix"

class
	PT_FAKE_CLOCK

inherit
	PT_CLOCK

create
	make

feature {NONE} -- Initialization

	make
			-- Clock at time 0.
		do
			now_ms := 0
		ensure
			at_zero: now_ms = 0
		end

feature -- Access

	now_ms: REAL_64
			-- Current time in milliseconds.

feature -- Element change

	advance (a_ms: REAL_64)
			-- Move time forward by `a_ms'.
		require
			non_negative: a_ms >= 0
		do
			now_ms := now_ms + a_ms
		ensure
			advanced: now_ms = old now_ms + a_ms
		end

	set (a_ms: REAL_64)
			-- Jump to `a_ms' (never backward).
		require
			not_backward: a_ms >= now_ms
		do
			now_ms := a_ms
		ensure
			set: now_ms = a_ms
		end

invariant
	non_negative: now_ms >= 0

end
