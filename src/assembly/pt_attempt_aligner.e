note
	description: "[
		Aligns the words heard in the full recording to the script, attempt by
		attempt, against the revision current during each attempt. Searches near
		the attempt's journaled caret (so a repeated phrase is matched where the
		reader actually restarted, R-T3) and finds the caret word inside a run-up.
	]"
	author: "Larry Rix"

class
	PT_ATTEMPT_ALIGNER

create
	make

feature {NONE} -- Initialization

	make (a_matcher: PT_WORD_MATCHER)
		do
			matcher := a_matcher
			create last_timeline.make
			create last_misreads.make (0)
		ensure
			matcher_set: matcher = a_matcher
			empty: last_timeline.count = 0
		end

feature -- Constants

	Run_up: INTEGER = 6
	Lookahead: INTEGER = 8

feature -- Access

	matcher: PT_WORD_MATCHER

	last_timeline: PT_WORD_TIMELINE
			-- Result of the last `align'.

	last_misreads: ARRAYED_LIST [PT_MISREAD]
			-- One-for-one substitutions found by the last `align' (T18): heard words that matched
			-- nothing, followed by a match that skipped exactly as many script words.

	Lost_after: INTEGER = 2
			-- Unmatched heard words in a row before the search widens (skipped paragraph, ad-lib);
			-- the confirmation rule keeps an ad-lib word from pulling the pointer.

	Wide_lookahead: INTEGER = 60
			-- Spoken words searched when lost (content words only, confirmed by the next heard word).

	Max_substitution: INTEGER = 3
			-- Longest run of substituted words reported as misreads (longer runs are ad-libs or
			-- lost alignment, not misreads).

