note
	description: "Seconds <-> SRT (HH:MM:SS,mmm), WebVTT (HH:MM:SS.mmm), chapter (M:SS / H:MM:SS) and EDL (HH:MM:SS:FF) timecodes."
	author: "Larry Rix"

class
	PT_TIMECODE

feature -- Formatting

	srt (a_seconds: REAL_64): STRING_8
			-- "HH:MM:SS,mmm".
		require
			non_negative: a_seconds >= 0
			below_100_hours: a_seconds < 360_000
		do
			Result := clock (a_seconds, ',')
		ensure
			shape: Result.count = 12 and Result [9] = ','
			round_trip: (seconds_of_srt (Result) - a_seconds).abs <= 0.0005
		end

	vtt (a_seconds: REAL_64): STRING_8
			-- "HH:MM:SS.mmm".
		require
			non_negative: a_seconds >= 0
			below_100_hours: a_seconds < 360_000
		do
			Result := clock (a_seconds, '.')
		ensure
			shape: Result.count = 12 and Result [9] = '.'
		end

	chapter (a_seconds: REAL_64): STRING_8
			-- YouTube chapter time: "M:SS" under an hour, else "H:MM:SS" (whole seconds, truncated).
		require
			non_negative: a_seconds >= 0
		local
			l_total, l_h, l_m, l_s: INTEGER
		do
			l_total := a_seconds.truncated_to_integer
			l_h := l_total // 3600
			l_m := (l_total \\ 3600) // 60
			l_s := l_total \\ 60
			create Result.make (8)
			if l_h > 0 then
				Result.append_integer (l_h)
				Result.append_character (':')
				Result.append (two (l_m))
			else
				Result.append_integer (l_m)
			end
			Result.append_character (':')
			Result.append (two (l_s))
		ensure
			zero_is_0_00: a_seconds < 1 implies Result.same_string ("0:00")
		end

	edl (a_seconds: REAL_64; a_fps: INTEGER): STRING_8
			-- "HH:MM:SS:FF" at `a_fps' frames per second (frames rounded).
		require
			non_negative: a_seconds >= 0
			fps_positive: a_fps > 0
		local
			l_frames, l_total_s, l_f: INTEGER_64
		do
			l_frames := (a_seconds * a_fps).rounded_real_64.truncated_to_integer_64
			l_total_s := l_frames // a_fps
			l_f := l_frames \\ a_fps
			create Result.make (11)
			Result.append (two ((l_total_s // 3600).to_integer_32))
			Result.append_character (':')
			Result.append (two (((l_total_s \\ 3600) // 60).to_integer_32))
			Result.append_character (':')
			Result.append (two ((l_total_s \\ 60).to_integer_32))
			Result.append_character (':')
			Result.append (two (l_f.to_integer_32))
		ensure
			shape: Result.count = 11
		end

feature -- Parsing

	seconds_of_srt (a_code: READABLE_STRING_8): REAL_64
			-- Seconds denoted by "HH:MM:SS,mmm" (or with '.').
		require
			shape: a_code.count = 12 and a_code [3] = ':' and a_code [6] = ':' and (a_code [9] = ',' or a_code [9] = '.')
			digits: is_digits (a_code.substring (1, 2)) and is_digits (a_code.substring (4, 5))
					and is_digits (a_code.substring (7, 8)) and is_digits (a_code.substring (10, 12))
		do
			Result := a_code.substring (1, 2).to_integer * 3600 + a_code.substring (4, 5).to_integer * 60
				+ a_code.substring (7, 8).to_integer + a_code.substring (10, 12).to_integer / 1000
		ensure
			non_negative: Result >= 0
		end

	is_digits (a_text: READABLE_STRING_8): BOOLEAN
		do
			Result := not a_text.is_empty and then across a_text as ic all ic.is_digit end
		end

feature {NONE} -- Implementation

	clock (a_seconds: REAL_64; a_separator: CHARACTER_8): STRING_8
			-- "HH:MM:SS" + `a_separator' + "mmm".
		local
			l_ms: INTEGER_64
		do
			l_ms := (a_seconds * 1000).rounded_real_64.truncated_to_integer_64
			create Result.make (12)
			Result.append (two ((l_ms // 3_600_000).to_integer_32))
			Result.append_character (':')
			Result.append (two (((l_ms \\ 3_600_000) // 60_000).to_integer_32))
			Result.append_character (':')
			Result.append (two (((l_ms \\ 60_000) // 1000).to_integer_32))
			Result.append_character (a_separator)
			Result.append (three ((l_ms \\ 1000).to_integer_32))
		end

	two (a_value: INTEGER): STRING_8
		require
			range: a_value >= 0 and a_value <= 99
		do
			Result := a_value.out
			if Result.count < 2 then
				Result.prepend_character ('0')
			end
		ensure
			two_chars: Result.count = 2
		end

	three (a_value: INTEGER): STRING_8
		require
			range: a_value >= 0 and a_value <= 999
		do
			Result := a_value.out
			from until Result.count >= 3 loop
				Result.prepend_character ('0')
			end
		ensure
			three_chars: Result.count = 3
		end

end
