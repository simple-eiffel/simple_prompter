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
			l_start, l_end, l_t0, l_t1, l_lo, l_hi, l_mid: REAL_64
			l_t0s, l_t1s, l_starts, l_ends: ARRAY [REAL_64]
		do
			create l_t0s.make_filled (0.0, 1, a_cuts.count)
			create l_t1s.make_filled (0.0, 1, a_cuts.count)
			create l_starts.make_filled (0.0, 1, a_cuts.count)
			create l_ends.make_filled (0.0, 1, a_cuts.count)
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
					-- Start edge: middle of the nearest silence before the first word, at most Max_lead
					-- earlier. VAD speech often starts a little before whisper's first word time
					-- (breath, onset), so the search steps over speech that begins within reach.
				l_t0 := -1.0
				if attached silence_before (a_map, l_start) as al_gap then
					l_t0 := al_gap.midpoint.max (l_start - Max_lead).min (al_gap.t1.min (l_start))
					if not a_map.is_silent_at (l_t0) then
						l_lo := al_gap.t0.max (l_start - Max_lead).max (0)
						l_hi := al_gap.t1.min (l_start)
						l_t0 := -1.0
						if l_lo <= l_hi and then a_map.is_silent_at ((l_lo + l_hi) / 2) then
							l_t0 := (l_lo + l_hi) / 2
						end
					end
				end
				if l_t0 < 0 then
					l_t0 := (l_start - head_pad).max (0)
				end
					-- End edge: middle of the nearest silence after the last word, at most Max_tail later
					-- (VAD speech often runs past whisper's last word end; Phase 5, review of T16).
				l_t1 := -1.0
				if attached silence_after (a_map, l_end) as al_gap2 then
					l_t1 := al_gap2.midpoint.min (l_end + Max_tail).max (al_gap2.t0.max (l_end))
					if not a_map.is_silent_at (l_t1) then
						l_lo := al_gap2.t0.max (l_end)
						l_hi := al_gap2.t1.min (l_end + Max_tail).min (a_map.duration)
						l_t1 := -1.0
						if l_lo <= l_hi and then a_map.is_silent_at ((l_lo + l_hi) / 2) then
							l_t1 := (l_lo + l_hi) / 2
						end
					end
				end
				if l_t1 < 0 then
					l_t1 := (l_end + tail_pad).min (a_map.duration)
				end
				l_t0s [l_i] := l_t0
				l_t1s [l_i] := l_t1.max (l_t0)
				l_starts [l_i] := l_start
				l_ends [l_i] := l_end
				l_i := l_i + 1
			end
				-- Neighbouring cuts of one source must not overlap: the overlap would play twice
				-- (real voice: two cuts of one take crossed by ~1 s). They meet between the last word
				-- of one and the first word of the next, in the silence there when there is one.
			from l_i := 2 until l_i > a_cuts.count loop
				if a_cuts.cut (l_i).src = a_cuts.cut (l_i - 1).src and then l_t0s [l_i] < l_t1s [l_i - 1]
					and then l_ends [l_i - 1] <= l_starts [l_i] then
					l_mid := (l_ends [l_i - 1] + l_starts [l_i]) / 2
					if not a_map.is_silent_at (l_mid) and then attached silence_after (a_map, l_ends [l_i - 1]) as al_gap
						and then al_gap.midpoint >= l_ends [l_i - 1] and then al_gap.midpoint <= l_starts [l_i] then
						l_mid := al_gap.midpoint
					end
					l_t1s [l_i - 1] := l_mid.max (l_t0s [l_i - 1])
					l_t0s [l_i] := l_mid.min (l_t1s [l_i])
				end
				l_i := l_i + 1
			end
				-- A cut is tight when either edge is not in silence.
			create last_result.make
			from l_i := 1 until l_i > a_cuts.count loop
				last_result.extend (a_cuts.cut (l_i).with_span (create {PT_TIME_SPAN}.make (l_t0s [l_i], l_t1s [l_i]),
					not (a_map.is_silent_at (l_t0s [l_i]) and a_map.is_silent_at (l_t1s [l_i]))))
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

feature -- Silence search

	silence_before (a_map: PT_SPEECH_MAP; a_t: REAL_64): detachable PT_TIME_SPAN
			-- Nearest silent interval before `a_t' that reaches within `Max_lead' of it, stepping back
			-- over speech spans that begin within reach.
		require
			in_range: a_t >= 0 and a_t <= a_map.duration
		local
			l_p: REAL_64
			l_j: INTEGER
			l_moved: BOOLEAN
		do
			l_p := (a_t - Probe).max (0)
			from l_moved := True until not l_moved or a_map.is_silent_at (l_p) loop
				l_moved := False
				from l_j := 1 until l_j > a_map.span_count loop
					if a_map.span (l_j).contains (l_p) and then a_map.span (l_j).t0 - Probe >= (a_t - Max_lead).max (0) then
						l_p := a_map.span (l_j).t0 - Probe
						l_moved := True
						l_j := a_map.span_count
					end
					l_j := l_j + 1
				end
			end
			if a_map.is_silent_at (l_p) then
				Result := a_map.silence_around (l_p)
			end
		ensure
			within_reach: attached Result as al_r implies (al_r.t1 >= a_t - Max_lead and al_r.t0 <= a_t)
		end

	silence_after (a_map: PT_SPEECH_MAP; a_t: REAL_64): detachable PT_TIME_SPAN
			-- Nearest silent interval after `a_t' that begins within `Max_tail' of it, stepping forward
			-- over speech spans that end within reach.
		require
			in_range: a_t >= 0 and a_t <= a_map.duration
		local
			l_p: REAL_64
			l_j: INTEGER
			l_moved: BOOLEAN
		do
			l_p := (a_t + Probe).min (a_map.duration)
			from l_moved := True until not l_moved or a_map.is_silent_at (l_p) loop
				l_moved := False
				from l_j := 1 until l_j > a_map.span_count loop
					if a_map.span (l_j).contains (l_p) and then a_map.span (l_j).t1 + Probe <= (a_t + Max_tail).min (a_map.duration) then
						l_p := a_map.span (l_j).t1 + Probe
						l_moved := True
						l_j := a_map.span_count
					end
					l_j := l_j + 1
				end
			end
			if a_map.is_silent_at (l_p) then
				Result := a_map.silence_around (l_p)
			end
		ensure
			within_reach: attached Result as al_r implies (al_r.t0 <= a_t + Max_tail and al_r.t1 >= a_t)
		end

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