feature -- Basic operations

	align (a_attempts: LIST [PT_ATTEMPT]; a_history: PT_SCRIPT_HISTORY; a_heard: PT_HEARD_WORDS)
			-- Occurrences of script words heard during each attempt.
		require
			revisions_known: across a_attempts as ic all ic.revision >= 1 and ic.revision <= a_history.revision_count end
		local
			l_revision: PT_SCRIPT_REVISION
			l_attempt: PT_ATTEMPT
			l_pointer, l_found, l_i, l_k, l_width, l_n: INTEGER
			l_word: PT_HEARD_WORD
			l_pending: ARRAYED_LIST [PT_HEARD_WORD]
			l_lost: BOOLEAN
			l_t1: REAL_64
			l_retro: ARRAYED_LIST [INTEGER]
			l_gap: ARRAYED_LIST [PT_HEARD_WORD]
			l_back: PT_HEARD_WORD
		do
			create last_timeline.make
			create last_misreads.make (4)
			create l_pending.make (Max_substitution + 1)
			from l_k := 1 until l_k > a_attempts.count loop
				l_attempt := a_attempts [l_k]
				l_revision := a_history.revision (l_attempt.revision)
				l_pending.wipe_out
					-- Start a little before the caret so run-up words match the words they are.
				l_pointer := (l_revision.index_of (l_attempt.caret).max (1) - Run_up).max (1)
				from l_i := 1 until l_i > a_heard.count loop
					l_word := a_heard.word (l_i)
					if l_attempt.span.contains (l_word.t0) and then l_word.t0 >= last_timeline.last_start
						and then not l_word.normalized.is_empty then
						l_lost := l_pending.count >= Lost_after
						l_found := next_match (l_word.normalized, l_revision, l_pointer, l_lost)
						if l_found > 0 and l_lost and then not is_confirmed (a_heard, l_i, l_revision, l_found) then
								-- When lost, one content word could be an ad-lib echo: the next heard
								-- word must match the next spoken script word too.
							l_found := 0
						end
						l_width := 1
						l_t1 := l_word.t1.max (l_word.t0)
						if l_found > 0 then
							l_width := match_width (l_word.normalized, l_revision, l_found)
						elseif not l_lost and l_i < a_heard.count then
								-- Two heard words for one script word ("for example" for "e.g.").
							l_found := pair_match (l_word.normalized + {STRING_32} " " + a_heard.word (l_i + 1).normalized,
								l_revision, l_pointer)
							if l_found > 0 then
								l_t1 := a_heard.word (l_i + 1).t1.max (l_word.t0)
								l_i := l_i + 1
							end
						end
						if l_found > 0 then
								-- After a lost-mode jump, the unmatched words just before it that match
								-- the script words just before it were read there too.
							if l_lost then
								l_retro := retro_indices (l_pending, l_revision, l_pointer, l_found)
							else
								create l_retro.make (0)
							end
							create l_gap.make (l_pending.count)
							from l_n := 1 until l_n > l_pending.count - l_retro.count loop
								l_gap.extend (l_pending [l_n])
								l_n := l_n + 1
							end
							if l_retro.is_empty then
								record_substitutions (l_gap, l_revision, l_pointer, l_found - 1, l_attempt.index)
							else
								record_substitutions (l_gap, l_revision, l_pointer, l_retro.first - 1, l_attempt.index)
							end
							from l_n := 1 until l_n > l_retro.count loop
								l_back := l_pending [l_pending.count - l_retro.count + l_n]
								last_timeline.extend (create {PT_WORD_OCCURRENCE}.make (l_revision.word (l_retro [l_n]).id,
									create {PT_TIME_SPAN}.make (l_back.t0, l_back.t1.max (l_back.t0)), l_back.probability, l_attempt.index))
								l_n := l_n + 1
							end
							l_pending.wipe_out
							from l_n := 0 until l_n >= l_width loop
								last_timeline.extend (create {PT_WORD_OCCURRENCE}.make (l_revision.word (l_found + l_n).id,
									create {PT_TIME_SPAN}.make (l_word.t0, l_t1), l_word.probability, l_attempt.index))
								l_n := l_n + 1
							end
							l_pointer := l_found + l_width
						elseif not is_tag (l_word.text) then
							l_pending.extend (l_word)
						end
					end
					l_i := l_i + 1
				end
				l_k := l_k + 1
			end
		ensure
			inside_attempts: across 1 |..| last_timeline.count as i all
					last_timeline.occurrence (i).attempt <= a_attempts.count and then
					a_attempts [last_timeline.occurrence (i).attempt].span.contains (last_timeline.occurrence (i).span.t0) end
			words_of_revision: across 1 |..| last_timeline.count as i all
					a_history.revision (a_attempts [last_timeline.occurrence (i).attempt].revision).index_of (last_timeline.occurrence (i).word) > 0 end
		end

