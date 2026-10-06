note
	description: "A closed time interval [t0, t1] in seconds on a recording timeline."
	author: "Larry Rix"

class
	PT_TIME_SPAN

create
	make

feature {NONE} -- Initialization

	make (a_t0, a_t1: REAL_64)
			-- Interval from `a_t0' to `a_t1'.
		require
			non_negative: a_t0 >= 0
			ordered: a_t0 <= a_t1
		do
			t0 := a_t0
			t1 := a_t1
		ensure
			set: t0 = a_t0 and t1 = a_t1
		end

feature -- Access

	t0, t1: REAL_64

	duration: REAL_64
		do
			Result := t1 - t0
		ensure
			non_negative: Result >= 0
		end

	midpoint: REAL_64
		do
			Result := (t0 + t1) / 2
		ensure
			inside: contains (Result)
		end

feature -- Status

	contains (a_t: REAL_64): BOOLEAN
		do
			Result := t0 <= a_t and a_t <= t1
		ensure
			definition: Result = (t0 <= a_t and a_t <= t1)
		end

	overlaps (a_other: PT_TIME_SPAN): BOOLEAN
			-- Do the intervals share more than an end point?
		do
			Result := t0 < a_other.t1 and a_other.t0 < t1
		end

invariant
	non_negative: t0 >= 0
	ordered: t0 <= t1

end
