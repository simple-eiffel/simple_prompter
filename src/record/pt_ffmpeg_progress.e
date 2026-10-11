note
	description: "[
		How far an ffmpeg run has got (0.6.0): the time of its last "time=hh:mm:ss.cc" stats
		reading, against the length of what it is writing. The Last take panel's progress
		bars (Render, Publish) come from it.
	]"
	author: "Larry Rix"

class
	PT_FFMPEG_PROGRESS

create
	make

feature {NONE} -- Initialization

	make
		do
		end

feature -- Reading

	last_seconds (a_text: READABLE_STRING_GENERAL): REAL_64
			-- Seconds of the last "time=h:mm:ss.cc" in `a_text', or -1 when it has none
			-- ("time=N/A" does not count).
		local
			l_text, l_value: STRING_32
			l_at, l_end: INTEGER
			l_seconds: REAL_64
		do
			Result := -1
			l_text := a_text.to_string_32
			from l_at := l_text.substring_index ({STRING_32} "time=", 1) until l_at = 0 loop
				from l_end := l_at + 5 until l_end > l_text.count or else l_text [l_end] = ' ' or else l_text [l_end] = '%R' or else l_text [l_end] = '%N' loop
					l_end := l_end + 1
				end
				l_value := l_text.substring (l_at + 5, l_end - 1)
				l_seconds := clock_seconds (l_value)
				if l_seconds >= 0 then
					Result := l_seconds
				end
				l_at := l_text.substring_index ({STRING_32} "time=", l_at + 5)
			end
		ensure
			none_or_time: Result = -1 or Result >= 0
		end

	fraction (a_text: READABLE_STRING_GENERAL; a_length: REAL_64): REAL_64
			-- How much of `a_length' seconds the last reading in `a_text' covers (0..1), or -1 with no reading.
		require
			length_positive: a_length > 0
		local
			l_seconds: REAL_64
		do
			l_seconds := last_seconds (a_text)
			if l_seconds < 0 then
				Result := -1
			else
				Result := (l_seconds / a_length).min (1.0)
			end
		ensure
			none_or_fraction: Result = -1 or (Result >= 0 and Result <= 1)
		end

	clock_seconds (a_value: READABLE_STRING_32): REAL_64
			-- "h:mm:ss.cc" (hours may be any width) in seconds, or -1 when `a_value' is not that.
		local
			l_parts: LIST [READABLE_STRING_32]
		do
			Result := -1
			l_parts := a_value.split (':')
			if l_parts.count = 3 and then l_parts [1].is_integer and then l_parts [2].is_integer and then l_parts [3].is_double then
				Result := l_parts [1].to_integer * 3600 + l_parts [2].to_integer * 60 + l_parts [3].to_double
				if Result < 0 then
					Result := -1
				end
			end
		ensure
			none_or_time: Result = -1 or Result >= 0
		end

end