feature {NONE} -- Implementation

	record_substitutions (a_heard: LIST [PT_HEARD_WORD]; a_revision: PT_SCRIPT_REVISION; a_first, a_last, a_attempt: INTEGER)
			-- If the unmatched heard words `a_heard' replaced script words `a_first'..`a_last' one for
			-- one, add a misread for each pair. Skipped cue words mean the gap was not read as written.
		local
			l_n: INTEGER
			l_spoken: ARRAYED_LIST [INTEGER]
		do
			if not a_heard.is_empty and then a_heard.count <= Max_substitution then
					-- Cue words in the gap are never read aloud; pair only the spoken ones.
				create l_spoken.make (a_heard.count)
				from l_n := a_first until l_n > a_last or l_spoken.count > a_heard.count loop
					if not a_revision.word (l_n).is_cue and not a_revision.word (l_n).normalized.is_empty then
						l_spoken.extend (l_n)
					end
					l_n := l_n + 1
				end
				if l_spoken.count = a_heard.count then
					from l_n := 1 until l_n > a_heard.count loop
						last_misreads.extend (create {PT_MISREAD}.make (a_revision.word (l_spoken [l_n]).id,
							a_revision.word (l_spoken [l_n]).text, a_heard [l_n].normalized,
							create {PT_TIME_SPAN}.make (a_heard [l_n].t0, a_heard [l_n].t1.max (a_heard [l_n].t0)), a_attempt))
							-- The slot was read (wrongly): the take still covers the passage, and the
							-- Misread flag tells the Edit Floor.
						last_timeline.extend (create {PT_WORD_OCCURRENCE}.make (a_revision.word (l_spoken [l_n]).id,
							create {PT_TIME_SPAN}.make (a_heard [l_n].t0, a_heard [l_n].t1.max (a_heard [l_n].t0)),
							a_heard [l_n].probability, a_attempt))
						l_n := l_n + 1
					end
				end
			end
		ensure
			only_added: last_misreads.count >= old last_misreads.count
			bounded: last_misreads.count <= old last_misreads.count + Max_substitution
		end

	retro_indices (a_pending: LIST [PT_HEARD_WORD]; a_revision: PT_SCRIPT_REVISION; a_floor, a_found: INTEGER): ARRAYED_LIST [INTEGER]
			-- Script indices, ascending, of the spoken words just before `a_found' (not below `a_floor')
			-- that the trailing words of `a_pending' match, newest first, stopping at the first mismatch.
		require
			floor_positive: a_floor >= 1
			found_after_floor: a_found >= a_floor and a_found <= a_revision.word_count
		local
			l_p, l_j: INTEGER
			l_stop: BOOLEAN
		do
			create Result.make (4)
			l_p := a_pending.count
			l_j := a_found - 1
			from until l_stop or l_p < 1 or l_j < a_floor loop
				if a_revision.word (l_j).is_cue then
					l_j := l_j - 1
				elseif matcher.matches (a_pending [l_p].normalized, a_revision.word (l_j)) then
					Result.put_front (l_j)
					l_p := l_p - 1
					l_j := l_j - 1
				else
					l_stop := True
				end
			end
		ensure
			bounded: Result.count <= a_pending.count
			ascending: across 2 |..| Result.count as i all Result [i] > Result [i - 1] end
			in_gap: across Result as ic all ic >= a_floor and ic < a_found end
		end

	next_match (a_heard: READABLE_STRING_32; a_revision: PT_SCRIPT_REVISION; a_from: INTEGER; a_lost: BOOLEAN): INTEGER
			-- First script word at or after `a_from' matching `a_heard', within `Lookahead' spoken
			-- words (cue words are skipped and not counted: a long [CUE] line must not end the search;
			-- T18 on larry_read_01); when `a_lost', within `Wide_lookahead' spoken words, content words
			-- only. Only a content word (or a multi-word token) may skip ahead: a stop word matches
			-- the next spoken word or nothing ("So" in an ad-lib must not jump the script). 0 if none.
		require
			from_positive: a_from >= 1
		local
			l_j, l_spoken, l_limit, l_width: INTEGER
		do
			if a_lost then
				l_limit := Wide_lookahead
			else
				l_limit := Lookahead
			end
			from l_j := a_from until Result > 0 or l_j > a_revision.word_count or l_spoken > l_limit loop
				if not a_revision.word (l_j).is_cue then
					l_spoken := l_spoken + 1
					l_width := match_width (a_heard, a_revision, l_j)
					if l_width >= 2 or else (l_width = 1 and then (not a_revision.word (l_j).is_stop_word
						or else (l_spoken = 1 and not a_lost))) then
						Result := l_j
					end
				end
				l_j := l_j + 1
			end
		ensure
			in_range: Result = 0 or (Result >= a_from and Result <= a_revision.word_count)
			never_a_cue: Result > 0 implies not a_revision.word (Result).is_cue
		end

	match_width (a_heard: READABLE_STRING_32; a_revision: PT_SCRIPT_REVISION; a_j: INTEGER): INTEGER
			-- Script words from `a_j' that heard token `a_heard' stands for: 1 for a direct match, 2 or 3
			-- for one token covering consecutive spoken words ("cpp" for "c p p"; spaces removed, no
			-- sound-alike keys), 0 for none.
		require
			valid: a_j >= 1 and a_j <= a_revision.word_count
		do
			if a_revision.word (a_j).is_cue then
				Result := 0
			elseif matcher.matches (a_heard, a_revision.word (a_j)) then
				Result := 1
			elseif not a_heard.has (' ') and then is_spoken_run (a_revision, a_j, 2)
				and then matcher.equivalences.joined (a_heard).same_string (run_text (a_revision, a_j, 2)) then
				Result := 2
			elseif not a_heard.has (' ') and then is_spoken_run (a_revision, a_j, 3)
				and then matcher.equivalences.joined (a_heard).same_string (run_text (a_revision, a_j, 3)) then
				Result := 3
			end
		ensure
			range: Result >= 0 and Result <= 3
			cue_never: a_revision.word (a_j).is_cue implies Result = 0
			fits: Result >= 2 implies is_spoken_run (a_revision, a_j, Result)
		end

	pair_match (a_pair: READABLE_STRING_32; a_revision: PT_SCRIPT_REVISION; a_from: INTEGER): INTEGER
			-- First script word within `Lookahead' spoken words from `a_from' that the two heard words
			-- `a_pair' stand for together (spoken abbreviation, split compound), 0 if none.
		require
			from_positive: a_from >= 1
			is_pair: a_pair.has (' ')
		local
			l_j, l_spoken: INTEGER
		do
			from l_j := a_from until Result > 0 or l_j > a_revision.word_count or l_spoken > Lookahead loop
				if not a_revision.word (l_j).is_cue then
					l_spoken := l_spoken + 1
					if matcher.matches (a_pair, a_revision.word (l_j)) then
						Result := l_j
					end
				end
				l_j := l_j + 1
			end
		ensure
			in_range: Result = 0 or (Result >= a_from and Result <= a_revision.word_count)
			never_a_cue: Result > 0 implies not a_revision.word (Result).is_cue
		end

	is_spoken_run (a_revision: PT_SCRIPT_REVISION; a_j, a_count: INTEGER): BOOLEAN
			-- Are words `a_j'..`a_j' + `a_count' - 1 all in the script and none of them cue words?
		require
			valid: a_j >= 1 and a_count >= 1
		local
			l_n: INTEGER
		do
			Result := a_j + a_count - 1 <= a_revision.word_count
			from l_n := a_j until not Result or l_n > a_j + a_count - 1 loop
				Result := not a_revision.word (l_n).is_cue
				l_n := l_n + 1
			end
		end

	run_text (a_revision: PT_SCRIPT_REVISION; a_j, a_count: INTEGER): STRING_32
			-- Normalized words `a_j'..`a_j' + `a_count' - 1 run together without spaces.
		require
			fits: is_spoken_run (a_revision, a_j, a_count)
		local
			l_n: INTEGER
		do
			create Result.make (16)
			from l_n := a_j until l_n > a_j + a_count - 1 loop
				Result.append (matcher.equivalences.joined (a_revision.word (l_n).normalized))
				l_n := l_n + 1
			end
		end

	is_confirmed (a_heard: PT_HEARD_WORDS; a_index: INTEGER; a_revision: PT_SCRIPT_REVISION; a_word: INTEGER): BOOLEAN
			-- Does heard word `a_index' + 1 match the spoken script word after `a_word'?
		require
			valid_index: a_index >= 1 and a_index <= a_heard.count
			valid_word: a_word >= 1 and a_word <= a_revision.word_count
		local
			l_next: INTEGER
		do
			from l_next := a_word + 1 until l_next > a_revision.word_count or else not a_revision.word (l_next).is_cue loop
				l_next := l_next + 1
			end
			Result := a_index < a_heard.count and then l_next <= a_revision.word_count
				and then matcher.matches (a_heard.word (a_index + 1).normalized, a_revision.word (l_next))
		end

	is_tag (a_text: READABLE_STRING_32): BOOLEAN
			-- Is `a_text' a non-speech tag such as [BLANK_AUDIO], (cough) or *laughs*?
		do
			Result := not a_text.is_empty and then (a_text [1] = '[' or a_text [1] = '(' or a_text [1] = '*')
		end

end
