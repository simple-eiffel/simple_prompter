note
	description: "A passage (sentence by default): the unit for restarts and take selection."
	author: "Larry Rix"

class
	PT_PASSAGE

create
	make

feature {NONE} -- Initialization

	make (a_index, a_first_word, a_last_word, a_paragraph, a_section: INTEGER)
			-- Passage `a_index' covering words `a_first_word'..`a_last_word'.
		require
			index_positive: a_index >= 1
			first_positive: a_first_word >= 1
			ordered: a_first_word <= a_last_word
			paragraph_positive: a_paragraph >= 1
			section_non_negative: a_section >= 0
		do
			index := a_index
			first_word := a_first_word
			last_word := a_last_word
			paragraph_index := a_paragraph
			section_index := a_section
		ensure
			index_set: index = a_index
			span_set: first_word = a_first_word and last_word = a_last_word
			structure_set: paragraph_index = a_paragraph and section_index = a_section
		end

feature -- Access

	index: INTEGER
			-- Position among the revision's passages.

	first_word, last_word: INTEGER
			-- Word index span (inclusive).

	paragraph_index, section_index: INTEGER
			-- Enclosing paragraph and section.

	word_count: INTEGER
			-- Number of words in the passage.
		do
			Result := last_word - first_word + 1
		ensure
			definition: Result = last_word - first_word + 1
		end

	contains (a_word: INTEGER): BOOLEAN
			-- Is word index `a_word' inside this passage?
		do
			Result := first_word <= a_word and a_word <= last_word
		ensure
			definition: Result = (first_word <= a_word and a_word <= last_word)
		end

invariant
	index_positive: index >= 1
	first_positive: first_word >= 1
	ordered: first_word <= last_word
	paragraph_positive: paragraph_index >= 1
	section_non_negative: section_index >= 0

end
