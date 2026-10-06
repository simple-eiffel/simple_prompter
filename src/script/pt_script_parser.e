note
	description: "[
		Turns script text (.txt, or .md already converted to plain text) into a
		PT_SCRIPT_REVISION: words with fresh ids, passages (sentences), sections
		(headings), cue marking ([CUE: ...] text is shown but never spoken) and
		stop-word flags.

		Phase 4 delegates tokenizing and sentence/paragraph/section marking to
		simple_text_structure (extracted from simple_speed_reader's SR_TOKENIZER)
		and Markdown stripping to SIMPLE_MARKDOWN.to_plain_text (spec 09 Q2, Q3).
	]"
	author: "Larry Rix"

class
	PT_SCRIPT_PARSER

create
	make

feature {NONE} -- Initialization

	make
			-- Parser with default stop words and normalizer.
		do
			create stop_words
			create normalizer
			last_revision := empty_revision ({STRING_32} "untitled", 1)
		ensure
			nothing_parsed: not has_parsed
		end

feature -- Access

	last_revision: PT_SCRIPT_REVISION
			-- Result of the last `parse' (an empty placeholder before the first).

	has_parsed: BOOLEAN
			-- Has `parse' run at least once?

	stop_words: PT_STOP_WORDS
	normalizer: PT_NORMALIZER

feature -- Basic operations

	parse (a_title, a_text: READABLE_STRING_32; a_number: INTEGER; a_ids: PT_ID_SOURCE)
			-- Parse `a_text' as revision `a_number', issuing ids from `a_ids'.
		require
			number_positive: a_number >= 1
		local
			l_words: ARRAYED_LIST [PT_WORD]
			l_passages: ARRAYED_LIST [PT_PASSAGE]
			l_sections: ARRAYED_LIST [PT_SECTION]
			l_lines: LIST [READABLE_STRING_32]
			l_line, l_token, l_text, l_norm, l_heading, l_trim: STRING_32
			l_offset, l_paragraph, l_section, l_first, l_pos, l_start: INTEGER
			l_heading_line, l_in_cue, l_cue_word, l_new_paragraph, l_ends: BOOLEAN
		do
			create l_words.make (64)
			create l_heading.make_empty
			create l_passages.make (16)
			create l_sections.make (4)
			l_paragraph := 1
			l_lines := a_text.split ('%N')
			l_offset := 0
			across l_lines as ic_line loop
				create l_line.make_from_string (ic_line)
				l_line.prune_all ('%R')
				if is_blank (l_line) then
					l_new_paragraph := True
				else
					l_trim := l_line.twin
					l_trim.left_adjust
					l_heading_line := l_trim.starts_with ({STRING_32} "#")
					if l_heading_line or l_new_paragraph then
						close_passage (l_words, l_passages, l_first, l_paragraph, l_section)
						l_first := 0
						if not l_words.is_empty then
							l_paragraph := l_paragraph + 1
						end
						l_new_paragraph := False
					end
					if l_heading_line then
						l_heading := heading_text (l_line)
						if not l_heading.is_empty then
							l_section := l_section + 1
						end
					end
						-- Tokens: maximal runs of non-blank characters.
					from l_pos := 1 until l_pos > l_line.count loop
						if l_line [l_pos].is_space then
							l_pos := l_pos + 1
						else
							l_start := l_pos
							from until l_pos > l_line.count or else l_line [l_pos].is_space loop
								l_pos := l_pos + 1
							end
							l_token := l_line.substring (l_start, l_pos - 1)
							l_cue_word := l_in_cue
							if l_token.as_upper.starts_with ({STRING_32} "[CUE") then
								l_in_cue := True
								l_cue_word := True
							end
							l_ends := False
							if l_cue_word and l_token.has (']') then
								l_in_cue := False
								l_ends := True
							end
							l_text := stripped_markup (l_token)
							l_norm := normalizer.normalized (l_text)
							if not l_text.is_empty and not l_norm.is_empty and l_norm.count <= l_text.count then
								if l_first = 0 then
									l_first := l_words.count + 1
								end
								a_ids.issue
								l_words.extend (create {PT_WORD}.make (a_ids.last_id, l_text, l_norm,
									l_offset + l_start, l_offset + l_pos - 1, l_passages.count + 1, l_paragraph, l_section,
									stop_words.has (l_norm), l_cue_word, l_heading_line and not l_cue_word))
								if l_heading_line and l_section > l_sections.count then
									l_sections.extend (create {PT_SECTION}.make (l_section, l_heading, l_words.count))
								end
							end
							if l_ends or (not l_cue_word and ends_sentence (l_token)) then
								close_passage (l_words, l_passages, l_first, l_paragraph, l_section)
								l_first := 0
							end
						end
					end
					if l_heading_line then
						close_passage (l_words, l_passages, l_first, l_paragraph, l_section)
						l_first := 0
						l_new_paragraph := True
					end
				end
				l_offset := l_offset + ic_line.count + 1
			end
			close_passage (l_words, l_passages, l_first, l_paragraph, l_section)
			create last_revision.make (a_number, a_title, a_text, l_words, l_passages, l_sections)
			has_parsed := True
		ensure
			parsed: has_parsed
			numbered: last_revision.number = a_number
			ids_unique: last_revision.ids_model.range.count = last_revision.word_count
			ids_fresh: across 1 |..| last_revision.word_count as i all
					last_revision.word (i).id.value > old a_ids.last_issued end
			ids_consumed: a_ids.last_issued = old a_ids.last_issued + last_revision.word_count
			words_found: has_words (a_text) implies last_revision.word_count > 0
			optional_not_required: across 1 |..| last_revision.word_count as i all
					not last_revision.word (i).is_required implies not last_revision.spoken_ids_model.has (last_revision.word (i).id) end
			headings_flagged: across 1 |..| last_revision.section_count as i all
					last_revision.word (last_revision.section (i).first_word).is_heading end
		end

