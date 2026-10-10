note
	description: "[
		YouTube chapters for a published video (0.5.0). Each paragraph of the script may start
		a chapter: it starts at the caption that opens with the paragraph's first words.
		The first paragraph is chapter 0:00; a later one is kept when it starts at least
		`Min_gap' after the chapter before and `Min_last' before the end (YouTube wants 10 s
		chapters), and when that leaves more than `Max_chapters', the shortest chapters fold
		into the ones before them. Each chapter's label is its paragraph's opening words,
		until `set_labels' gives better ones (the local AI's).
	]"
	author: "Larry Rix"

class
	PT_CHAPTER_PICKER

create
	make

feature {NONE} -- Initialization

	make
		do
			create chapters.make (8)
			create normalizer
		ensure
			none: chapters.is_empty
		end

feature -- Constants

	Min_gap: REAL_64 = 10.0
	Min_last: REAL_64 = 10.0
	Max_chapters: INTEGER = 8
	Label_words: INTEGER = 7
	Opening_words: INTEGER = 4
			-- A paragraph starts at the caption that opens with its first words: all but one of
			-- its first `Opening_words' (whisper drops a word, hears "four" as 4) among the
			-- caption's first `Window_words', the caption's first word one of its first two.
	Window_words: INTEGER = 8

feature -- Access

	chapters: ARRAYED_LIST [TUPLE [t: REAL_64; paragraph: INTEGER; label: STRING_32]]
			-- The chapters of the last `pick', in order, the first at 0.

	text: STRING_32
			-- One line per chapter, "m:ss label", as YouTube reads them from a description.
		do
			create Result.make (256)
			across chapters as ic loop
				Result.append (clock (ic.t) + {STRING_32} " " + ic.label + {STRING_32} "%N")
			end
		end

feature -- Basic operations

	pick (a_script: PT_SCRIPT_TEXT; a_cues: LIST [PT_CAPTION_CUE]; a_length: REAL_64)
			-- Chapters for `a_script' read as `a_cues', in a video `a_length' seconds long.
		require
			length_positive: a_length > 0
		local
			l_c, l_p, l_found, i, l_shortest: INTEGER
			l_opening, l_cue_words: ARRAYED_LIST [STRING_32]
			l_gap: REAL_64
		do
			chapters.wipe_out
			if not a_script.paragraphs.is_empty then
				chapters.extend ([0.0, 1, label_of (a_script, 1)])
				l_c := 1
				from l_p := 2 until l_p > a_script.paragraphs.count loop
					l_opening := normal_words (a_script, a_script.paragraphs [l_p], Opening_words)
					l_found := 0
					from i := l_c until l_found > 0 or i > a_cues.count loop
						l_cue_words := normal_words (a_script, a_cues [i].text, Window_words)
						if opens_with (l_cue_words, l_opening) then
							l_found := i
						end
						i := i + 1
					end
					if l_found > 0 then
						l_c := l_found + 1
						if a_cues [l_found].t0 - chapters.last.t >= Min_gap and a_length - a_cues [l_found].t0 >= Min_last then
							chapters.extend ([a_cues [l_found].t0, l_p, label_of (a_script, l_p)])
						end
					end
					l_p := l_p + 1
				end
				from until chapters.count <= Max_chapters loop
					l_shortest := 2
					l_gap := a_length
					from i := 2 until i > chapters.count loop
						if chapters [i].t - chapters [i - 1].t < l_gap then
							l_gap := chapters [i].t - chapters [i - 1].t
							l_shortest := i
						end
						i := i + 1
					end
					chapters.go_i_th (l_shortest)
					chapters.remove
				end
			end
		ensure
			first_at_zero: not chapters.is_empty implies chapters.first.t = 0.0
			bounded: chapters.count <= Max_chapters
			spaced: across 2 |..| chapters.count as ic_k all chapters [ic_k].t - chapters [ic_k - 1].t >= Min_gap end
		end

	set_labels (a_labels: LIST [STRING_32])
			-- Use `a_labels' (one per chapter) instead of the opening words.
		require
			one_each: a_labels.count = chapters.count
			none_empty: across a_labels as ic all not ic.is_empty end
		local
			i: INTEGER
		do
			from i := 1 until i > chapters.count loop
				chapters [i].label := a_labels [i].twin
				i := i + 1
			end
		end

	openings (a_script: PT_SCRIPT_TEXT): ARRAYED_LIST [STRING_32]
			-- The first sentence of each chapter's paragraph (what the local AI names).
		do
			create Result.make (chapters.count)
			across chapters as ic loop
				if attached a_script.sentences_of (a_script.paragraphs [ic.paragraph]) as al_s and then not al_s.is_empty then
					Result.extend (al_s.first)
				else
					Result.extend (ic.label.twin)
				end
			end
		ensure
			one_each: Result.count = chapters.count
		end

