note
	description: "[
		A script's prose for publishing (0.5.0): its title (the first # line) and its
		paragraphs, with stage cues ([CUE: ...]) and other headings left out, and the
		sentences and words of any text. The Publish step builds chapters, descriptions and
		captions from it.
	]"
	author: "Larry Rix"

class
	PT_SCRIPT_TEXT

create
	make

feature {NONE} -- Initialization

	make (a_markdown: READABLE_STRING_32)
			-- Read `a_markdown' (the script as written).
		local
			l_line, l_paragraph: STRING_32
		do
			create title.make_empty
			create paragraphs.make (16)
			create l_paragraph.make_empty
			across a_markdown.split ('%N') as ic loop
				l_line := ic.twin
				l_line.prune_all ('%R')
				l_line.left_adjust
				l_line.right_adjust
				if l_line.starts_with ({STRING_32} "# ") then
					if title.is_empty then
						title := l_line.substring (3, l_line.count)
						title.left_adjust
					end
					flush (l_paragraph)
				elseif l_line.is_empty or l_line.starts_with ({STRING_32} "#") or (l_line.starts_with ({STRING_32} "[") and l_line.ends_with ({STRING_32} "]")) then
					flush (l_paragraph)
				else
					if not l_paragraph.is_empty then
						l_paragraph.append_character (' ')
					end
					l_paragraph.append (l_line)
				end
			end
			flush (l_paragraph)
		end

feature -- Access

	title: STRING_32
			-- The # line's text, or empty.

	paragraphs: ARRAYED_LIST [STRING_32]
			-- The spoken paragraphs, in order, each on one line.

	sentences: ARRAYED_LIST [STRING_32]
			-- Every sentence of every paragraph, in order.
		do
			create Result.make (64)
			across paragraphs as ic loop
				Result.append (sentences_of (ic))
			end
		end

feature -- Text

	sentences_of (a_text: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- `a_text' cut after each word that ends a sentence (. ? !, closing quotes allowed).
		local
			l_sentence: STRING_32
		do
			create Result.make (8)
			create l_sentence.make_empty
			across words_of (a_text) as ic loop
				if not l_sentence.is_empty then
					l_sentence.append_character (' ')
				end
				l_sentence.append (ic)
				if ends_sentence (ic) then
					Result.extend (l_sentence)
					create l_sentence.make_empty
				end
			end
			if not l_sentence.is_empty then
				Result.extend (l_sentence)
			end
		ensure
			no_empty: across Result as ic all not ic.is_empty end
		end

	words_of (a_text: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- The space-separated words of `a_text'.
		do
			create Result.make (32)
			across a_text.split (' ') as ic loop
				if not ic.is_empty then
					Result.extend (ic.twin)
				end
			end
		ensure
			no_empty: across Result as ic all not ic.is_empty end
		end

	ends_sentence (a_word: READABLE_STRING_32): BOOLEAN
			-- Does `a_word' end a sentence (. ? ! before any closing quotes)?
		local
			i: INTEGER
		do
			from i := a_word.count until i < 1 or else not is_closing_quote (a_word [i]) loop
				i := i - 1
			end
			Result := i >= 1 and then (a_word [i] = '.' or a_word [i] = '?' or a_word [i] = '!')
		end

	is_closing_quote (c: CHARACTER_32): BOOLEAN
		do
			Result := c = '"' or c = '%'' or c = '%/8221/' or c = '%/8217/' or c = ')'
		end

feature {NONE} -- Implementation

	flush (a_paragraph: STRING_32)
			-- End the paragraph being gathered, if any.
		do
			if not a_paragraph.is_empty then
				paragraphs.extend (a_paragraph.twin)
				a_paragraph.wipe_out
			end
		ensure
			emptied: a_paragraph.is_empty
		end

end
