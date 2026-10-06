note
	description: "[
		Where every word of a laid-out script sits inside the pill, and which
		word is under a point. Words are measured exactly as PT_LAYOUT wraps
		them (advance of the text, one space advance between words), so a
		click lands on the word that was drawn there. Pill coordinates: the
		text area starts `padding' in from the left and top; the reading row
		starts `reading_line' pixels below the top of the text area, and the
		scroll offset (PT_SCROLL_MODEL.y_offset) is the content y of the
		reading point, placed half a line down that row - so the line being
		read crosses the reading row centred halfway through it.
		Pure: the GUI's painting and hit testing are tested headless.
	]"
	author: "Larry Rix"

class
	PT_PILL_GEOMETRY

create
	make

feature {NONE} -- Initialization

	make (a_revision: PT_SCRIPT_REVISION; a_layout: PT_LAYOUT; a_measure: PT_TEXT_MEASURE; a_padding, a_reading_line: REAL_64)
			-- Geometry of `a_layout' (built from `a_revision' with `a_measure').
		require
			same_words: a_layout.word_count = a_revision.word_count
			padding_non_negative: a_padding >= 0
			reading_line_non_negative: a_reading_line >= 0
		local
			l_line, i: INTEGER
			l_x, l_space: REAL_64
		do
			layout := a_layout
			padding := a_padding
			reading_line := a_reading_line
			create x_list.make_filled (0.0, 1, a_revision.word_count.max (1))
			create width_list.make_filled (0.0, 1, a_revision.word_count.max (1))
			l_space := a_measure.space_advance
			from l_line := 1 until l_line > a_layout.line_count loop
				l_x := a_padding
				from i := a_layout.line (l_line).first_word until i > a_layout.line (l_line).last_word loop
					x_list [i] := l_x
					width_list [i] := a_measure.advance (a_revision.word (i).text)
					l_x := l_x + width_list [i] + l_space
					i := i + 1
				end
				l_line := l_line + 1
			end
		ensure
			layout_set: layout = a_layout
			padding_set: padding = a_padding
			reading_line_set: reading_line = a_reading_line
		end

feature -- Access

	layout: PT_LAYOUT
	padding: REAL_64
			-- Inset of the text area from the pill's left and top edges.
	reading_line: REAL_64
			-- Distance from the top of the text area to the reading point.

	word_x (a_word: INTEGER): REAL_64
			-- Left edge of word `a_word' in pill coordinates.
		require
			valid: a_word >= 1 and a_word <= layout.word_count
		do
			Result := x_list [a_word]
		ensure
			inset: Result >= padding
		end

	word_width (a_word: INTEGER): REAL_64
			-- Drawn width of word `a_word'.
		require
			valid: a_word >= 1 and a_word <= layout.word_count
		do
			Result := width_list [a_word]
		ensure
			non_negative: Result >= 0
		end

	line_top (a_line: INTEGER; a_offset: REAL_64): REAL_64
			-- Top of line `a_line' in pill coordinates when the content is scrolled to `a_offset'.
		require
			valid: a_line >= 1 and a_line <= layout.line_count
		do
			Result := padding + reading_line + layout.line_height / 2 + layout.line (a_line).y - a_offset
		ensure
			definition: Result = padding + reading_line + layout.line_height / 2 + layout.line (a_line).y - a_offset
		end

	word_at (a_x, a_y, a_offset: REAL_64): INTEGER
			-- Word under pill point (`a_x', `a_y') at scroll offset `a_offset', 0 if none.
		local
			l_line, i: INTEGER
			l_top: REAL_64
		do
			from l_line := 1 until Result > 0 or l_line > layout.line_count loop
				l_top := line_top (l_line, a_offset)
				if a_y >= l_top and a_y < l_top + layout.line_height then
					from i := layout.line (l_line).first_word until Result > 0 or i > layout.line (l_line).last_word loop
						if a_x >= x_list [i] and a_x < x_list [i] + width_list [i] then
							Result := i
						end
						i := i + 1
					end
					l_line := layout.line_count
				end
				l_line := l_line + 1
			end
		ensure
			in_script: Result >= 0 and Result <= layout.word_count
			inside_word: Result > 0 implies (a_x >= word_x (Result) and a_x < word_x (Result) + word_width (Result))
		end

	first_visible_line (a_offset: REAL_64): INTEGER
			-- First line whose box reaches below the pill's top edge (0 for an empty layout).
		local
			l_line: INTEGER
		do
			from l_line := 1 until Result > 0 or l_line > layout.line_count loop
				if line_top (l_line, a_offset) + layout.line_height > 0 then
					Result := l_line
				end
				l_line := l_line + 1
			end
		ensure
			in_range: Result >= 0 and Result <= layout.line_count
		end

	last_visible_line (a_offset, a_height: REAL_64): INTEGER
			-- Last line whose box starts above the pill's bottom edge `a_height' (0 if none).
		local
			l_line: INTEGER
		do
			from l_line := layout.line_count until Result > 0 or l_line < 1 loop
				if line_top (l_line, a_offset) < a_height then
					Result := l_line
				end
				l_line := l_line - 1
			end
		ensure
			in_range: Result >= 0 and Result <= layout.line_count
		end

feature {NONE} -- Implementation

	x_list, width_list: ARRAY [REAL_64]
			-- Per word, indexed by word.

invariant
	padding_non_negative: padding >= 0
	reading_line_non_negative: reading_line >= 0

end
