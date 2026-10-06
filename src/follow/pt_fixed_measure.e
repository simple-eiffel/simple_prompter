note
	description: "Monospace measure with a fixed character width: deterministic layout for tests."
	author: "Larry Rix"

class
	PT_FIXED_MEASURE

inherit
	PT_TEXT_MEASURE

create
	make

feature {NONE} -- Initialization

	make (a_char_width, a_line_height: REAL_64)
			-- Every character is `a_char_width' wide; lines are `a_line_height' apart.
		require
			width_positive: a_char_width > 0
			height_positive: a_line_height > 0
		do
			char_width := a_char_width
			line_height := a_line_height
		ensure
			width_set: char_width = a_char_width
			height_set: line_height = a_line_height
		end

feature -- Access

	char_width: REAL_64

feature -- Measurement

	advance (a_text: READABLE_STRING_32): REAL_64
			-- `char_width' per character.
		do
			Result := a_text.count * char_width
		ensure then
			fixed: Result = a_text.count * char_width
		end

	space_advance: REAL_64
			-- One character.
		do
			Result := char_width
		end

	line_height: REAL_64
			-- Distance between baselines.

invariant
	width_positive: char_width > 0
	height_positive: line_height > 0

end
