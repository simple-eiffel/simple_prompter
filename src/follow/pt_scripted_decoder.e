note
	description: "[
		Decoder test double: returns scripted words for a window, keyed by the
		window's start sample; unknown windows hear nothing. Records the last
		prompt it was given so tests can check prompt bookkeeping.
	]"
	author: "Larry Rix"

class
	PT_SCRIPTED_DECODER

inherit
	PT_DECODER

create
	make

feature {NONE} -- Initialization

	make
			-- Decoder with no scripted windows.
		do
			create script.make (8)
			create last_prompt.make_empty
		ensure
			nothing_scripted: scripted_count = 0
		end

feature -- Access

	scripted_count: INTEGER
		do
			Result := script.count
		end

	last_prompt: STRING_32
			-- Prompt of the most recent `decode' (test observation).

	decode_count: INTEGER
			-- Number of `decode' calls (test observation).

feature -- Element change

	script_window (a_window_start: INTEGER_64; a_words: ARRAY [STRING_32])
			-- When the window starting at `a_window_start' is decoded, hear `a_words'
			-- (spread evenly over the first second).
		require
			start_non_negative: a_window_start >= 0
			words_present: across a_words as ic all not ic.is_empty end
		do
			script.force (a_words, a_window_start)
		ensure
			scripted: scripted_count >= old scripted_count
		end

feature -- Decoding

	decode (a_samples: SPECIAL [REAL_32]; a_count: INTEGER; a_window_start: INTEGER_64;
			a_prompt: READABLE_STRING_32): PT_HEARD_WORDS
			-- Scripted words for `a_window_start'.
		local
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_step: REAL_64
			i: INTEGER
		do
			-- Observation of a double; the deferred contract does not constrain it.
			last_prompt.make_from_string (a_prompt)
			decode_count := decode_count + 1
			create l_words.make (4)
			if attached script.item (a_window_start) as al_words and then al_words.count > 0 then
				l_step := (a_count / 16_000).min (1.0) / al_words.count
				from i := al_words.lower until i > al_words.upper loop
					l_words.extend (create {PT_HEARD_WORD}.make (al_words [i], al_words [i].as_lower,
						(i - al_words.lower) * l_step, (i - al_words.lower + 1) * l_step, 0.9))
					i := i + 1
				end
			end
			create Result.make (a_window_start, a_count, l_words)
		end

feature {NONE} -- Implementation

	script: HASH_TABLE [ARRAY [STRING_32], INTEGER_64]

end
