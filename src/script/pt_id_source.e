note
	description: "Monotone word-id generator; one per script history, so ids never repeat within a session."
	author: "Larry Rix"

class
	PT_ID_SOURCE

create
	make, make_after

feature {NONE} -- Initialization

	make
			-- Fresh source; the first issued id will be 1.
		do
			last_issued := 0
		ensure
			nothing_issued: last_issued = 0
		end

	make_after (a_last: INTEGER_64)
			-- Source resuming after `a_last' (session recovery).
		require
			non_negative: a_last >= 0
		do
			last_issued := a_last
		ensure
			resumed: last_issued = a_last
		end

feature -- Access

	last_issued: INTEGER_64
			-- Most recently issued id value (0 = none yet).

	last_id: PT_WORD_ID
			-- Most recently issued id.
		require
			issued: last_issued > 0
		do
			create Result.make (last_issued)
		ensure
			matches: Result.value = last_issued
		end

feature -- Element change

	issue
			-- Issue the next id; read it with `last_id'.
		do
			last_issued := last_issued + 1
		ensure
			incremented: last_issued = old last_issued + 1
		end

invariant
	non_negative: last_issued >= 0

end
