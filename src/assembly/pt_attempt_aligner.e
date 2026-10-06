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

feature -- Basic operations

	align (a_attempts: LIST [PT_ATTEMPT]; a_history: PT_SCRIPT_HISTORY; a_heard: PT_HEARD_WORDS)
			-- Occurrences of script words heard during each attempt.
		require
			revisions_known: across a_attempts as ic all ic.revision >= 1 and ic.revision <= a_history.revision_count end
		local
			l_revision: PT_SCRIPT_REVISION
			l_attempt: PT_ATTEMPT
			l_pointer, l_found, l_i, l_j, l_k: INTEGER
			l_word: PT_HEARD_WORD
		do
			create last_timeline.make
			from l_k := 1 until l_k > a_attempts.count loop
				l_attempt := a_attempts [l_k]
				l_revision := a_history.revision (l_attempt.revision)
					-- Start a little before the caret so run-up words match the words they are.
				l_pointer := (l_revision.index_of (l_attempt.caret).max (1) - Run_up).max (1)
				from l_i := 1 until l_i > a_heard.count loop
					l_word := a_heard.word (l_i)
					if l_attempt.span.contains (l_word.t0) and then l_word.t0 >= last_timeline.last_start
						and then not l_word.normalized.is_empty then
						l_found := 0
						from l_j := l_pointer until l_found > 0 or l_j > (l_pointer + Lookahead).min (l_revision.word_count) loop
							if matcher.matches (l_word.normalized, l_revision.word (l_j)) then
								l_found := l_j
							end
							l_j := l_j + 1
						end
						if l_found > 0 then
							last_timeline.extend (create {PT_WORD_OCCURRENCE}.make (l_revision.word (l_found).id,
								create {PT_TIME_SPAN}.make (l_word.t0, l_word.t1), l_word.probability, l_attempt.index))
							l_pointer := l_found + 1
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

end
