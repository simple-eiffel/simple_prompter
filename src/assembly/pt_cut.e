note
	description: "[
		One kept interval of a source recording in the final video: which words it
		carries (ids, in order), from which attempt, and whether its edges could
		not be placed in silence (tight).
	]"
	author: "Larry Rix"

class
	PT_CUT

create
	make

feature {NONE} -- Initialization

	make (a_src: INTEGER; a_span: PT_TIME_SPAN; a_word_ids: ITERABLE [PT_WORD_ID];
			a_first_index, a_last_index, a_attempt: INTEGER; a_tight: BOOLEAN)
			-- Interval `a_span' of source `a_src' carrying final-revision words `a_first_index'..`a_last_index'.
		require
			src_non_negative: a_src >= 0
			first_positive: a_first_index >= 1
			ordered: a_first_index <= a_last_index
			attempt_positive: a_attempt >= 1
		do
			src := a_src
			span := a_span
			create word_ids.make (a_last_index - a_first_index + 1)
			across a_word_ids as ic loop
				word_ids.extend (ic)
			end
			first_word_index := a_first_index
			last_word_index := a_last_index
			attempt := a_attempt
			is_tight := a_tight
		ensure
			src_set: src = a_src
			span_set: span = a_span
			range_set: first_word_index = a_first_index and last_word_index = a_last_index
			attempt_set: attempt = a_attempt
			tight_set: is_tight = a_tight
		end

feature -- Access

	src: INTEGER
			-- Source file index (0 = raw.mkv; pickups later).
	span: PT_TIME_SPAN
	word_ids: ARRAYED_LIST [PT_WORD_ID]
			-- Spoken final-revision word ids carried, in order (cue words excluded).
	first_word_index, last_word_index: INTEGER
	attempt: INTEGER

	first_word: PT_WORD_ID
		require
			has_words: not word_ids.is_empty
		do
			Result := word_ids.first
		end

	last_word: PT_WORD_ID
		require
			has_words: not word_ids.is_empty
		do
			Result := word_ids.last
		end

feature -- Status

	is_tight: BOOLEAN

feature -- Derivation

	with_span (a_span: PT_TIME_SPAN; a_tight: BOOLEAN): PT_CUT
			-- Same words and attempt over `a_span'.
		do
			create Result.make (src, a_span, word_ids, first_word_index, last_word_index, attempt, a_tight)
		ensure
			same_words: Result.word_ids ~ word_ids
			span_set: Result.span = a_span
		end

invariant
	src_non_negative: src >= 0
	first_positive: first_word_index >= 1
	ordered: first_word_index <= last_word_index
	attempt_positive: attempt >= 1
	ids_fit_range: word_ids.count <= last_word_index - first_word_index + 1

end
