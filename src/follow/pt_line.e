note
	description: "One display line of the prompter column: a contiguous word span with its width and top."
	author: "Larry Rix"

class
	PT_LINE

create
	make

feature {NONE} -- Initialization

	make (a_first_word, a_last_word: INTEGER; a_width, a_y: REAL_64)
			-- Line holding words `a_first_word'..`a_last_word'.
		require
			first_positive: a_first_word >= 1
			ordered: a_first_word <= a_last_word
			width_non_negative: a_width >= 0
			y_non_negative: a_y >= 0
		do
			first_word := a_first_word
			last_word := a_last_word
			width := a_width
			y := a_y
		ensure
			span_set: first_word = a_first_word and last_word = a_last_word
			width_set: width = a_width
			y_set: y = a_y
		end

feature -- Access

	first_word, last_word: INTEGER
	width: REAL_64
			-- Rendered width in pixels.
	y: REAL_64
			-- Top of the line in the column, pixels.

	word_count: INTEGER
		do
			Result := last_word - first_word + 1
		end

	contains (a_word: INTEGER): BOOLEAN
		do
			Result := first_word <= a_word and a_word <= last_word
		end

invariant
	first_positive: first_word >= 1
	ordered: first_word <= last_word
	width_non_negative: width >= 0
	y_non_negative: y >= 0

end
