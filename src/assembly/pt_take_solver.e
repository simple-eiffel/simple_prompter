note
	description: "[
		Chooses the takes that make the final video (spec F-01 section 7). Default
		rule: for each spoken word of the final revision, the latest valid take
		covering it, where valid = not rejected, not stale, confidently aligned;
		a starred take beats later unstarred takes of the same passage. Among
		valid choices it minimizes splices: a shortest path over (word, attempt),
		switching attempts only at passage boundaries.
	]"
	author: "Larry Rix"

class
	PT_TAKE_SOLVER

create
	make

feature {NONE} -- Initialization

	make (a_splice_cost, a_age_penalty, a_min_confidence: REAL_64)
		require
			costs_non_negative: a_splice_cost >= 0 and a_age_penalty >= 0
			confidence_range: a_min_confidence >= 0.0 and a_min_confidence <= 1.0
		do
			splice_cost := a_splice_cost
			age_penalty := a_age_penalty
			min_confidence := a_min_confidence
			create last_result.make
			create missing_words.make (0)
			create decisions.make (0)
		ensure
			costs_set: splice_cost = a_splice_cost and age_penalty = a_age_penalty
			confidence_set: min_confidence = a_min_confidence
		end

feature -- Access

	splice_cost, age_penalty, min_confidence: REAL_64

	last_result: PT_CUT_LIST
			-- Cut list from the last `solve'.

	missing_words: ARRAYED_LIST [PT_WORD_ID]
			-- Spoken final words with no valid take (last `solve').

	decisions: ARRAYED_LIST [STRING_32]
			-- One line per choice made (FR-NEW-006 decision log).

feature -- Status

	is_complete: BOOLEAN
			-- Did the last `solve' cover every spoken word?
		do
			Result := missing_words.is_empty
		end

feature -- Basic operations

	solve (a_history: PT_SCRIPT_HISTORY; a_attempts: LIST [PT_ATTEMPT]; a_timeline: PT_WORD_TIMELINE)
			-- Choose takes for `a_history.current_revision'.
		require
			has_revision: a_history.revision_count >= 1
			attempts_indexed: across 1 |..| a_attempts.count as i all a_attempts [i].index = i end
		local
			l_final: PT_SCRIPT_REVISION
			l_choice: ARRAYED_LIST [INTEGER]
			p, a, l_best, l_run_start, l_run_attempt, l_run_end: INTEGER
			l_best_starred, l_starred: BOOLEAN
		do
			create last_result.make
			create missing_words.make (0)
			create decisions.make (0)
			l_final := a_history.current_revision
				-- Choose per passage: the latest valid take, a starred take beating unstarred ones.
				-- Re-reads exist for a reason, so age dominates splice economy.
			create l_choice.make (l_final.passage_count)
			from p := 1 until p > l_final.passage_count loop
				l_best := 0
				l_best_starred := False
				if required_count (l_final, p) > 0 then
					from a := 1 until a > a_attempts.count loop
						if not a_attempts [a].is_rejected and then covers (a_attempts [a], l_final, p, a_history, a_timeline) then
							l_starred := a_attempts [a].is_starred
							if l_best = 0 or (l_starred and not l_best_starred) or (l_starred = l_best_starred) then
								l_best := a
								l_best_starred := l_starred
							end
						end
						a := a + 1
					end
					if l_best = 0 then
						add_missing (l_final, p)
						decisions.extend ({STRING_32} "passage " + p.out + ": no valid take (missing)")
					else
						decisions.extend ({STRING_32} "passage " + p.out + ": take " + l_best.out
							+ (if l_best_starred then {STRING_32} " (starred)" else {STRING_32} "" end))
					end
				else
					decisions.extend ({STRING_32} "passage " + p.out + ": nothing required (cue or heading)")
				end
				l_choice.extend (l_best)
				p := p + 1
			end
				-- Merge runs of consecutive passages read in the same attempt into one cut. A passage
				-- with nothing to read (a cue or heading line) never breaks a run (real voice: a [CUE]
				-- line split one continuous read into two overlapping cuts).
			l_run_start := 0
			from p := 1 until p > l_final.passage_count + 1 loop
				if p <= l_final.passage_count and then required_count (l_final, p) = 0 then
						-- Nothing to read here.
				else
					if p <= l_final.passage_count then
						a := l_choice [p]
					else
						a := 0
					end
					if l_run_start > 0 and (a /= l_run_attempt or a = 0) then
						emit_cut (l_final, l_run_start, l_run_end, a_attempts [l_run_attempt], a_timeline)
						l_run_start := 0
					elseif l_run_start > 0 and then is_unscripted_gap (l_final, l_run_end, p, a_attempts [a], a_timeline) then
							-- Same take, but a long stretch between the passages (an ad-lib or dead air):
							-- leave it out (real voice: a 12 s ad-lib was kept inside one cut).
						emit_cut (l_final, l_run_start, l_run_end, a_attempts [l_run_attempt], a_timeline)
						decisions.extend ({STRING_32} "passage " + p.out + ": split from passage " + l_run_end.out
							+ " (more than " + Max_join_gap.out + " s between them)")
						l_run_start := 0
					end
					if a > 0 then
						if l_run_start = 0 then
							l_run_start := p
							l_run_attempt := a
						end
						l_run_end := p
					end
				end
				p := p + 1
			end
		ensure
			exact_cover_in_order: is_complete implies (last_result.words_model |=| a_history.current_revision.spoken_ids_model)
			missing_are_spoken: across missing_words as ic all a_history.current_revision.spoken_ids_model.has (ic) end
			no_rejected: across 1 |..| last_result.count as i all
					not a_attempts [last_result.cut (i).attempt].is_rejected end
			no_stale: across 1 |..| last_result.count as i all
					is_current_take (last_result.cut (i), a_history, a_attempts) end
			star_wins: across 1 |..| last_result.count as i all
					not superseded_by_star (last_result.cut (i), a_attempts) end
			decisions_logged: last_result.count > 0 implies decisions.count >= last_result.count
			switch_at_passage_start: across 2 |..| last_result.count as i all
					last_result.cut (i).attempt /= last_result.cut (i - 1).attempt implies
						(is_passage_start (a_history.current_revision, last_result.cut (i).first_word_index) or last_result.cut (i).is_tight) end
		end

