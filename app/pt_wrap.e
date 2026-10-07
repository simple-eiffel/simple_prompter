note
	description: "[
		Word wrap for the control window: splits text into lines no wider than a width,
		measured with the painter's current font, so long notes (a session path, a speech
		status) wrap inside their column instead of running into the next (Larry, 2026-10-07).
		A single word wider than the column is broken by characters.
	]"
	author: "Larry Rix"

class
	PT_WRAP

feature -- Wrapping

	lines (p: SW_PAINTER; a_text: READABLE_STRING_32; a_width: REAL_64): ARRAYED_LIST [STRING_32]
			-- `a_text' as lines no wider than `a_width' in `p''s current font.
		require
			width_positive: a_width > 0
		local
			l_line, l_try: STRING_32
		do
			create Result.make (2)
			create l_line.make_empty
			across a_text.to_string_32.split (' ') as ic loop
				if not ic.is_empty then
					if l_line.is_empty then
						l_try := ic.twin
					else
						l_try := l_line + {STRING_32} " " + ic
					end
					if p.advance (l_try) <= a_width or l_line.is_empty and p.advance (ic) <= a_width then
						l_line := l_try
					else
						if not l_line.is_empty then
							Result.extend (l_line)
						end
						l_line := broken (p, ic, a_width, Result)
					end
				end
			end
			if not l_line.is_empty or Result.is_empty then
				Result.extend (l_line)
			end
		ensure
			at_least_one: not Result.is_empty
		end

feature {NONE} -- Implementation

	broken (p: SW_PAINTER; a_word: STRING_32; a_width: REAL_64; a_lines: ARRAYED_LIST [STRING_32]): STRING_32
			-- Put the full-width pieces of `a_word' into `a_lines'; answer the rest.
		local
			i: INTEGER
		do
			create Result.make_empty
			from i := 1 until i > a_word.count loop
				if not Result.is_empty and then p.advance (Result + a_word.substring (i, i)) > a_width then
					a_lines.extend (Result)
					create Result.make_empty
				end
				Result.append_character (a_word [i])
				i := i + 1
			end
		end

end
