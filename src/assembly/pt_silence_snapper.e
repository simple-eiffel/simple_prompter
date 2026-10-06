note
	description: "[
		Moves each cut's edges into the silence around it (midpoint of the gap
		before the first word and after the last), or pads by head/tail margins
		and marks the cut tight when there is no gap. Never clips a heard word.
	]"
	author: "Larry Rix"

class
	PT_SILENCE_SNAPPER

create
	make

feature {NONE} -- Initialization

	make (a_head_pad, a_tail_pad: REAL_64)
			-- Margins used when no silence is available.
		require
			pads_non_negative: a_head_pad >= 0 and a_tail_pad >= 0
		do
			head_pad := a_head_pad
			tail_pad := a_tail_pad
			create last_result.make
		ensure
			pads_set: head_pad = a_head_pad and tail_pad = a_tail_pad
		end

feature -- Access

	head_pad, tail_pad: REAL_64
	last_result: PT_CUT_LIST

feature -- Basic operations

	snap (a_cuts: PT_CUT_LIST; a_map: PT_SPEECH_MAP; a_timeline: PT_WORD_TIMELINE)
			-- Snapped copy of `a_cuts' in `last_result'.
		require
			spans_in_map: across 1 |..| a_cuts.count as i all a_cuts.cut (i).span.t1 <= a_map.duration end
		local
			l_i: INTEGER
			l_cut: PT_CUT
			l_start, l_end, l_t0, l_t1, l_probe: REAL_64
			l_tight: BOOLEAN
		do
			create last_result.make
			from l_i := 1 until l_i > a_cuts.count loop
				l_cut := a_cuts.cut (l_i)
				l_start := l_cut.span.t0
				l_end := l_cut.span.t1
				across l_cut.word_ids as ic loop
					if attached a_timeline.occurrence_in (ic, l_cut.attempt) as al_occ then
						l_start := l_start.min (al_occ.span.t0)
						l_end := l_end.max (al_occ.span.t1)
					end
				end
				l_start := l_start.max (0).min (a_map.duration)
				l_end := l_end.max (l_start).min (a_map.duration)
				l_tight := False
					-- Start edge: middle of the silence before the first word (at most Max_lead earlier).
				l_probe := (l_start - Probe).max (0)
				if a_map.is_silent_at (l_probe) and then attached a_map.silence_around (l_probe) as al_gap then
					l_t0 := al_gap.midpoint.max (l_start - Max_lead).min (l_start)
					if not a_map.is_silent_at (l_t0) then
						l_t0 := l_probe
					end
				else
					l_t0 := (l_start - head_pad).max (0)
					l_tight := True
				end
					-- End edge: middle of the silence after the last word (at most Max_tail later).
				l_probe := (l_end + Probe).min (a_map.duration)
				if a_map.is_silent_at (l_probe) and then attached a_map.silence_around (l_probe) as al_gap2 then
					l_t1 := al_gap2.midpoint.min (l_end + Max_tail).max (l_end)
					if not a_map.is_silent_at (l_t1) then
						l_t1 := l_probe
					end
				else
					l_t1 := (l_end + tail_pad).min (a_map.duration)
					l_tight := True
				end
				last_result.extend (l_cut.with_span (create {PT_TIME_SPAN}.make (l_t0, l_t1.max (l_t0)), l_tight))
				l_i := l_i + 1
			end
		ensure
			same_count: last_result.count = a_cuts.count
			same_words: (last_result.words_model |=| a_cuts.words_model)
			within_recording: across 1 |..| last_result.count as i all last_result.cut (i).span.t1 <= a_map.duration end
			in_silence_or_tight: across 1 |..| last_result.count as i all
					last_result.cut (i).is_tight or
					(a_map.is_silent_at (last_result.cut (i).span.t0) and a_map.is_silent_at (last_result.cut (i).span.t1)) end
			words_not_clipped: across 1 |..| last_result.count as i all
					words_inside (last_result.cut (i), a_timeline) end
		end

feature -- Constants

	Probe: REAL_64 = 0.02
			-- Distance from a word edge at which silence is looked for.
	Max_lead: REAL_64 = 0.6
	Max_tail: REAL_64 = 0.8
			-- Longest silence kept before the first word / after the last word.

feature -- Contract helpers

	words_inside (a_cut: PT_CUT; a_timeline: PT_WORD_TIMELINE): BOOLEAN
			-- Do all heard occurrences of `a_cut''s words in its attempt lie inside its span?
		do
			Result := across a_cut.word_ids as ic all
					attached a_timeline.occurrence_in (ic, a_cut.attempt) as al_occ implies
						(a_cut.span.t0 <= al_occ.span.t0 and al_occ.span.t1 <= a_cut.span.t1) end
		end

invariant
	pads_non_negative: head_pad >= 0 and tail_pad >= 0

end
