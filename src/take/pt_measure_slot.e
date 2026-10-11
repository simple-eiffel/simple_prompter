note
	description: "[
		Where a Measure run (PT_MEASURE_WORKER, on its own processor) and the window meet
		(0.6.0). Like PT_SPEECH_SLOT, every routine is a field read or an assignment, so
		the window never waits behind the measuring: it reads `progress' and, once
		`is_done', the result.
	]"
	author: "Larry Rix"

class
	PT_MEASURE_SLOT

create
	make

feature {NONE} -- Initialization

	make
		do
			create summary.make_empty
			first_clap := -1
		ensure
			running: not is_done and progress = 0
		end

feature -- Access

	is_done: BOOLEAN
			-- Has the measuring finished?

	progress: REAL_64
			-- How far it has got (0..1).

	is_found: BOOLEAN
			-- Was a sync measured?

	delay_ms: INTEGER
			-- The measured sync (when `is_found').

	first_clap: REAL_64
			-- Time of the first clap heard (-1: none).

	summary: STRING_32
			-- What it found, for the panel.

feature -- Element change

	put_progress (a_fraction: REAL_64)
		do
			progress := a_fraction.max (0).min (1)
		ensure
			in_range: progress >= 0 and progress <= 1
		end

	put_result (a_found: BOOLEAN; a_delay_ms: INTEGER; a_first_clap: REAL_64; a_summary: separate READABLE_STRING_32)
		do
			is_found := a_found
			delay_ms := a_delay_ms
			first_clap := a_first_clap
			create summary.make_from_separate (a_summary)
			progress := 1
			is_done := True
		ensure
			done: is_done and progress = 1
		end

invariant
	progress_range: progress >= 0 and progress <= 1

end