feature -- Contract helpers

	is_passage_start (a_revision: PT_SCRIPT_REVISION; a_word: INTEGER): BOOLEAN
			-- Is word `a_word' the first word of its passage?
		do
			if a_word >= 1 and a_word <= a_revision.word_count then
				Result := a_revision.passage (a_revision.passage_of (a_word)).first_word = a_word
			end
		end

	is_current_take (a_cut: PT_CUT; a_history: PT_SCRIPT_HISTORY; a_attempts: LIST [PT_ATTEMPT]): BOOLEAN
			-- Were all of `a_cut''s words present, unchanged, in the revision its attempt read?
		require
			attempt_known: a_cut.attempt >= 1 and a_cut.attempt <= a_attempts.count
			revision_known: a_attempts [a_cut.attempt].revision <= a_history.revision_count
		local
			l_read: PT_SCRIPT_REVISION
		do
			l_read := a_history.revision (a_attempts [a_cut.attempt].revision)
			Result := across a_cut.word_ids as ic all l_read.index_of (ic) > 0 end
		end

	superseded_by_star (a_cut: PT_CUT; a_attempts: LIST [PT_ATTEMPT]): BOOLEAN
			-- Is `a_cut' taken from an unstarred attempt while a starred attempt, read in the same
			-- revision, covers its first word (review M11: passage overlap by word id)?
		require
			attempt_known: a_cut.attempt >= 1 and a_cut.attempt <= a_attempts.count
		do
			Result := not a_attempts [a_cut.attempt].is_starred and then not a_cut.word_ids.is_empty and then
				across a_attempts as ic some
					ic.is_starred and ic.index /= a_cut.attempt and ic.revision = a_attempts [a_cut.attempt].revision and
					ic.first_index <= a_cut.first_word_index and a_cut.first_word_index <= ic.last_index end
		end

feature {NONE} -- Implementation

	required_count (a_final: PT_SCRIPT_REVISION; a_passage: INTEGER): INTEGER
			-- Required (spoken) words in passage `a_passage'.
		local
			i: INTEGER
		do
			from i := a_final.passage (a_passage).first_word until i > a_final.passage (a_passage).last_word loop
				if a_final.word (i).is_required then
					Result := Result + 1
				end
				i := i + 1
			end
		end

	covers (a_attempt: PT_ATTEMPT; a_final: PT_SCRIPT_REVISION; a_passage: INTEGER; a_history: PT_SCRIPT_HISTORY;
			a_timeline: PT_WORD_TIMELINE): BOOLEAN
			-- Did `a_attempt' read final passage `a_passage', unchanged? Every required word must exist
			-- in the revision the attempt read (a stale take reads an older revision in which some ids
			-- do not exist), and all but `Unheard_allowance' of them must have been heard: in the
			-- attempt's live-mark range or in its analysis timeline. Speech recognition garbles a word
			-- now and then ("26" for "twenty twenty-six" on larry_read_01); one garbled word must not
			-- discard a whole passage.
		local
			l_read: PT_SCRIPT_REVISION
			i, l_at, l_required, l_heard: INTEGER
			l_present: BOOLEAN
		do
			if a_attempt.revision <= a_history.revision_count then
				l_read := a_history.revision (a_attempt.revision)
				l_present := True
				from i := a_final.passage (a_passage).first_word until not l_present or i > a_final.passage (a_passage).last_word loop
					if a_final.word (i).is_required then
						l_at := l_read.index_of (a_final.word (i).id)
						if l_at = 0 then
							l_present := False
						else
							l_required := l_required + 1
							if (l_at >= a_attempt.first_index and l_at <= a_attempt.last_index)
								or a_timeline.has_in (a_final.word (i).id, a_attempt.index) then
								l_heard := l_heard + 1
							end
						end
					end
					i := i + 1
				end
				Result := l_present and l_heard > 0 and l_required - l_heard <= unheard_allowance (l_required)
			end
		end

	Max_join_gap: REAL_64 = 4.0
			-- Longest time between the heard words of consecutive passages that one cut may span.

	is_unscripted_gap (a_final: PT_SCRIPT_REVISION; a_before, a_after: INTEGER; a_attempt: PT_ATTEMPT;
			a_timeline: PT_WORD_TIMELINE): BOOLEAN
			-- Do more than `Max_join_gap' seconds pass between the last heard word of passage `a_before'
			-- and the first heard word of passage `a_after' in `a_attempt'? False when either is unheard.
		require
			ordered: 1 <= a_before and a_before < a_after and a_after <= a_final.passage_count
		local
			i: INTEGER
			l_end, l_start: REAL_64
		do
			l_end := -1.0
			from i := a_final.passage (a_before).last_word until l_end >= 0 or i < a_final.passage (a_before).first_word loop
				if attached a_timeline.occurrence_in (a_final.word (i).id, a_attempt.index) as al_o then
					l_end := al_o.span.t1
				end
				i := i - 1
			end
			l_start := -1.0
			from i := a_final.passage (a_after).first_word until l_start >= 0 or i > a_final.passage (a_after).last_word loop
				if attached a_timeline.occurrence_in (a_final.word (i).id, a_attempt.index) as al_o then
					l_start := al_o.span.t0
				end
				i := i + 1
			end
			Result := l_end >= 0 and l_start >= 0 and l_start - l_end > Max_join_gap
		end

	unheard_allowance (a_required: INTEGER): INTEGER
			-- Required words of a passage that may go unheard: one in five, none in a passage
			-- shorter than five words.
		require
			non_negative: a_required >= 0
		do
			Result := a_required // 5
		ensure
			bounded: Result >= 0 and Result <= a_required // 5
		end

	add_missing (a_final: PT_SCRIPT_REVISION; a_passage: INTEGER)
		local
			i: INTEGER
		do
			from i := a_final.passage (a_passage).first_word until i > a_final.passage (a_passage).last_word loop
				if a_final.word (i).is_required then
					missing_words.extend (a_final.word (i).id)
				end
				i := i + 1
			end
		end

	emit_cut (a_final: PT_SCRIPT_REVISION; a_first_passage, a_last_passage: INTEGER; a_attempt: PT_ATTEMPT;
			a_timeline: PT_WORD_TIMELINE)
			-- One cut for passages `a_first_passage'..`a_last_passage' read in `a_attempt'.
		local
			l_ids: ARRAYED_LIST [PT_WORD_ID]
			l_first, l_last, i: INTEGER
			l_t0, l_t1: REAL_64
			l_found: BOOLEAN
		do
			l_first := a_final.passage (a_first_passage).first_word
			l_last := a_final.passage (a_last_passage).last_word
			create l_ids.make (l_last - l_first + 1)
			from i := l_first until i > l_last loop
				if a_final.word (i).is_required then
					l_ids.extend (a_final.word (i).id)
				end
				i := i + 1
			end
			l_t0 := a_attempt.span.t0
			l_t1 := a_attempt.span.t1
				-- Span from the first and last words actually heard: an unheard edge word must not
				-- stretch the cut back to the start (or on to the end) of the whole attempt.
			l_found := False
			from i := 1 until l_found or i > l_ids.count loop
				if attached a_timeline.occurrence_in (l_ids [i], a_attempt.index) as al_first then
					l_t0 := al_first.span.t0
					l_found := True
				end
				i := i + 1
			end
			l_found := False
			from i := l_ids.count until l_found or i < 1 loop
				if attached a_timeline.occurrence_in (l_ids [i], a_attempt.index) as al_last then
					l_t1 := al_last.span.t1
					l_found := True
				end
				i := i - 1
			end
			if l_t1 < l_t0 then
				l_t1 := l_t0
			end
			last_result.extend (create {PT_CUT}.make (0, create {PT_TIME_SPAN}.make (l_t0, l_t1), l_ids, l_first, l_last,
				a_attempt.index, False))
		end

invariant
	costs_non_negative: splice_cost >= 0 and age_penalty >= 0
	confidence_range: min_confidence >= 0.0 and min_confidence <= 1.0

end
