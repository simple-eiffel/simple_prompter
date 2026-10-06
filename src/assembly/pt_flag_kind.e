note
	description: "Review flag kinds raised by analysis (reached as {PT_FLAG_KIND}.Misread etc.)."
	author: "Larry Rix"

class
	PT_FLAG_KIND

feature -- Constants

	Misread: INTEGER = 1
			-- Heard word differs from the script word.
	Low_confidence: INTEGER = 2
	Unmarked_restart: INTEGER = 3
			-- Same words read twice in one attempt without pressing Again.
	Tight_splice: INTEGER = 4
			-- A cut edge could not be placed in silence.
	Missing: INTEGER = 5
			-- A passage has no valid take.
	Long_pause: INTEGER = 6
			-- A long silence kept inside a take.

end
