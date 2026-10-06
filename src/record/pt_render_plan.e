note
	description: "[
		Final render as one ffmpeg pass (spike recipe, frame-accurate):
		per cut trim/atrim + setpts/asetpts, Fade_ms audio fades at every joint
		(click-free), optional punch-in zoom, concat, h264_nvenc + AAC. The filter
		graph goes to a script file (-filter_complex_script) so long cut lists
		never hit the command-line limit.
	]"
	author: "Larry Rix"

class
	PT_RENDER_PLAN

create
	make

feature {NONE} -- Initialization

	make (a_ffmpeg: READABLE_STRING_32; a_fade_ms: INTEGER; a_punch_in: BOOLEAN)
		require
			ffmpeg_present: not a_ffmpeg.is_empty
			fade_range: a_fade_ms >= 0 and a_fade_ms <= 200
		do
			ffmpeg := a_ffmpeg.to_string_32
			fade_ms := a_fade_ms
			is_punch_in := a_punch_in
		ensure
			fade_set: fade_ms = a_fade_ms
			punch_set: is_punch_in = a_punch_in
		end

feature -- Access

	ffmpeg: STRING_32
	fade_ms: INTEGER
			-- 20 ms by default (spike).
	is_punch_in: BOOLEAN
			-- Alternate 100% / 108% zoom at joints (default off: plain cuts decided).

feature -- Rendering

	filter_script (a_cuts: PT_CUT_LIST): STRING_8
			-- filter_complex graph for `a_cuts' (single source, input 0).
		require
			non_empty: a_cuts.count >= 1
		local
			l_k, l_n: INTEGER
			l_cut: PT_CUT
			l_fade: REAL_64
		do
			l_n := a_cuts.count
			l_fade := fade_ms / 1000.0
			create Result.make (l_n * 200)
			from l_k := 0 until l_k >= l_n loop
				l_cut := a_cuts.cut (l_k + 1)
				Result.append ("[0:v]trim=start=" + seconds (l_cut.span.t0) + ":end=" + seconds (l_cut.span.t1) + ",setpts=PTS-STARTPTS")
				if is_punch_in and l_k \\ 2 = 1 then
					Result.append (",scale=iw*1.08:ih*1.08,crop=iw/1.08:ih/1.08")
				end
				Result.append ("[v" + l_k.out + "];")
				Result.append ("[0:a]atrim=start=" + seconds (l_cut.span.t0) + ":end=" + seconds (l_cut.span.t1) + ",asetpts=PTS-STARTPTS")
				if fade_ms > 0 and l_k > 0 then
					Result.append (",afade=t=in:st=0:d=" + seconds (l_fade))
				end
				if fade_ms > 0 and l_k < l_n - 1 then
					Result.append (",afade=t=out:st=" + seconds ((l_cut.span.duration - l_fade).max (0)) + ":d=" + seconds (l_fade))
				end
				Result.append ("[a" + l_k.out + "];")
				l_k := l_k + 1
			end
			from l_k := 0 until l_k >= l_n loop
				Result.append ("[v" + l_k.out + "][a" + l_k.out + "]")
				l_k := l_k + 1
			end
			Result.append ("concat=n=" + l_n.out + ":v=1:a=1[v][a]")
		ensure
			trims: occurrences (Result, "]trim=") = a_cuts.count and occurrences (Result, "]atrim=") = a_cuts.count
			one_concat: occurrences (Result, "concat=n=" + a_cuts.count.out) = 1
			fades_at_joints: fade_ms > 0 implies occurrences (Result, "afade=") = 2 * a_cuts.count - 2
		end

	arguments (a_input, a_script_path, a_output: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- Arguments after the ffmpeg executable.
		do
			create Result.make (24)
			across << "-hide_banner", "-y", "-i" >> as ic loop
				Result.extend (ic.to_string_32)
			end
			Result.extend (a_input.to_string_32)
			Result.extend ({STRING_32} "-filter_complex_script")
			Result.extend (a_script_path.to_string_32)
			across << "-map", "[v]", "-map", "[a]", "-c:v", "h264_nvenc", "-preset", "p5", "-cq", "19", "-c:a", "aac", "-b:a", "192k" >> as ic loop
				Result.extend (ic.to_string_32)
			end
			Result.extend (a_output.to_string_32)
		ensure
			output_last: not Result.is_empty implies Result.last.same_string_general (a_output)
		end

feature -- Formatting

	seconds (a_value: REAL_64): STRING_8
			-- `a_value' with exactly three decimals ("4.200").
		require
			non_negative: a_value >= 0
		local
			l_ms: INTEGER_64
			l_frac: STRING_8
		do
			l_ms := (a_value * 1000).rounded_real_64.truncated_to_integer_64
			l_frac := (l_ms \\ 1000).out
			from until l_frac.count >= 3 loop
				l_frac.prepend_character ('0')
			end
			Result := (l_ms // 1000).out + "." + l_frac
		ensure
			three_decimals: Result.count >= 5 and Result [Result.count - 3] = '.'
		end

feature -- Contract helpers

	occurrences (a_text, a_part: READABLE_STRING_8): INTEGER
			-- Non-overlapping occurrences of `a_part' in `a_text'.
		require
			part_present: not a_part.is_empty
		local
			i: INTEGER
		do
			from i := a_text.substring_index (a_part, 1) until i = 0 loop
				Result := Result + 1
				i := a_text.substring_index (a_part, i + a_part.count)
			end
		end

invariant
	fade_range: fade_ms >= 0 and fade_ms <= 200

end
