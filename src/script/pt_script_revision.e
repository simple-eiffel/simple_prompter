note
	description: "[
		An immutable version of a script: ordered words, passages and sections.
		Created by PT_SCRIPT_PARSER and PT_SCRIPT_HISTORY; creation is also open
		to test fixtures, which may build revisions word by word. There are no
		commands, so a revision never changes once made (DR-002).
	]"
	author: "Larry Rix"

class
	PT_SCRIPT_REVISION

create
	make

feature {NONE} -- Initialization

	make (a_number: INTEGER; a_title, a_source: READABLE_STRING_32;
			a_words: ARRAYED_LIST [PT_WORD]; a_passages: ARRAYED_LIST [PT_PASSAGE];
			a_sections: ARRAYED_LIST [PT_SECTION])
			-- Revision `a_number' of script `a_title' with the given structure.
		require
			number_positive: a_number >= 1
			ids_unique: ids_are_unique (a_words)
			passages_partition: passages_partition (a_words.count, a_passages)
			sections_fit: a_sections.count <= a_passages.count
		local
			i: INTEGER
		do
			number := a_number
			create title.make_from_string (a_title)
			create source_text.make_from_string (a_source)
			create word_list.make_from_iterable (a_words)
			create passage_list.make_from_iterable (a_passages)
			create section_list.make_from_iterable (a_sections)
			create index_by_id.make (a_words.count.max (1))
			from i := 1 until i > word_list.count loop
				index_by_id.put (i, word_list [i].id.value)
				i := i + 1
			end
		ensure
			number_set: number = a_number
			title_set: title.same_string (a_title)
			counts_set: word_count = a_words.count and passage_count = a_passages.count and section_count = a_sections.count
		end

feature -- Access

	number: INTEGER
			-- Revision number (1 = as loaded).

	title: STRING_32
			-- Script title.

	source_text: STRING_32
			-- Plain text the words were taken from (char spans refer to it).

	word_count: INTEGER
			-- Number of words.
		do
			Result := word_list.count
		end

	passage_count: INTEGER
			-- Number of passages.
		do
			Result := passage_list.count
		end

	section_count: INTEGER
			-- Number of sections.
		do
			Result := section_list.count
		end

	word (a_index: INTEGER): PT_WORD
			-- Word at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= word_count
		do
			Result := word_list [a_index]
		end

	passage (a_index: INTEGER): PT_PASSAGE
			-- Passage at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= passage_count
		do
			Result := passage_list [a_index]
		end

	section (a_index: INTEGER): PT_SECTION
			-- Section at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= section_count
		do
			Result := section_list [a_index]
		end

	index_of (a_id: PT_WORD_ID): INTEGER
			-- Index of the word with id `a_id', or 0 if absent.
		do
			if index_by_id.has (a_id.value) then
				Result := index_by_id [a_id.value]
			end
		ensure
			zero_or_found: Result = 0 or else word (Result).id ~ a_id
			found_if_present: ids_model.has (a_id) implies Result > 0
		end

	passage_of (a_index: INTEGER): INTEGER
			-- Index of the passage containing word `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= word_count
		local
			i: INTEGER
		do
			from i := 1 until Result > 0 or i > passage_list.count loop
				if passage_list [i].contains (a_index) then
					Result := i
				end
				i := i + 1
			end
		ensure
			contains: passage (Result).contains (a_index)
		end

	text_of_range (a_first, a_last: INTEGER): STRING_32
			-- Words `a_first'..`a_last' joined by single spaces (empty when `a_first' > `a_last').
		require
			first_valid: a_first >= 1
			last_valid: a_last <= word_count
			ordered: a_first <= a_last + 1
		local
			i: INTEGER
		do
			create Result.make (32)
			from i := a_first until i > a_last loop
				if i > a_first then
					Result.append_character (' ')
				end
				Result.append (word_list [i].text)
				i := i + 1
			end
		ensure
			empty_range: a_first > a_last implies Result.is_empty
		end

feature -- Model

	ids_model: MML_SEQUENCE [PT_WORD_ID]
			-- Word ids in script order. Built once: a revision never changes after `make', and
			-- contracts that call this per word made a long script take 25 s to parse (2026-10-07).
		local
			l_ids: ARRAYED_LIST [PT_WORD_ID]
		do
			if attached ids_model_cache as al_cached then
				Result := al_cached
			else
				create l_ids.make (word_list.count)
				across word_list as ic loop
					l_ids.extend (ic.id)
				end
				create Result.from_iterable (l_ids)
				ids_model_cache := Result
			end
		ensure
			same_count: Result.count = word_count
		end

	spoken_ids_model: MML_SEQUENCE [PT_WORD_ID]
			-- Ids of words required in the final cut (cue and heading words excluded), in order.
			-- Built once, like `ids_model'.
		local
			l_ids: ARRAYED_LIST [PT_WORD_ID]
		do
			if attached spoken_ids_model_cache as al_cached then
				Result := al_cached
			else
				create l_ids.make (word_list.count)
				across word_list as ic loop
					if ic.is_required then
						l_ids.extend (ic.id)
					end
				end
				create Result.from_iterable (l_ids)
				spoken_ids_model_cache := Result
			end
		ensure
			not_longer: Result.count <= word_count
		end

	passage_bounds_model: MML_SEQUENCE [INTEGER]
			-- First word index of every passage, in order.
		do
			create Result
			across passage_list as ic loop
				Result := Result & ic.first_word
			end
		ensure
			same_count: Result.count = passage_count
		end

feature -- Validation (exported for preconditions)

	ids_are_unique (a_words: ARRAYED_LIST [PT_WORD]): BOOLEAN
			-- Are all ids in `a_words' distinct?
		local
			l_seen: HASH_TABLE [BOOLEAN, INTEGER_64]
		do
			create l_seen.make (a_words.count.max (1))
			Result := True
			across a_words as ic until not Result loop
				if l_seen.has (ic.id.value) then
					Result := False
				else
					l_seen.put (True, ic.id.value)
				end
			end
		end

	passages_partition (a_word_count: INTEGER; a_passages: ARRAYED_LIST [PT_PASSAGE]): BOOLEAN
			-- Do `a_passages' cover words 1..`a_word_count' contiguously, in order, indexed 1..n?
		local
			i: INTEGER
		do
			if a_word_count = 0 then
				Result := a_passages.is_empty
			elseif not a_passages.is_empty then
				Result := a_passages.first.first_word = 1 and a_passages.last.last_word = a_word_count
				from i := 1 until not Result or i > a_passages.count loop
					Result := a_passages [i].index = i and
						(i = 1 or else a_passages [i].first_word = a_passages [i - 1].last_word + 1)
					i := i + 1
				end
			end
		end

feature {NONE} -- Implementation

	word_list: ARRAYED_LIST [PT_WORD]
	passage_list: ARRAYED_LIST [PT_PASSAGE]
	section_list: ARRAYED_LIST [PT_SECTION]
	index_by_id: HASH_TABLE [INTEGER, INTEGER_64]

feature {NONE} -- Model caches (a revision is immutable after `make')

	ids_model_cache: detachable MML_SEQUENCE [PT_WORD_ID]
	spoken_ids_model_cache: detachable MML_SEQUENCE [PT_WORD_ID]

invariant
	number_positive: number >= 1
	passages_fit: passage_count <= word_count
	sections_fit: section_count <= passage_count
	empty_consistent: word_count = 0 implies passage_count = 0
	index_sized: index_by_id.count = word_count

end
