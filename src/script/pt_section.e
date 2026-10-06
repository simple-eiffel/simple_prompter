note
	description: "A headed part of the script (from a Markdown heading); used for chapters and jump-to-section."
	author: "Larry Rix"

class
	PT_SECTION

create
	make

feature {NONE} -- Initialization

	make (a_index: INTEGER; a_heading: READABLE_STRING_32; a_first_word: INTEGER)
			-- Section `a_index' titled `a_heading' starting at word `a_first_word'.
		require
			index_positive: a_index >= 1
			heading_present: not a_heading.is_empty
			first_positive: a_first_word >= 1
		do
			index := a_index
			create heading.make_from_string (a_heading)
			first_word := a_first_word
		ensure
			index_set: index = a_index
			heading_set: heading.same_string (a_heading)
			first_set: first_word = a_first_word
		end

feature -- Access

	index: INTEGER
			-- Position among the revision's sections.

	heading: STRING_32
			-- Heading text without the leading '#' marks.

	first_word: INTEGER
			-- First word index of the section.

invariant
	index_positive: index >= 1
	heading_present: not heading.is_empty
	first_positive: first_word >= 1

end
