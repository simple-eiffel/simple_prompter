note
	description: "[
		PT_VOICE_FRAME / PT_HEARD_WORDS <-> one compact STRING_8 record, so values
		cross SCOOP processors as strings (the simple_taskman frame-codec pattern).
		Records: "F|pos|level|prob|0/1" and "H|start|samples|n|w1|t0|t1|p|w2|...".
	]"
	author: "Larry Rix"

class
	PT_SPEECH_CODEC

create
	make

feature {NONE} -- Initialization

	make
		do
		ensure
			nothing_decoded: last_frame = Void and last_heard = Void
		end

feature -- Encoding

	encode_frame (a_frame: PT_VOICE_FRAME): STRING_8
		do
			create Result.make (64)
			Result.append ("F|")
			Result.append (a_frame.sample_pos.out)
			Result.append_character ('|')
			Result.append (a_frame.level.out)
			Result.append_character ('|')
			Result.append (a_frame.speech_probability.out)
			Result.append_character ('|')
			if a_frame.is_speech then
				Result.append_character ('1')
			else
				Result.append_character ('0')
			end
		ensure
			tagged: Result.starts_with ("F|")
			one_line: not Result.has ('%N')
		end

	encode_heard (a_heard: PT_HEARD_WORDS): STRING_8
		local
			i: INTEGER
		do
			create Result.make (64 + 48 * a_heard.count)
			Result.append ("H|")
			Result.append (a_heard.window_start.out)
			Result.append_character ('|')
			Result.append (a_heard.window_samples.out)
			Result.append_character ('|')
			Result.append (a_heard.count.out)
			from i := 1 until i > a_heard.count loop
				Result.append_character ('|')
				Result.append (escaped (a_heard.word (i).text))
				Result.append_character ('|')
				Result.append (escaped (a_heard.word (i).normalized))
				Result.append_character ('|')
				Result.append (a_heard.word (i).t0.out)
				Result.append_character ('|')
				Result.append (a_heard.word (i).t1.out)
				Result.append_character ('|')
				Result.append (a_heard.word (i).probability.out)
				i := i + 1
			end
		ensure
			tagged: Result.starts_with ("H|")
			one_line: not Result.has ('%N')
		end

feature -- Decoding

	decode (a_record: READABLE_STRING_8)
			-- Set `last_frame' or `last_heard' (the other becomes Void); both Void on a bad record.
		local
			l_parts: LIST [READABLE_STRING_8]
		do
			last_frame := Void
			last_heard := Void
			l_parts := a_record.split ('|')
			if l_parts.count = 5 and then l_parts [1].same_string ("F") then
				decode_frame (l_parts)
			elseif l_parts.count >= 4 and then l_parts [1].same_string ("H") then
				decode_heard (l_parts)
			end
		ensure
			at_most_one: not (attached last_frame and attached last_heard)
		end

	last_frame: detachable PT_VOICE_FRAME
	last_heard: detachable PT_HEARD_WORDS

feature {NONE} -- Implementation

	decode_frame (a_parts: LIST [READABLE_STRING_8])
			-- "F|pos|level|prob|0/1".
		require
			five: a_parts.count = 5
		local
			l_level, l_probability: REAL_64
		do
			if a_parts [2].is_integer_64 and a_parts [3].is_double and a_parts [4].is_double
				and (a_parts [5].same_string ("0") or a_parts [5].same_string ("1")) then
				l_level := a_parts [3].to_double
				l_probability := a_parts [4].to_double
				if a_parts [2].to_integer_64 >= 0 and l_level >= 0.0 and l_level <= 1.0
					and l_probability >= 0.0 and l_probability <= 1.0 then
					create last_frame.make (a_parts [2].to_integer_64, l_level, l_probability, a_parts [5].same_string ("1"))
				end
			end
		end

	decode_heard (a_parts: LIST [READABLE_STRING_8])
			-- "H|start|samples|n" followed by n groups "text|normalized|t0|t1|p".
		require
			header: a_parts.count >= 4
		local
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_n, i, k: INTEGER
			l_text, l_normal: STRING_32
			l_t0, l_t1, l_p: REAL_64
			l_good: BOOLEAN
		do
			if a_parts [2].is_integer_64 and a_parts [3].is_integer and a_parts [4].is_integer then
				l_n := a_parts [4].to_integer
				l_good := l_n >= 0 and a_parts.count = 4 + 5 * l_n and a_parts [2].to_integer_64 >= 0 and a_parts [3].to_integer > 0
				create l_words.make (l_n.max (0))
				from i := 0 until not l_good or i >= l_n loop
					k := 5 + 5 * i
					l_text := unescaped (a_parts [k])
					l_normal := unescaped (a_parts [k + 1])
					l_good := not l_text.is_empty and a_parts [k + 2].is_double and a_parts [k + 3].is_double and a_parts [k + 4].is_double
					if l_good then
						l_t0 := a_parts [k + 2].to_double
						l_t1 := a_parts [k + 3].to_double
						l_p := a_parts [k + 4].to_double
						l_good := l_t0 >= 0 and l_t0 <= l_t1 and l_p >= 0.0 and l_p <= 1.0
						if l_good then
							l_words.extend (create {PT_HEARD_WORD}.make (l_text, l_normal, l_t0, l_t1, l_p))
						end
					end
					i := i + 1
				end
				if l_good then
					create last_heard.make (a_parts [2].to_integer_64, a_parts [3].to_integer, l_words)
				end
			end
		end

	escaped (a_text: READABLE_STRING_32): STRING_8
			-- UTF-8 of `a_text' with '%' and '|' percent-escaped.
		local
			l_utf: UTF_CONVERTER
		do
			Result := l_utf.string_32_to_utf_8_string_8 (a_text)
			Result.replace_substring_all ("%%", "%%25")
			Result.replace_substring_all ("|", "%%7C")
		ensure
			no_separator: not Result.has ('|')
		end

	unescaped (a_field: READABLE_STRING_8): STRING_32
			-- Inverse of `escaped'.
		local
			l_utf: UTF_CONVERTER
			l_bytes: STRING_8
		do
			create l_bytes.make_from_string (a_field)
			l_bytes.replace_substring_all ("%%7C", "|")
			l_bytes.replace_substring_all ("%%25", "%%")
			Result := l_utf.utf_8_string_8_to_string_32 (l_bytes)
		end

end
