note
	description: "One decode result: the window's start on the sample clock and the words heard in it."
	author: "Larry Rix"

class
	PT_HEARD_WORDS

create
	make

feature {NONE} -- Initialization

	make (a_window_start: INTEGER_64; a_window_samples: INTEGER; a_words: ITERABLE [PT_HEARD_WORD])
			-- Words heard in the window of `a_window_samples' starting at sample `a_window_start'.
		require
			start_non_negative: a_window_start >= 0
			window_positive: a_window_samples > 0
		do
			window_start := a_window_start
			window_samples := a_window_samples
			create word_list.make (8)
			across a_words as ic loop
				word_list.extend (ic)
			end
		ensure
			start_set: window_start = a_window_start
			size_set: window_samples = a_window_samples
		end

feature -- Access

	window_start: INTEGER_64
			-- First sample of the decoded window.

	window_samples: INTEGER
			-- Window length in samples.

	count: INTEGER
			-- Number of words heard.
		do
			Result := word_list.count
		end

	word (a_index: INTEGER): PT_HEARD_WORD
			-- Word at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= count
		do
			Result := word_list [a_index]
		end

	is_empty: BOOLEAN
			-- Was nothing heard?
		do
			Result := count = 0
		end

	window_end: INTEGER_64
			-- One past the last sample of the window.
		do
			Result := window_start + window_samples
		ensure
			after_start: Result > window_start
		end

feature -- Model

	normalized_model: MML_SEQUENCE [STRING_32]
			-- Normalized heard words, in order.
		do
			create Result
			across word_list as ic loop
				Result := Result & ic.normalized
			end
		ensure
			same_count: Result.count = count
		end

feature {NONE} -- Implementation

	word_list: ARRAYED_LIST [PT_HEARD_WORD]

invariant
	start_non_negative: window_start >= 0
	window_positive: window_samples > 0

end
