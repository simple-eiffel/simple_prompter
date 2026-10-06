note
	description: "[
		Derives attempts from the journal (live marks only): one per Resume, ending
		at the next Hold, Flub, Wrap or Abort (or the end of the recording).
		The word range is estimated from Align samples; the analysis pass refines it.
	]"
	author: "Larry Rix"

class
	PT_ATTEMPT_BUILDER

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_attempts.make (0)
		ensure
			nothing_built: last_attempts.is_empty
		end

feature -- Access

	last_attempts: ARRAYED_LIST [PT_ATTEMPT]
			-- Result of the last `build'.

feature -- Basic operations

	build (a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY; a_end_rt: REAL_64)
			-- Attempts of a session ending at `a_end_rt'.
		require
			ended: a_end_rt >= a_journal.last_rt
			has_revision: a_history.revision_count >= 1
		local
			l_open: BOOLEAN
			l_t0: REAL_64
			l_caret: PT_WORD_ID
			l_rev, l_first, l_last, l_index, l_kind, l_i: INTEGER
			l_star, l_reject: BOOLEAN
			l_event: PT_TAKE_EVENT
			l_revision: PT_SCRIPT_REVISION
		do
			create last_attempts.make (a_journal.count_of ({PT_EVENT_KIND}.Resume))
			from l_i := 1 until l_i > a_journal.count loop
				l_event := a_journal.event (l_i)
				l_kind := l_event.kind
				if l_kind = {PT_EVENT_KIND}.Resume then
					if l_open then
						close_attempt (l_t0, l_event.rt, l_caret, l_rev, l_first, l_last, l_star, l_reject)
					end
					l_open := True
					l_t0 := l_event.rt
					l_caret := l_event.caret
					l_rev := l_event.to_rev.max (1).min (a_history.revision_count)
					l_revision := a_history.revision (l_rev)
					l_first := l_revision.index_of (l_caret).max (1)
					l_last := l_first - 1
					l_star := False
					l_reject := False
				elseif l_kind = {PT_EVENT_KIND}.Hold or l_kind = {PT_EVENT_KIND}.Flub
					or l_kind = {PT_EVENT_KIND}.Wrap or l_kind = {PT_EVENT_KIND}.Abort then
					if l_open then
						close_attempt (l_t0, l_event.rt, l_caret, l_rev, l_first, l_last, l_star, l_reject)
						l_open := False
					end
				elseif l_kind = {PT_EVENT_KIND}.Align then
					if l_open then
						l_index := a_history.revision (l_rev).index_of (l_event.word)
						if l_index > l_last then
							l_last := l_index
						end
					end
				elseif l_kind = {PT_EVENT_KIND}.Star or l_kind = {PT_EVENT_KIND}.Reject then
						-- One mark, one attempt (review M9): the attempt being read, else the last one closed.
					if l_open then
						l_star := l_kind = {PT_EVENT_KIND}.Star
						l_reject := not l_star
					elseif not last_attempts.is_empty then
						remark_last (l_kind = {PT_EVENT_KIND}.Star)
					end
				end
				l_i := l_i + 1
			end
			if l_open then
				close_attempt (l_t0, a_end_rt, l_caret, l_rev, l_first, l_last, l_star, l_reject)
			end
		ensure
			one_per_resume: last_attempts.count = a_journal.count_of ({PT_EVENT_KIND}.Resume)
			indexed: across 1 |..| last_attempts.count as i all last_attempts [i].index = i end
			ordered_disjoint: across 2 |..| last_attempts.count as i all
					last_attempts [i - 1].span.t1 <= last_attempts [i].span.t0 end
			within: across last_attempts as ic all ic.span.t1 <= a_end_rt end
			known_revisions: across last_attempts as ic all ic.revision <= a_history.revision_count end
			one_star_one_attempt: starred_count <= a_journal.count_of ({PT_EVENT_KIND}.Star)
			not_both: across last_attempts as ic all not (ic.is_starred and ic.is_rejected) end
		end

feature {NONE} -- Implementation

	close_attempt (a_t0, a_t1: REAL_64; a_caret: PT_WORD_ID; a_rev, a_first, a_last: INTEGER; a_star, a_reject: BOOLEAN)
			-- Record the attempt that ran from `a_t0' to `a_t1'.
		do
			last_attempts.extend (create {PT_ATTEMPT}.make (last_attempts.count + 1, create {PT_TIME_SPAN}.make (a_t0, a_t1.max (a_t0)),
				a_caret, a_rev, a_first, a_last.max (a_first - 1), a_star, a_reject and not a_star))
		end

	remark_last (a_star: BOOLEAN)
			-- Star (or reject) the most recently closed attempt.
		local
			l_a: PT_ATTEMPT
		do
			l_a := last_attempts.last
			last_attempts.put_i_th (create {PT_ATTEMPT}.make (l_a.index, l_a.span, l_a.caret, l_a.revision,
				l_a.first_index, l_a.last_index, a_star, not a_star), last_attempts.count)
		end

feature -- Contract helpers

	starred_count: INTEGER
			-- Starred attempts in `last_attempts'.
		do
			across last_attempts as ic loop
				if ic.is_starred then
					Result := Result + 1
				end
			end
		end

end
