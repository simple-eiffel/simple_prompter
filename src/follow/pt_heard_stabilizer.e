note
	description: "[
		Local agreement for streaming recognition. Live whisper invents words where a
		window cuts a phrase off ("going to be in the middle of the year", "8, 8, 8 ...",
		all stamped at the window's last instant), and those inventions differ from one
		decode to the next. A heard word is trusted only when the previous decode heard
		the same word starting at about the same time, and never while it starts inside
		the window's last `Tail_guard' seconds. Real words survive with one step (250 ms)
		of extra delay; inventions do not (live replay of larry_read_01, 2026-10-06:
		without this the aligner stalled up to 16 s, its time-ordered buffer pushed ahead
		by invented words so that the real ones were dropped as duplicates).
	]"
	author: "Larry Rix"

class
	PT_HEARD_STABILIZER

create
	make

feature {NONE} -- Initialization

	make
		do
			create previous_words.make (0)
			create previous_starts.make (0)
			create last_stable.make (0, 1, create {ARRAYED_LIST [PT_HEARD_WORD]}.make (0))
		ensure
			nothing_remembered: remembered_count = 0
			nothing_stable: last_stable.count = 0
		end

feature -- Constants

	Tail_guard: REAL_64 = 0.3
			-- Words starting this close to the window's end are not trusted yet.

	Time_tolerance: REAL_64 = 0.4
			-- Two decodes agree on a word when its starts differ by at most this (seconds).

	Sample_rate: INTEGER = 16_000

feature -- Access

	last_stable: PT_HEARD_WORDS
			-- The words of the last `accept' that the decode before it agreed with.

	remembered_count: INTEGER
			-- Words of the last decode kept for the next comparison.
		do
			Result := previous_words.count
		end

feature -- Element change

	accept (a_heard: PT_HEARD_WORDS)
			-- Compare `a_heard' with the previous decode; keep the agreed words in `last_stable'.
		local
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_current_words: ARRAYED_LIST [STRING_32]
			l_current_starts: ARRAYED_LIST [REAL_64]
			l_origin, l_limit, l_abs: REAL_64
			i: INTEGER
		do
			l_origin := a_heard.window_start / Sample_rate
			l_limit := a_heard.window_samples / Sample_rate - Tail_guard
			create l_words.make (a_heard.count)
			create l_current_words.make (a_heard.count)
			create l_current_starts.make (a_heard.count)
			from i := 1 until i > a_heard.count loop
				if a_heard.word (i).t0 <= l_limit and not a_heard.word (i).normalized.is_empty then
					l_abs := l_origin + a_heard.word (i).t0
					l_current_words.extend (a_heard.word (i).normalized)
					l_current_starts.extend (l_abs)
					if agreed (a_heard.word (i).normalized, l_abs) then
						l_words.extend (a_heard.word (i))
					end
				end
				i := i + 1
			end
			previous_words := l_current_words
			previous_starts := l_current_starts
			create last_stable.make (a_heard.window_start, a_heard.window_samples, l_words)
		ensure
			same_window: last_stable.window_start = a_heard.window_start and last_stable.window_samples = a_heard.window_samples
			subset: last_stable.count <= a_heard.count
			outside_tail: across 1 |..| last_stable.count as ic all
					last_stable.word (ic).t0 <= a_heard.window_samples / Sample_rate - Tail_guard end
			remembered: remembered_count <= a_heard.count
		end

	reset
			-- Forget the previous decode (a new stream, or after a long silence).
		do
			previous_words.wipe_out
			previous_starts.wipe_out
		ensure
			forgotten: remembered_count = 0
		end

feature {NONE} -- Implementation

	previous_words: ARRAYED_LIST [STRING_32]
			-- Normalized words of the previous decode (outside its tail guard).

	previous_starts: ARRAYED_LIST [REAL_64]
			-- Their absolute start times, seconds.

	agreed (a_normalized: STRING_32; a_start: REAL_64): BOOLEAN
			-- Did the previous decode hear `a_normalized' starting near `a_start'?
		local
			i: INTEGER
		do
			from i := 1 until Result or i > previous_words.count loop
				Result := previous_words [i].same_string (a_normalized) and (previous_starts [i] - a_start).abs <= Time_tolerance
				i := i + 1
			end
		end

invariant
	parallel: previous_words.count = previous_starts.count

end
