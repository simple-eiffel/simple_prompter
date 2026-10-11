note
	description: "[
		The words on the pictures Publish makes (0.7.0): the thumbnails' lines, the word struck
		out on thumbnail A, the reel cover's title lines and its Bible reference.

		From the local AI's suggestions when it gave them, else from the script's title:
		  thumbnail A  the struck word (if any), then its lines in yellow;
		  thumbnail B  its lines in white, the last in yellow;
		  cover        the script's title, the last line in yellow, the reference under it.
		Lines are upper case and split into balanced lines (the longest as short as it can be).
	]"
	author: "Larry Rix"

class
	PT_PICTURE_WORDS

create
	make

feature {NONE} -- Initialization

	make (a_title: READABLE_STRING_32; a_suggestions: PT_PUBLISH_SUGGESTIONS)
			-- The words for a video titled `a_title' (the script's title), with `a_suggestions'.
		do
			title_lines := balanced (upper_case (a_title), Title_lines_max)
			if a_suggestions.thumbnail_a.is_empty then
				thumbnail_a_lines := title_lines.twin
			else
				thumbnail_a_lines := balanced (upper_case (a_suggestions.thumbnail_a), Thumbnail_lines_max)
			end
			if a_suggestions.thumbnail_b.is_empty then
				thumbnail_b_lines := title_lines.twin
			else
				thumbnail_b_lines := balanced (upper_case (a_suggestions.thumbnail_b), Thumbnail_lines_max)
			end
			struck := upper_case (a_suggestions.thumbnail_struck)
			bible_reference := upper_case (a_suggestions.bible_reference)
			from_ai := not a_suggestions.thumbnail_a.is_empty or not a_suggestions.thumbnail_b.is_empty
		ensure
			title_kept: not a_title.is_empty implies not title_lines.is_empty
		end

feature -- Constants

	Title_lines_max: INTEGER = 3
	Thumbnail_lines_max: INTEGER = 3

feature -- Access

	title_lines: ARRAYED_LIST [STRING_32]
			-- The cover's title, in lines.

	thumbnail_a_lines: ARRAYED_LIST [STRING_32]
			-- Thumbnail A's lines (yellow).

	thumbnail_b_lines: ARRAYED_LIST [STRING_32]
			-- Thumbnail B's lines (white, the last yellow).

	struck: STRING_32
			-- The word struck out above thumbnail A's lines (or empty).

	bible_reference: STRING_32
			-- The Bible reference under the cover's title (or empty).

	from_ai: BOOLEAN
			-- Did the thumbnail lines come from the local AI (else from the title)?

feature -- Splitting

	balanced (a_text: READABLE_STRING_32; a_max_lines: INTEGER): ARRAYED_LIST [STRING_32]
			-- `a_text''s words in at most `a_max_lines' lines, the longest line as short as it can be:
			-- one line up to 12 characters, else two, else (over 26) up to `a_max_lines'.
		require
			lines_positive: a_max_lines >= 1
		local
			l_words: LIST [STRING_32]
			l_count, l_best_width, i, j: INTEGER
			l_try: ARRAYED_LIST [STRING_32]
		do
			l_words := words_of (a_text)
			create Result.make (a_max_lines)
			if not l_words.is_empty then
				if a_text.count <= 12 or l_words.count = 1 then
					l_count := 1
				elseif a_text.count <= 26 then
					l_count := 2
				else
					l_count := a_max_lines
				end
				l_count := l_count.min (l_words.count).min (a_max_lines).min (3)
				if l_count = 1 then
					Result.extend (joined (l_words, 1, l_words.count))
				else
					-- Every split (titles are a few words): the longest line as short as it can be.
					l_best_width := {INTEGER}.max_value
					from i := 1 until i >= l_words.count loop
						if l_count = 2 then
							l_try := split (l_words, i, l_words.count)
							if widest (l_try) < l_best_width then
								l_best_width := widest (l_try)
								Result := l_try
							end
						else
							from j := i + 1 until j >= l_words.count loop
								l_try := split (l_words, i, j)
								if widest (l_try) < l_best_width then
									l_best_width := widest (l_try)
									Result := l_try
								end
								j := j + 1
							end
						end
						i := i + 1
					end
				end
			end
		ensure
			at_most: Result.count <= a_max_lines
		end

feature {NONE} -- Implementation

	split (a_words: LIST [STRING_32]; a_first_end, a_second_end: INTEGER): ARRAYED_LIST [STRING_32]
			-- Words 1..`a_first_end', then up to `a_second_end', then the rest (when any).
		do
			create Result.make (3)
			Result.extend (joined (a_words, 1, a_first_end))
			Result.extend (joined (a_words, a_first_end + 1, a_second_end))
			if a_second_end < a_words.count then
				Result.extend (joined (a_words, a_second_end + 1, a_words.count))
			end
		end

	joined (a_words: LIST [STRING_32]; a_from, a_to: INTEGER): STRING_32
			-- Words `a_from'..`a_to' with single spaces.
		local
			i: INTEGER
		do
			create Result.make_empty
			from i := a_from until i > a_to loop
				if not Result.is_empty then
					Result.append_character (' ')
				end
				Result.append (a_words [i])
				i := i + 1
			end
		end

	widest (a_lines: LIST [STRING_32]): INTEGER
		do
			across a_lines as ic loop
				Result := Result.max (ic.count)
			end
		end

	words_of (a_text: READABLE_STRING_32): LIST [STRING_32]
		do
			create {ARRAYED_LIST [STRING_32]} Result.make (8)
			across a_text.to_string_32.split (' ') as ic loop
				if not ic.is_empty then
					Result.extend (ic.twin)
				end
			end
		end

	upper_case (a_text: READABLE_STRING_32): STRING_32
		do
			Result := a_text.to_string_32.as_upper
			Result.left_adjust
			Result.right_adjust
		end

invariant
	lines_exist: title_lines /= Void and thumbnail_a_lines /= Void and thumbnail_b_lines /= Void

end
