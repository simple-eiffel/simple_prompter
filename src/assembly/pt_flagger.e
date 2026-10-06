note
	description: "Raises review flags from the alignment, the cut list and the speech map."
	author: "Larry Rix"

class
	PT_FLAGGER

create
	make

feature {NONE} -- Initialization

	make (a_long_pause_s: REAL_64)
		require
			positive: a_long_pause_s > 0
		do
			long_pause_s := a_long_pause_s
			create last_flags.make (0)
		ensure
			set: long_pause_s = a_long_pause_s
		end

feature -- Access

	long_pause_s: REAL_64
	last_flags: ARRAYED_LIST [PT_FLAG]

	count_of (a_kind: INTEGER): INTEGER
		do
			across last_flags as ic loop
				if ic.kind = a_kind then
					Result := Result + 1
				end
			end
		end

feature -- Basic operations

	flag (a_cuts: PT_CUT_LIST; a_missing: LIST [PT_WORD_ID]; a_timeline: PT_WORD_TIMELINE; a_map: PT_SPEECH_MAP)
			-- Flags for a solved and snapped session.
		local
			i, j: INTEGER
			l_cut: PT_CUT
			l_occ, l_other: PT_WORD_OCCURRENCE
		do
			create last_flags.make (8)
			from i := 1 until i > a_cuts.count loop
				l_cut := a_cuts.cut (i)
				if l_cut.is_tight then
					last_flags.extend (create {PT_FLAG}.make ({PT_FLAG_KIND}.Tight_splice, l_cut.span,
						first_or_none (l_cut), last_or_none (l_cut), {STRING_32} "cut " + i.out + " could not be placed in silence"))
				end
				from j := 1 until j > a_map.span_count loop
					if j > 1 and then (a_map.span (j).t0 - a_map.span (j - 1).t1) >= long_pause_s
						and then l_cut.span.contains (a_map.span (j - 1).t1) and then l_cut.span.contains (a_map.span (j).t0) then
						last_flags.extend (create {PT_FLAG}.make ({PT_FLAG_KIND}.Long_pause,
							create {PT_TIME_SPAN}.make (a_map.span (j - 1).t1, a_map.span (j).t0),
							first_or_none (l_cut), last_or_none (l_cut), {STRING_32} "long pause kept in cut " + i.out))
					end
					j := j + 1
				end
				i := i + 1
			end
			if not a_missing.is_empty then
				last_flags.extend (create {PT_FLAG}.make ({PT_FLAG_KIND}.Missing, create {PT_TIME_SPAN}.make (0, 0),
					a_missing.first, a_missing.last, a_missing.count.out + " script words have no usable take"))
			end
			from i := 1 until i > a_timeline.count loop
				l_occ := a_timeline.occurrence (i)
				if l_occ.confidence < Low_confidence_level then
					last_flags.extend (create {PT_FLAG}.make ({PT_FLAG_KIND}.Low_confidence, l_occ.span, l_occ.word, l_occ.word,
						{STRING_32} "low confidence word"))
				end
				from j := i + 1 until j > a_timeline.count or else a_timeline.occurrence (j).attempt /= l_occ.attempt loop
					l_other := a_timeline.occurrence (j)
					if l_other.word ~ l_occ.word then
						last_flags.extend (create {PT_FLAG}.make ({PT_FLAG_KIND}.Unmarked_restart,
							create {PT_TIME_SPAN}.make (l_occ.span.t0, l_other.span.t1.max (l_occ.span.t0)), l_occ.word, l_occ.word,
							{STRING_32} "the same words were read twice without Again"))
						j := a_timeline.count
					end
					j := j + 1
				end
				i := i + 1
			end
		ensure
			tight_flagged: count_of ({PT_FLAG_KIND}.Tight_splice) = tight_count (a_cuts)
			missing_flagged: a_missing.is_empty = (count_of ({PT_FLAG_KIND}.Missing) = 0)
		end

feature -- Constants

	Low_confidence_level: REAL_64 = 0.35

feature {NONE} -- Implementation

	first_or_none (a_cut: PT_CUT): PT_WORD_ID
		do
			if not a_cut.word_ids.is_empty then
				Result := a_cut.word_ids.first
			end
		end

	last_or_none (a_cut: PT_CUT): PT_WORD_ID
		do
			if not a_cut.word_ids.is_empty then
				Result := a_cut.word_ids.last
			end
		end

feature -- Contract helpers

	tight_count (a_cuts: PT_CUT_LIST): INTEGER
		do
			across 1 |..| a_cuts.count as i loop
				if a_cuts.cut (i).is_tight then
					Result := Result + 1
				end
			end
		end

invariant
	positive: long_pause_s > 0

end
