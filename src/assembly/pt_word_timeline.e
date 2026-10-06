note
	description: "[
		Script words heard in a recording, ordered by start time. A word read
		several times (retakes) has one occurrence per attempt, so lookups are
		per attempt.
	]"
	author: "Larry Rix"

class
	PT_WORD_TIMELINE

create
	make

feature {NONE} -- Initialization

	make
		do
			create occurrence_list.make (256)
		ensure
			empty: count = 0
		end

feature -- Access

	count: INTEGER
		do
			Result := occurrence_list.count
		end

	occurrence (a_index: INTEGER): PT_WORD_OCCURRENCE
		require
			valid_index: a_index >= 1 and a_index <= count
		do
			Result := occurrence_list [a_index]
		end

	last_start: REAL_64
			-- Start of the last occurrence (0 when empty).
		do
			if not occurrence_list.is_empty then
				Result := occurrence_list.last.span.t0
			end
		end

	occurrence_in (a_word: PT_WORD_ID; a_attempt: INTEGER): detachable PT_WORD_OCCURRENCE
			-- Occurrence of `a_word' in attempt `a_attempt', if heard there.
		do
			across occurrence_list as ic until attached Result loop
				if ic.word ~ a_word and ic.attempt = a_attempt then
					Result := ic
				end
			end
		ensure
			matches: attached Result as al_r implies (al_r.word ~ a_word and al_r.attempt = a_attempt)
		end

	has_in (a_word: PT_WORD_ID; a_attempt: INTEGER): BOOLEAN
			-- Was `a_word' heard in attempt `a_attempt'?
		do
			Result := attached occurrence_in (a_word, a_attempt)
		end

feature -- Model

	occurrences_model: MML_SEQUENCE [PT_WORD_OCCURRENCE]
		do
			create Result
			across occurrence_list as ic loop
				Result := Result & ic
			end
		ensure
			same_count: Result.count = count
		end

feature -- Element change

	extend (a_occurrence: PT_WORD_OCCURRENCE)
			-- Add the next occurrence (start-time order).
		require
			ordered: a_occurrence.span.t0 >= last_start
		do
			occurrence_list.extend (a_occurrence)
		ensure
			appended: (occurrences_model |=| (old occurrences_model & a_occurrence))
		end

feature {NONE} -- Implementation

	occurrence_list: ARRAYED_LIST [PT_WORD_OCCURRENCE]

invariant
	last_start_non_negative: last_start >= 0

end
