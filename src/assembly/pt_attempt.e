note
	description: "[
		One continuous stretch of reading: from a resume to the next hold, flub,
		wrap or abort. Covers script words first_index..last_index of revision
		`revision' (empty when the reader stopped before finishing a word).
	]"
	author: "Larry Rix"

class
	PT_ATTEMPT

create
	make

feature {NONE} -- Initialization

	make (a_index: INTEGER; a_span: PT_TIME_SPAN; a_caret: PT_WORD_ID; a_revision, a_first_index, a_last_index: INTEGER;
			a_starred, a_rejected: BOOLEAN)
		require
			index_positive: a_index >= 1
			real_caret: not a_caret.is_none
			revision_positive: a_revision >= 1
			first_positive: a_first_index >= 1
			range_ordered: a_last_index >= a_first_index - 1
			not_both: not (a_starred and a_rejected)
		do
			index := a_index
			span := a_span
			caret := a_caret
			revision := a_revision
			first_index := a_first_index
			last_index := a_last_index
			is_starred := a_starred
			is_rejected := a_rejected
		ensure
			index_set: index = a_index
			span_set: span = a_span
			caret_set: caret ~ a_caret
			revision_set: revision = a_revision
			range_set: first_index = a_first_index and last_index = a_last_index
			marks_set: is_starred = a_starred and is_rejected = a_rejected
		end

feature -- Access

	index: INTEGER
	span: PT_TIME_SPAN
	caret: PT_WORD_ID
			-- Restart word the attempt began at.
	revision: INTEGER
	first_index, last_index: INTEGER

	word_count: INTEGER
		do
			Result := last_index - first_index + 1
		ensure
			non_negative: Result >= 0
		end

feature -- Status

	is_starred: BOOLEAN
	is_rejected: BOOLEAN

	is_empty: BOOLEAN
		do
			Result := last_index < first_index
		end

invariant
	index_positive: index >= 1
	real_caret: not caret.is_none
	revision_positive: revision >= 1
	first_positive: first_index >= 1
	range_ordered: last_index >= first_index - 1
	not_both: not (is_starred and is_rejected)

end
