note
	description: "[
		Normal form for matching heard words to script words: lowercase,
		punctuation stripped, typographic quotes and dashes unified, digits kept.
	]"
	author: "Larry Rix"

class
	PT_NORMALIZER

feature -- Conversion

	normalized (a_text: READABLE_STRING_32): STRING_32
			-- Normal form of `a_text': lowercase letters and digits, plus an apostrophe
			-- between letters (don't, they're); typographic apostrophes count as an apostrophe.
		local
			i: INTEGER
			c: CHARACTER_32
		do
			create Result.make (a_text.count)
			from i := 1 until i > a_text.count loop
				c := a_text [i]
				if c = '%/8217/' or c = '%/8216/' or c = '%/700/' then
					c := '%''
				end
				if c.is_alpha or c.is_digit then
					Result.append_character (c.as_lower)
				elseif c = '%'' and then (not Result.is_empty and then Result [Result.count].is_alpha)
					and then (i < a_text.count and then a_text [i + 1].is_alpha) then
					Result.append_character (c)
				end
				i := i + 1
			end
		ensure
			not_longer: Result.count <= a_text.count
			no_upper: Result.same_string (Result.as_lower)
			no_spaces: not Result.has (' ')
		end

end
