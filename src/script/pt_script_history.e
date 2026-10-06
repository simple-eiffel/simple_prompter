note
	description: "[
		The chain of script revisions in a session. `apply_edit' makes revision
		n+1 from revision n. Words outside the edited range keep their ids, and
		inside the range an LCS on normalized forms keeps the ids of words the
		edit left alone (spec 03 A-108). Older revisions never change (DR-002, DR-003).
	]"
	author: "Larry Rix"

class
	PT_SCRIPT_HISTORY

create
	make

feature {NONE} -- Initialization

	make (a_ids: PT_ID_SOURCE; a_parser: PT_SCRIPT_PARSER)
			-- Empty history issuing ids from `a_ids' and tokenizing edits with `a_parser'.
		do
			ids := a_ids
			parser := a_parser
			create revision_list.make (4)
		ensure
			empty: revision_count = 0
			ids_set: ids = a_ids
			parser_set: parser = a_parser
		end

feature -- Access

	ids: PT_ID_SOURCE
			-- Id source shared with the parser for this session.

	parser: PT_SCRIPT_PARSER
			-- Parser used to tokenize replacement text.

	revision_count: INTEGER
			-- Number of revisions.
		do
			Result := revision_list.count
		end

	current_revision: PT_SCRIPT_REVISION
			-- Latest revision.
		require
			has_revision: revision_count >= 1
		do
			Result := revision_list.last
		end

	revision (a_number: INTEGER): PT_SCRIPT_REVISION
			-- Revision `a_number'.
		require
			valid: a_number >= 1 and a_number <= revision_count
		do
			Result := revision_list [a_number]
		ensure
			numbered: Result.number = a_number
		end

feature -- Model

	revisions_model: MML_SEQUENCE [PT_SCRIPT_REVISION]
			-- Revisions in order.
		do
			create Result
			across revision_list as ic loop
				Result := Result & ic
			end
		ensure
			same_count: Result.count = revision_count
		end

feature -- Element change

	start (a_first: PT_SCRIPT_REVISION)
			-- Begin the history with `a_first'.
		require
			empty: revision_count = 0
			first_numbered: a_first.number = 1
		do
			revision_list.extend (a_first)
		ensure
			one: revision_count = 1
			current_is_first: current_revision = a_first
		end

	apply_edit (a_first, a_last: INTEGER; a_new_text: READABLE_STRING_32)
			-- Replace words `a_first'..`a_last' of the current revision with `a_new_text'
			-- (`a_first' = `a_last' + 1 inserts; empty text strikes).
		require
			has_revision: revision_count >= 1
			range_low: a_first >= 1
			range_high: a_last <= current_revision.word_count
			range_ordered: a_first <= a_last + 1
		local
			l_old, l_parsed: PT_SCRIPT_REVISION
			l_source, l_prefix, l_suffix: STRING_32
			l_cut_from, l_cut_to, l_prefix_count, l_suffix_count, l_middle, i, j: INTEGER
			l_ids: ARRAYED_LIST [PT_WORD_ID]
			l_match: SPECIAL [INTEGER]
			l_words: ARRAYED_LIST [PT_WORD]
			l_w: PT_WORD
		do
			l_old := current_revision
				-- Splice the replacement into the source text by character span.
			if a_first <= a_last then
				l_cut_from := l_old.word (a_first).char_start
				l_cut_to := l_old.word (a_last).char_end
			elseif a_first <= l_old.word_count then
				l_cut_from := l_old.word (a_first).char_start
				l_cut_to := l_cut_from - 1
			else
				l_cut_from := l_old.source_text.count + 1
				l_cut_to := l_old.source_text.count
			end
			l_prefix := l_old.source_text.substring (1, l_cut_from - 1)
			l_suffix := l_old.source_text.substring (l_cut_to + 1, l_old.source_text.count)
			create l_source.make (l_prefix.count + a_new_text.count + l_suffix.count + 2)
			l_source.append (l_prefix)
			if not l_prefix.is_empty and then not l_prefix [l_prefix.count].is_space and not a_new_text.is_empty then
				l_source.append_character (' ')
			end
			l_source.append (a_new_text)
			if not l_suffix.is_empty and then not l_suffix [1].is_space and not a_new_text.is_empty then
				l_source.append_character (' ')
			end
			l_source.append (l_suffix)
				-- Re-parse the whole text with throwaway ids, then assign the real ones.
			parser.parse (l_old.title, l_source, l_old.number + 1, create {PT_ID_SOURCE}.make_after (ids.last_issued))
			l_parsed := parser.last_revision
			l_prefix_count := a_first - 1
			l_suffix_count := l_old.word_count - a_last
			l_middle := l_parsed.word_count - l_prefix_count - l_suffix_count
			create l_ids.make (l_parsed.word_count)
			from i := 1 until i > l_prefix_count loop
				l_ids.extend (l_old.word (i).id)
				i := i + 1
			end
			l_match := lcs_match (l_old, a_first, a_last, l_parsed, l_prefix_count + 1, l_prefix_count + l_middle.max (0))
			from i := 1 until i > l_middle loop
				j := l_match [i - 1]
				if j > 0 then
					l_ids.extend (l_old.word (j).id)
				else
					ids.issue
					l_ids.extend (ids.last_id)
				end
				i := i + 1
			end
			from i := a_last + 1 until i > l_old.word_count loop
				l_ids.extend (l_old.word (i).id)
				i := i + 1
			end
			create l_words.make (l_parsed.word_count)
			from i := 1 until i > l_parsed.word_count loop
				l_w := l_parsed.word (i)
				l_words.extend (create {PT_WORD}.make (l_ids [i], l_w.text, l_w.normalized, l_w.char_start, l_w.char_end,
					l_w.passage_index, l_w.paragraph_index, l_w.section_index, l_w.is_stop_word, l_w.is_cue, l_w.is_heading))
				i := i + 1
			end
			revision_list.extend (create {PT_SCRIPT_REVISION}.make (l_old.number + 1, l_old.title, l_source, l_words,
				passages_of (l_parsed), sections_of (l_parsed)))
		ensure
			one_more: revision_count = old revision_count + 1
			numbered: current_revision.number = old current_revision.number + 1
			history_kept: (revisions_model.front (old revision_count) |=| old revisions_model)
			prefix_ids_kept: (current_revision.ids_model.front (a_first - 1)
					|=| (old current_revision.ids_model).front (a_first - 1))
			suffix_ids_kept: (current_revision.ids_model.tail (current_revision.word_count - (old current_revision.word_count - a_last) + 1)
					|=| (old current_revision.ids_model).tail (a_last + 1))
			ids_unique: current_revision.ids_model.range.count = current_revision.word_count
		end

feature {NONE} -- Implementation

	revision_list: ARRAYED_LIST [PT_SCRIPT_REVISION]

	lcs_match (a_old: PT_SCRIPT_REVISION; a_old_first, a_old_last: INTEGER;
			a_new: PT_SCRIPT_REVISION; a_new_first, a_new_last: INTEGER): SPECIAL [INTEGER]
			-- For each new word a_new_first..a_new_last (0-based slot), the old word index it keeps, or 0.
		local
			l_n, l_m, i, j: INTEGER
			l_table: ARRAY2 [INTEGER]
		do
			l_n := (a_old_last - a_old_first + 1).max (0)
			l_m := (a_new_last - a_new_first + 1).max (0)
			create Result.make_filled (0, l_m.max (1))
			if l_n > 0 and l_m > 0 then
				create l_table.make_filled (0, l_n + 1, l_m + 1)
				from i := l_n until i < 1 loop
					from j := l_m until j < 1 loop
						if a_old.word (a_old_first + i - 1).normalized.same_string (a_new.word (a_new_first + j - 1).normalized) then
							l_table [i, j] := l_table [i + 1, j + 1] + 1
						else
							l_table [i, j] := l_table [i + 1, j].max (l_table [i, j + 1])
						end
						j := j - 1
					end
					i := i - 1
				end
				from i := 1; j := 1 until i > l_n or j > l_m loop
					if a_old.word (a_old_first + i - 1).normalized.same_string (a_new.word (a_new_first + j - 1).normalized) then
						Result [j - 1] := a_old_first + i - 1
						i := i + 1
						j := j + 1
					elseif l_table [i + 1, j] >= l_table [i, j + 1] then
						i := i + 1
					else
						j := j + 1
					end
				end
			end
		end

	passages_of (a_revision: PT_SCRIPT_REVISION): ARRAYED_LIST [PT_PASSAGE]
		local
			i: INTEGER
		do
			create Result.make (a_revision.passage_count)
			from i := 1 until i > a_revision.passage_count loop
				Result.extend (a_revision.passage (i))
				i := i + 1
			end
		end

	sections_of (a_revision: PT_SCRIPT_REVISION): ARRAYED_LIST [PT_SECTION]
		local
			i: INTEGER
		do
			create Result.make (a_revision.section_count)
			from i := 1 until i > a_revision.section_count loop
				Result.extend (a_revision.section (i))
				i := i + 1
			end
		end

invariant
	current_consistent: revision_count >= 1 implies current_revision.number = revision_count

end
