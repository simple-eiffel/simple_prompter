note
	description: "[
		When a heard word (or short heard span) counts as the script word, even though
		it is spelled differently. Built from Larry's real recording (evidence/
		real-voice-larry_read_01.md, review H7), where 91.7% raw accuracy hid
		systematic, harmless differences:
		  homophones      their / they're -> there, to / too -> two, whole -> hole, so -> sew
		  abbreviations   e.g. spoken as "for example"; Ms. heard as "Mrs."
		  numbers         one <-> 1
		  compounds       postcondition <-> "post condition", c p p <-> "cpp"
		  phonetics       Silero <-> Celero (Phase 4: Metaphone-style key)
		All inputs are normalized forms (PT_NORMALIZER); a heard span may contain spaces.
	]"
	author: "Larry Rix"

class
	PT_EQUIVALENCES

feature -- Queries

	are_equivalent (a_heard, a_script: READABLE_STRING_32): BOOLEAN
			-- Does heard `a_heard' (a word or short span) count as script word `a_script'?
		local
			l_spaced: BOOLEAN
		do
			l_spaced := has_joiner (a_heard) or has_joiner (a_script)
			Result := a_heard.same_string (a_script)
				or else same_homophone_class (a_heard, a_script)
				or else is_spoken_form (a_heard, a_script)
				or else is_spoken_form (a_script, a_heard)
				or else (number_value (a_heard) >= 0 and then number_value (a_heard) = number_value (a_script))
				or else (l_spaced and then joined (a_heard).same_string (joined (a_script)))
				or else (not a_heard.has (' ') and then not has_digit (a_heard) and then not has_digit (a_script)
					and then phonetic_key (a_script).count >= Min_phonetic_length
					and then phonetic_key (a_heard).same_string (phonetic_key (a_script)))
						-- Sound-alike keys are for words: a doubled digit is a different number
						-- ("55070" is not "5070"; T18 on larry_read_01).
		ensure
			reflexive: a_heard.same_string (a_script) implies Result
			homophones: same_homophone_class (a_heard, a_script) implies Result
			abbreviations: (is_spoken_form (a_heard, a_script) or is_spoken_form (a_script, a_heard)) implies Result
			compounds: joined (a_heard).same_string (joined (a_script)) implies Result
		end

	homophone_class (a_word: READABLE_STRING_32): INTEGER
			-- Class number of `a_word' among the homophone sets, 0 if none.
		do
			Result := cached_homophones.item (as_key (a_word))
		ensure
			non_negative: Result >= 0
		end

	same_homophone_class (a, b: READABLE_STRING_32): BOOLEAN
		do
			Result := homophone_class (a) > 0 and homophone_class (a) = homophone_class (b)
		end

	spoken_forms (a_written: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- How abbreviation `a_written' (normalized, e.g. "eg") may be spoken.
		do
			if attached cached_abbreviations.item (as_key (a_written)) as al_forms then
				Result := al_forms
			else
				Result := no_forms
			end
		end

	is_spoken_form (a_heard, a_written: READABLE_STRING_32): BOOLEAN
			-- Is `a_heard' one of the spoken forms of `a_written'?
		do
			if attached cached_abbreviations.item (as_key (a_written)) as al_forms then
				Result := across al_forms as ic some ic.same_string (a_heard) end
			end
		end

	number_value (a_word: READABLE_STRING_32): INTEGER
			-- Value of a digit string or a single number word (zero..twenty, tens), -1 otherwise.
		do
			Result := -1
			if not a_word.is_empty then
				if a_word [1].is_digit then
					if a_word.count <= 9 and then across a_word as ic all ic.is_digit end then
						Result := a_word.to_string_32.to_integer
					end
				elseif cached_number_words.has (as_key (a_word)) then
					Result := cached_number_words [as_key (a_word)]
				end
			end
		ensure
			minus_one_or_value: Result >= -1
		end

	joined (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' without spaces and hyphens ("post condition" -> "postcondition").
		do
			create Result.make (a_text.count)
			across a_text as ic loop
				if ic /= ' ' and ic /= '-' then
					Result.append_character (ic)
				end
			end
		ensure
			no_spaces: not Result.has (' ')
			not_longer: Result.count <= a_text.count
		end

	phonetic_key (a_word: READABLE_STRING_32): STRING_32
			-- Sound-alike key (Metaphone-style).
		do
			if attached cached_keys.item (as_key (a_word)) as al_known then
				Result := al_known
			else
				Result := computed_key (a_word)
				if cached_keys.count < Max_cached_keys then
					cached_keys.put (Result, a_word.to_string_32)
				end
			end
		ensure
			deterministic_length: Result.count <= a_word.count + 1
		end

	Min_phonetic_length: INTEGER = 3
			-- Short keys collide too easily to count.

feature {NONE} -- Phonetic key

	Max_cached_keys: INTEGER = 20_000

	cached_keys: HASH_TABLE [STRING_32, STRING_32]
			-- Memo of phonetic keys (script and heard words repeat across updates).
		once
			create Result.make (1024)
		end

	computed_key (a_word: READABLE_STRING_32): STRING_32
			-- Metaphone-style key of `a_word'.
		local
			i: INTEGER
			c, l_next, l_mapped: CHARACTER_32
		do
			create Result.make (a_word.count)
			from i := 1 until i > a_word.count loop
				c := a_word [i].as_lower
				if i < a_word.count then
					l_next := a_word [i + 1].as_lower
				else
					l_next := ' '
				end
				l_mapped := '%U'
				if c = 'c' then
					if l_next = 'e' or l_next = 'i' or l_next = 'y' then
						l_mapped := 's'
					elseif l_next /= 'k' then
						l_mapped := 'k'
					end
				elseif c = 'q' then
					l_mapped := 'k'
				elseif c = 'z' or c = 'x' then
					l_mapped := 's'
				elseif c = 'p' and l_next = 'h' then
					l_mapped := 'f'
				elseif c = 'k' and i = 1 and l_next = 'n' then
						-- silent k in "kn"
				elseif c = 'w' and i = 1 and l_next = 'r' then
						-- silent w in "wr"
				elseif c = 'h' then
					if i = 1 then
						l_mapped := 'h'
					end
				elseif c = 'a' or c = 'e' or c = 'i' or c = 'o' or c = 'u' or c = 'y' or c = 'w' then
					if i = 1 then
						l_mapped := 'a'
					end
				elseif c.is_alpha or c.is_digit then
					l_mapped := c
				end
				if l_mapped /= '%U' and then (Result.is_empty or else Result [Result.count] /= l_mapped) then
					Result.append_character (l_mapped)
				end
				i := i + 1
			end
		ensure
			not_longer: Result.count <= a_word.count
		end

feature {NONE} -- Lookup helpers

	as_key (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' as a hash key, copying only when it is not already a STRING_32.
		do
			if attached {STRING_32} a_text as al_s then
				Result := al_s
			else
				Result := a_text.to_string_32
			end
		end

	has_digit (a_text: READABLE_STRING_32): BOOLEAN
			-- Does `a_text' contain a digit?
		do
			Result := across a_text as ic some ic.is_digit end
		end

	has_joiner (a_text: READABLE_STRING_32): BOOLEAN
			-- Does `a_text' contain a space or hyphen (a compound candidate)?
		do
			Result := a_text.has (' ') or a_text.has ('-')
		end

	no_forms: ARRAYED_LIST [STRING_32]
			-- Shared empty result of `spoken_forms'.
		once
			create Result.make (0)
		end

feature {NONE} -- Tables (built once per processor)

	cached_homophones: HASH_TABLE [INTEGER, STRING_32]
		local
			l_sets: ARRAY [ARRAY [STRING_32]]
			i: INTEGER
		once
			l_sets := <<
				<<{STRING_32} "their", {STRING_32} "there", {STRING_32} "they're", {STRING_32} "theyre">>,
				<<{STRING_32} "to", {STRING_32} "too", {STRING_32} "two">>,
				<<{STRING_32} "hole", {STRING_32} "whole">>,
				<<{STRING_32} "so", {STRING_32} "sew", {STRING_32} "sow">>,
				<<{STRING_32} "for", {STRING_32} "four", {STRING_32} "fore">>,
				<<{STRING_32} "by", {STRING_32} "buy", {STRING_32} "bye">>,
				<<{STRING_32} "right", {STRING_32} "write", {STRING_32} "rite">>,
				<<{STRING_32} "no", {STRING_32} "know">>,
				<<{STRING_32} "new", {STRING_32} "knew">>,
				<<{STRING_32} "here", {STRING_32} "hear">>,
				<<{STRING_32} "its", {STRING_32} "it's">>,
				<<{STRING_32} "your", {STRING_32} "you're", {STRING_32} "youre">>,
				<<{STRING_32} "one", {STRING_32} "won">>,
				<<{STRING_32} "eight", {STRING_32} "ate">>,
				<<{STRING_32} "see", {STRING_32} "sea">>,
				<<{STRING_32} "hour", {STRING_32} "our">>,
				<<{STRING_32} "whether", {STRING_32} "weather">>,
				<<{STRING_32} "piece", {STRING_32} "peace">>,
				<<{STRING_32} "wear", {STRING_32} "where">>,
				<<{STRING_32} "which", {STRING_32} "witch">>,
				<<{STRING_32} "threw", {STRING_32} "through">>,
				<<{STRING_32} "weak", {STRING_32} "week">>,
				<<{STRING_32} "wait", {STRING_32} "weight">>>>
			create Result.make (64)
			from i := l_sets.lower until i > l_sets.upper loop
				across l_sets [i] as ic loop
					Result.put (i, ic)
				end
				i := i + 1
			end
		end

	cached_abbreviations: HASH_TABLE [ARRAYED_LIST [STRING_32], STRING_32]
			-- Normalized written form -> spoken forms (normalized, may contain spaces).
		once
			create Result.make (16)
			Result.put (forms (<<{STRING_32} "for example">>), {STRING_32} "eg")
			Result.put (forms (<<{STRING_32} "that is">>), {STRING_32} "ie")
			Result.put (forms (<<{STRING_32} "doctor">>), {STRING_32} "dr")
			Result.put (forms (<<{STRING_32} "mister">>), {STRING_32} "mr")
			Result.put (forms (<<{STRING_32} "missus">>), {STRING_32} "mrs")
			Result.put (forms (<<{STRING_32} "miz", {STRING_32} "mrs", {STRING_32} "miss">>), {STRING_32} "ms")
			Result.put (forms (<<{STRING_32} "versus">>), {STRING_32} "vs")
			Result.put (forms (<<{STRING_32} "et cetera", {STRING_32} "etcetera">>), {STRING_32} "etc")
			Result.put (forms (<<{STRING_32} "saint", {STRING_32} "street">>), {STRING_32} "st")
		end

	cached_number_words: HASH_TABLE [INTEGER, STRING_32]
		local
			l_words: ARRAY [STRING_32]
			i: INTEGER
		once
			l_words := <<{STRING_32} "zero", {STRING_32} "one", {STRING_32} "two", {STRING_32} "three", {STRING_32} "four",
				{STRING_32} "five", {STRING_32} "six", {STRING_32} "seven", {STRING_32} "eight", {STRING_32} "nine",
				{STRING_32} "ten", {STRING_32} "eleven", {STRING_32} "twelve", {STRING_32} "thirteen", {STRING_32} "fourteen",
				{STRING_32} "fifteen", {STRING_32} "sixteen", {STRING_32} "seventeen", {STRING_32} "eighteen",
				{STRING_32} "nineteen", {STRING_32} "twenty">>
			create Result.make (32)
			from i := l_words.lower until i > l_words.upper loop
				Result.put (i - l_words.lower, l_words [i])
				i := i + 1
			end
			Result.put (30, {STRING_32} "thirty")
			Result.put (40, {STRING_32} "forty")
			Result.put (50, {STRING_32} "fifty")
			Result.put (60, {STRING_32} "sixty")
			Result.put (70, {STRING_32} "seventy")
			Result.put (80, {STRING_32} "eighty")
			Result.put (90, {STRING_32} "ninety")
		end

	forms (a_items: ARRAY [STRING_32]): ARRAYED_LIST [STRING_32]
		do
			create Result.make_from_array (a_items)
		end

end
