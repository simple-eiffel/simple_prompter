note
	description: "[
		Captions of what was said (0.5.0, the Publish step). The analyzer's captions
		(PT_CAPTION_BUILDER) show the script's words at the times it matched them; when a
		sentence is skipped they still show it, squeezing the next one to a blink (Reel 2).
		These come from the words whisper heard in the finished video instead:

		- words heard where the speech map has only silence are dropped (whisper invents
		  "Thank you." over a silent ending), and so is the first copy of a run of 2 to 6
		  words repeated at once (whisper's word-by-word mode can echo a phrase said once);
		- a sentence read as written (same word count, 85% the same words) takes the script's
		  wording: its quotes, capitals and spelling;
		- each sentence becomes captions of at most `Max_chars', split evenly (after a comma
		  when one is near), two lines of at most `Line_chars';
		- a caption starts when the speaking does and holds at most `Hold_s' into a pause.
	]"
	author: "Larry Rix"

class
	PT_SPOKEN_CAPTIONS

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_cues.make (64)
			create normalizer
		ensure
			empty: last_cues.is_empty
		end

feature -- Constants

	Max_chars: INTEGER = 84
	Line_chars: INTEGER = 42
	Min_seconds: REAL_64 = 0.8
	Hold_s: REAL_64 = 0.4
			-- Longest a caption stays up into a pause.
	Speech_slack: REAL_64 = 0.8
			-- A word this near the speech map's speech still counts as spoken.
	Max_repeat: INTEGER = 6
	Adopt_share: REAL_64 = 0.85

feature -- Access

	last_cues: ARRAYED_LIST [PT_CAPTION_CUE]
			-- The captions of the last `build', on the output timeline.

	adopted_count: INTEGER
			-- Sentences of the last `build' shown in the script's wording.

	dropped_count: INTEGER
			-- Words the last `build' left out (heard in silence, or a repeat).

feature -- Basic operations

	build (a_words: LIST [PT_HEARD_WORD]; a_map: PT_SPEECH_MAP; a_script: PT_SCRIPT_TEXT; a_shift, a_length: REAL_64)
			-- Captions for an output that starts at `a_shift' on the words' timeline and lasts `a_length'.
		require
			shift_non_negative: a_shift >= 0
			length_positive: a_length > 0
		local
			l_words: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]
			l_sentences: ARRAYED_LIST [ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]]
		do
			last_cues.wipe_out
			adopted_count := 0
			l_words := spoken (a_words, a_map)
			dropped_count := a_words.count - l_words.count
			dropped_count := dropped_count + drop_repeats (l_words)
			l_sentences := sentences (l_words, a_script)
			across l_sentences as ic loop
				if adopt (ic, a_script) then
					adopted_count := adopted_count + 1
				end
			end
			across l_sentences as ic loop
				across pieces (ic) as ic_piece loop
					add_cue (ic_piece, a_map, a_shift, a_length)
				end
			end
		ensure
			within_output: across last_cues as ic all ic.t0 >= 0 and ic.t1 <= a_length end
			in_order: across 2 |..| last_cues.count as i all last_cues [i - 1].t1 <= last_cues [i].t0 end
		end

feature -- Matching

	same_word (a_heard, a_script: READABLE_STRING_32): BOOLEAN
			-- Do normal forms `a_heard' and `a_script' name the same word (34 = thirty-four)?
		do
			Result := a_heard.same_string (a_script) or else (is_number (a_heard) and then number_words (a_heard.to_integer).same_string (a_script))
				or else (is_number (a_script) and then number_words (a_script.to_integer).same_string (a_heard))
		end

	number_words (n: INTEGER): STRING_32
			-- `n' (0 to 99) in words, run together as the normal form has it ("thirtyfour").
		require
			small: n >= 0 and n <= 99
		local
			l_ones: ARRAY [STRING_32]
			l_tens: ARRAY [STRING_32]
		do
			l_ones := <<{STRING_32} "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
				"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen">>
			l_tens := <<{STRING_32} "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety">>
			if n < 20 then
				Result := l_ones [n + 1].twin
			else
				Result := l_tens [n // 10 + 1].twin
				if n \\ 10 > 0 then
					Result.append (l_ones [n \\ 10 + 1])
				end
			end
		end

	is_number (a_text: READABLE_STRING_32): BOOLEAN
			-- Is `a_text' one or two digits?
		do
			Result := (a_text.count = 1 or a_text.count = 2) and then a_text.is_integer
		end

