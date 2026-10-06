note
	description: "[
		Wraps a revision's words into display lines for a column width (greedy
		wrap, as simple_speed_reader's SR_CONTEXT_VIEW does, but cached), and maps
		fractional word positions to vertical pixel offsets for smooth scrolling.
	]"
	author: "Larry Rix"

class
	PT_LAYOUT

create
	make

feature {NONE} -- Initialization

	make
			-- Empty layout.
		do
			create line_list.make (0)
		ensure
			empty: line_count = 0 and word_count = 0
		end

feature -- Access

	word_count: INTEGER
			-- Words laid out.

	width: REAL_64
			-- Column width used by the last `build'.

	line_height: REAL_64
			-- Line pitch used by the last `build'.

	line_count: INTEGER
		do
			Result := line_list.count
		end

	line (a_index: INTEGER): PT_LINE
		require
			valid_index: a_index >= 1 and a_index <= line_count
		do
			Result := line_list [a_index]
		end

	line_of (a_word: INTEGER): INTEGER
			-- Line containing word `a_word'.
		require
			valid: a_word >= 1 and a_word <= word_count
		local
			i: INTEGER
		do
			from i := 1 until Result > 0 or i > line_list.count loop
				if line_list [i].contains (a_word) then
					Result := i
				end
				i := i + 1
			end
		ensure
			contains: line (Result).contains (a_word)
		end

	y_of (a_position: REAL_64): REAL_64
			-- Vertical offset that puts fractional word position `a_position' on the reading line.
		require
			in_range: a_position >= 0 and a_position <= word_count
		local
			l_word, l_line: INTEGER
			l_progress: REAL_64
		do
			if word_count > 0 and line_count > 0 then
				l_word := (a_position.floor + 1).min (word_count)
				l_line := line_of (l_word)
				l_progress := ((a_position - (line (l_line).first_word - 1)) / line (l_line).word_count).max (0.0).min (1.0)
				Result := line (l_line).y + l_progress * line_height
			end
		ensure
			non_negative: Result >= 0
		end

feature -- Model

	line_starts_model: MML_SEQUENCE [INTEGER]
			-- First word of every line.
		do
			create Result
			across line_list as ic loop
				Result := Result & ic.first_word
			end
		ensure
			same_count: Result.count = line_count
		end

feature -- Element change

	build (a_revision: PT_SCRIPT_REVISION; a_measure: PT_TEXT_MEASURE; a_width: REAL_64)
			-- Lay out `a_revision' in a column `a_width' pixels wide.
		require
			positive_width: a_width > 0
		do
			line_list.wipe_out
			word_count := a_revision.word_count
			width := a_width
			line_height := a_measure.line_height
			wrap (a_revision, a_measure, a_width)
		ensure
			counted: word_count = a_revision.word_count
			covers: word_count > 0 implies
				(line_count > 0 and then (line (1).first_word = 1 and line (line_count).last_word = word_count))
			contiguous: across 2 |..| line_count as i all line (i).first_word = line (i - 1).last_word + 1 end
			fits_or_single: across 1 |..| line_count as i all
					line (i).width <= a_width or line (i).first_word = line (i).last_word end
		end

feature {NONE} -- Implementation

	line_list: ARRAYED_LIST [PT_LINE]

	wrap (a_revision: PT_SCRIPT_REVISION; a_measure: PT_TEXT_MEASURE; a_width: REAL_64)
			-- Greedy wrap; a paragraph break starts a new line.
		local
			i, l_first: INTEGER
			l_line_width, l_word_width, l_space: REAL_64
		do
			l_space := a_measure.space_advance
			from i := 1 until i > a_revision.word_count loop
				l_word_width := a_measure.advance (a_revision.word (i).text)
				if l_first = 0 then
					l_first := i
					l_line_width := l_word_width
				elseif a_revision.word (i).paragraph_index /= a_revision.word (i - 1).paragraph_index
					or l_line_width + l_space + l_word_width > a_width then
					line_list.extend (create {PT_LINE}.make (l_first, i - 1, l_line_width, line_list.count * line_height))
					l_first := i
					l_line_width := l_word_width
				else
					l_line_width := l_line_width + l_space + l_word_width
				end
				i := i + 1
			end
			if l_first > 0 then
				line_list.extend (create {PT_LINE}.make (l_first, a_revision.word_count, l_line_width, line_list.count * line_height))
			end
		end

invariant
	lines_fit_words: line_count <= word_count
	empty_consistent: word_count = 0 implies line_count = 0

end