feature -- Classification

	Abbreviations: ARRAY [STRING_32]
			-- Single-period abbreviations that do not end a sentence (lowercase, with the period).
		once
			Result := << {STRING_32} "dr.", {STRING_32} "mr.", {STRING_32} "mrs.", {STRING_32} "ms.",
				{STRING_32} "st.", {STRING_32} "vs.", {STRING_32} "etc.", {STRING_32} "prof.",
				{STRING_32} "jr.", {STRING_32} "sr.", {STRING_32} "no." >>
		end

	ends_sentence (a_token: READABLE_STRING_32): BOOLEAN
			-- Does `a_token' end a sentence (. ! ? or the ellipsis, ignoring closing quotes and
			-- brackets), unless it is an abbreviation ("Dr.", "e.g.", "U.S.")?
		local
			l_core: STRING_32
			l_last: CHARACTER_32
		do
			create l_core.make_from_string (a_token)
			from until l_core.is_empty or else not closing_marks.has (l_core [l_core.count]) loop
				l_core.remove_tail (1)
			end
			if not l_core.is_empty then
				l_last := l_core [l_core.count]
				if l_last = '!' or l_last = '?' or l_last = '%/8230/' then
					Result := True
				elseif l_last = '.' then
					Result := not is_abbreviation (l_core)
				end
			end
		end

	is_abbreviation (a_core: READABLE_STRING_32): BOOLEAN
			-- Is `a_core' (ending in '.') an abbreviation: an inner period ("e.g.", "U.S.") or a known title?
		local
			l_lower: STRING_32
		do
			l_lower := a_core.as_lower
			Result := across Abbreviations as ic some l_lower.same_string (ic) end
			if not Result and a_core.count >= 3 then
				Result := a_core.substring (1, a_core.count - 1).has ('.') and then
					a_core [a_core.count - 1].is_alpha and then not a_core.ends_with ({STRING_32} "...")
			end
		end

feature {NONE} -- Implementation

	closing_marks: STRING_32
			-- Characters skipped at a token end before testing for a sentence end.
		once
			Result := {STRING_32} "%"')]}*_%/8221/%/8217/%/187/"
		end

	is_blank (a_line: READABLE_STRING_32): BOOLEAN
		do
			Result := across a_line as ic all ic.is_space end
		end

	heading_text (a_line: READABLE_STRING_32): STRING_32
			-- `a_line' without its leading '#' marks and markup.
		local
			i: INTEGER
		do
			create Result.make_from_string (a_line)
			Result.left_adjust
			from i := 1 until i > Result.count or else Result [i] /= '#' loop
				i := i + 1
			end
			Result := Result.substring (i, Result.count)
			Result.left_adjust
			Result.right_adjust
			Result.prune_all ('*')
		end

	stripped_markup (a_token: READABLE_STRING_32): STRING_32
			-- `a_token' without Markdown emphasis, heading marks, link targets and cue brackets.
		local
			l_link: INTEGER
		do
			create Result.make_from_string (a_token)
			l_link := Result.substring_index ({STRING_32} "](", 1)
			if l_link > 0 then
				Result := Result.substring (1, l_link - 1)
			end
			Result.prune_all ('*')
			Result.prune_all ('`')
			Result.prune_all ('#')
			if Result.as_upper.starts_with ({STRING_32} "[CUE") then
				Result.remove_head (1)
			end
			Result.prune_all ('[')
			Result.prune_all (']')
			from until Result.is_empty or else Result [1] /= '_' loop
				Result.remove_head (1)
			end
			from until Result.is_empty or else Result [Result.count] /= '_' loop
				Result.remove_tail (1)
			end
		end

	close_passage (a_words: ARRAYED_LIST [PT_WORD]; a_passages: ARRAYED_LIST [PT_PASSAGE];
			a_first, a_paragraph, a_section: INTEGER)
			-- Close the open passage (words `a_first'.. last) if it has words.
		do
			if a_first > 0 and a_first <= a_words.count then
				a_passages.extend (create {PT_PASSAGE}.make (a_passages.count + 1, a_first, a_words.count,
					a_words [a_first].paragraph_index, a_words [a_first].section_index))
			end
		end

	empty_revision (a_title: READABLE_STRING_32; a_number: INTEGER): PT_SCRIPT_REVISION
			-- A revision with no words.
		require
			number_positive: a_number >= 1
		do
			create Result.make (a_number, a_title, {STRING_32} "",
				create {ARRAYED_LIST [PT_WORD]}.make (0),
				create {ARRAYED_LIST [PT_PASSAGE]}.make (0),
				create {ARRAYED_LIST [PT_SECTION]}.make (0))
		ensure
			empty: Result.word_count = 0
		end

feature -- Status

	has_words (a_text: READABLE_STRING_32): BOOLEAN
			-- Does `a_text' contain at least one non-whitespace character?
		do
			Result := across a_text as ic some not ic.is_space end
		end

end