feature -- Formatting

	clock (a_seconds: REAL_64): STRING_32
			-- `a_seconds' as m:ss, or h:mm:ss from an hour.
		local
			s: INTEGER
		do
			s := a_seconds.truncated_to_integer.max (0)
			if s >= 3600 then
				Result := (s // 3600).out.to_string_32 + {STRING_32} ":" + two (s \\ 3600 // 60) + {STRING_32} ":" + two (s \\ 60)
			else
				Result := (s // 60).out.to_string_32 + {STRING_32} ":" + two (s \\ 60)
			end
		end

feature {NONE} -- Implementation

	normalizer: PT_NORMALIZER

	label_of (a_script: PT_SCRIPT_TEXT; a_paragraph: INTEGER): STRING_32
			-- The opening of paragraph `a_paragraph': its first sentence, cut to `Label_words' words.
		local
			l_words: ARRAYED_LIST [STRING_32]
			i: INTEGER
		do
			create Result.make (64)
			l_words := a_script.words_of (a_script.paragraphs [a_paragraph])
			from i := 1 until i > l_words.count or i > Label_words loop
				if i > 1 then
					Result.append_character (' ')
				end
				Result.append (l_words [i])
				if a_script.ends_sentence (l_words [i]) then
					i := l_words.count
				end
				i := i + 1
			end
			if i <= l_words.count then
				Result.append ({STRING_32} "...")
			end
			from until Result.is_empty or else not (Result [Result.count] = '.' or Result [Result.count] = ',' or Result [Result.count] = ';' or Result [Result.count] = ':') or else Result.ends_with ({STRING_32} "...") loop
				Result.remove_tail (1)
			end
			if Result.is_empty then
				Result := {STRING_32} "Part " + a_paragraph.out
			end
		ensure
			present: not Result.is_empty
		end

	normal_words (a_script: PT_SCRIPT_TEXT; a_text: READABLE_STRING_32; a_count: INTEGER): ARRAYED_LIST [STRING_32]
			-- The normal forms of the first `a_count' words of `a_text' (line breaks count as spaces).
		local
			l_text: STRING_32
			l_n: STRING_32
		do
			create Result.make (a_count)
			l_text := a_text.to_string_32.twin
			l_text.replace_substring_all ({STRING_32} "%N", {STRING_32} " ")
			across a_script.words_of (l_text) as ic until Result.count >= a_count loop
				l_n := normalizer.normalized (ic)
				if not l_n.is_empty then
					Result.extend (l_n)
				end
			end
		end

	opens_with (a_cue, a_opening: LIST [STRING_32]): BOOLEAN
			-- Does a caption whose first words are `a_cue' open with a paragraph whose first words are `a_opening'?
		local
			l_hits: INTEGER
		do
			if a_opening.count >= 2 and not a_cue.is_empty
				and then (words.same_word (a_cue [1], a_opening [1]) or words.same_word (a_cue [1], a_opening [2])) then
				across a_opening as ic loop
					if across a_cue as ic_c some words.same_word (ic_c, ic) end then
						l_hits := l_hits + 1
					end
				end
				Result := l_hits >= a_opening.count - 1
			end
		end

	words: PT_SPOKEN_CAPTIONS
			-- For `same_word' (numbers heard as digits).
		once
			create Result.make
		end

	two (n: INTEGER): STRING_32
		do
			Result := n.out.to_string_32
			if n < 10 then
				Result.prepend_character ('0')
			end
		end

end