feature {NONE} -- Steps

	normalizer: PT_NORMALIZER

	spoken (a_words: LIST [PT_HEARD_WORD]; a_map: PT_SPEECH_MAP): ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]
			-- `a_words' heard in or beside speech (all of them when the map has no speech).
		local
			l_mid: REAL_64
			l_in: BOOLEAN
			j: INTEGER
		do
			create Result.make (a_words.count)
			across a_words as ic loop
				l_mid := (ic.t0 + ic.t1) / 2
				l_in := a_map.span_count = 0
				from j := 1 until l_in or j > a_map.span_count loop
					l_in := l_mid >= a_map.span (j).t0 - Speech_slack and l_mid <= a_map.span (j).t1 + Speech_slack
					j := j + 1
				end
				if l_in then
					Result.extend ([ic.text.twin, ic.t0, ic.t1])
				end
			end
		ensure
			not_more: Result.count <= a_words.count
		end

	drop_repeats (a_words: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]): INTEGER
			-- Remove the first copy of each run of 2 to `Max_repeat' words repeated at once; how many words went.
		local
			k, i, j: INTEGER
			l_changed, l_same: BOOLEAN
		do
			from l_changed := True until not l_changed loop
				l_changed := False
				from k := Max_repeat until k < 2 or l_changed loop
					from i := 1 until i + 2 * k - 1 > a_words.count or l_changed loop
						l_same := True
						from j := 0 until j >= k or not l_same loop
							l_same := normalizer.normalized (a_words [i + j].text).same_string (normalizer.normalized (a_words [i + k + j].text))
							j := j + 1
						end
						if l_same then
							a_words [i + k].t0 := a_words [i].t0
							from j := 1 until j > k loop
								a_words.go_i_th (i)
								a_words.remove
								j := j + 1
							end
							Result := Result + k
							l_changed := True
						end
						i := i + 1
					end
					k := k - 1
				end
			end
		ensure
			counted: a_words.count = old a_words.count - Result
		end

	sentences (a_words: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]; a_script: PT_SCRIPT_TEXT): ARRAYED_LIST [ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]]
			-- `a_words' cut after each word that ends a sentence.
		local
			l_current: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]
		do
			create Result.make (32)
			create l_current.make (16)
			across a_words as ic loop
				l_current.extend (ic)
				if a_script.ends_sentence (ic.text) then
					Result.extend (l_current)
					create l_current.make (16)
				end
			end
			if not l_current.is_empty then
				Result.extend (l_current)
			end
		ensure
			none_empty: across Result as ic all not ic.is_empty end
		end

	adopt (a_sentence: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]; a_script: PT_SCRIPT_TEXT): BOOLEAN
			-- Give `a_sentence' the wording of the first script sentence it reads as written; was there one?
		local
			l_tokens: ARRAYED_LIST [STRING_32]
			l_same, i: INTEGER
		do
			across a_script.sentences as ic until Result loop
				l_tokens := a_script.words_of (ic)
				if l_tokens.count = a_sentence.count then
					l_same := 0
					from i := 1 until i > l_tokens.count loop
						if same_word (normalizer.normalized (a_sentence [i].text), normalizer.normalized (l_tokens [i])) then
							l_same := l_same + 1
						end
						i := i + 1
					end
					if l_same >= (Adopt_share * l_tokens.count).ceiling then
						from i := 1 until i > l_tokens.count loop
							a_sentence [i].text := l_tokens [i]
							i := i + 1
						end
						Result := True
					end
				end
			end
		end

	pieces (a_sentence: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]): ARRAYED_LIST [ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]]
			-- `a_sentence' as near-equal runs of at most about `Max_chars', each break after a comma
			-- when one lies within 15 characters of the even point.
		local
			l_total, l_n, k, l_pos, l_target, l_best, l_best_d, l_start, i: INTEGER
			l_ends: ARRAYED_LIST [INTEGER]
			l_comma: BOOLEAN
			l_piece: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]
		do
			create Result.make (2)
			create l_ends.make (a_sentence.count)
			across a_sentence as ic loop
				l_pos := l_pos + ic.text.count + 1
				l_ends.extend (l_pos)
			end
			l_total := l_pos - 1
			l_n := (l_total + Max_chars - 1) // Max_chars
			l_start := 1
			from k := 1 until k >= l_n.max (1) loop
				l_target := (l_total * k) // l_n
				l_best := 0
				l_best_d := l_total
				l_comma := False
				from i := l_start until i >= a_sentence.count loop
					if (l_ends [i] - l_target).abs <= 15 and a_sentence [i].text.ends_with ({STRING_32} ",") then
						if not l_comma or (l_ends [i] - l_target).abs < l_best_d then
							l_best := i
							l_best_d := (l_ends [i] - l_target).abs
							l_comma := True
						end
					elseif not l_comma and (l_ends [i] - l_target).abs < l_best_d then
						l_best := i
						l_best_d := (l_ends [i] - l_target).abs
					end
					i := i + 1
				end
				if l_best >= l_start then
					create l_piece.make (16)
					from i := l_start until i > l_best loop
						l_piece.extend (a_sentence [i])
						i := i + 1
					end
					Result.extend (l_piece)
					l_start := l_best + 1
				end
				k := k + 1
			end
			create l_piece.make (16)
			from i := l_start until i > a_sentence.count loop
				l_piece.extend (a_sentence [i])
				i := i + 1
			end
			if not l_piece.is_empty then
				Result.extend (l_piece)
			end
		ensure
			all_words: across Result as ic all not ic.is_empty end
		end

	add_cue (a_piece: ARRAYED_LIST [TUPLE [text: STRING_32; t0, t1: REAL_64]]; a_map: PT_SPEECH_MAP; a_shift, a_length: REAL_64)
			-- One caption for `a_piece', its times fitted to the speech and moved to the output timeline.
		require
			piece_present: not a_piece.is_empty
		local
			l_text: STRING_32
			l_t0, l_t1: REAL_64
		do
			create l_text.make (Max_chars)
			across a_piece as ic loop
				if not l_text.is_empty then
					l_text.append_character (' ')
				end
				l_text.append (ic.text)
			end
			l_t0 := a_piece.first.t0
			l_t1 := a_piece.last.t1.max (l_t0)
			if l_t0 <= a_map.duration and then a_map.is_silent_at (l_t0) and then attached a_map.silence_around (l_t0) as al_gap
				and then al_gap.t1 - l_t0 <= 1.0 then
					-- Appear when the speaking starts.
				l_t0 := al_gap.t1
			end
			if l_t1 <= a_map.duration and then l_t1 - 0.05 >= 0 and then a_map.is_silent_at (l_t1 - 0.05) and then attached a_map.silence_around (l_t1 - 0.05) as al_gap then
				l_t1 := l_t1.min (al_gap.t0 + Hold_s)
			end
			l_t0 := (l_t0 - a_shift).max (0)
			l_t1 := (l_t1 - a_shift).max (l_t0 + Min_seconds).min (a_length)
			if not last_cues.is_empty and then last_cues.last.t1 > l_t0 then
				if l_t0 > last_cues.last.t0 then
						-- The earlier caption ends where this one starts.
					last_cues.finish
					last_cues.replace (create {PT_CAPTION_CUE}.make (last_cues.last.t0, l_t0, last_cues.last.text, last_cues.last.word_ids))
				else
					l_t0 := last_cues.last.t1
				end
			end
			if l_t1 > l_t0 and not l_text.is_empty then
				last_cues.extend (create {PT_CAPTION_CUE}.make (l_t0, l_t1, two_lines (l_text), create {ARRAYED_LIST [PT_WORD_ID]}.make (0)))
			end
		end

	two_lines (a_text: STRING_32): STRING_32
			-- `a_text' broken at the space nearest its middle when longer than `Line_chars'.
		local
			i, l_best: INTEGER
		do
			Result := a_text.twin
			if a_text.count > Line_chars then
				from i := 1 until i > a_text.count loop
					if a_text [i] = ' ' and then (l_best = 0 or else (i - a_text.count // 2).abs < (l_best - a_text.count // 2).abs) then
						l_best := i
					end
					i := i + 1
				end
				if l_best > 0 then
					Result [l_best] := '%N'
				end
			end
		ensure
			same_length: Result.count = a_text.count
		end

end
