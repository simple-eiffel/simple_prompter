note
	description: "[
		Which frames of a take Publish looks at for its pictures (0.7.0): `Candidates' times spread
		evenly over the speech (3 seconds in from each end), the ffmpeg arguments that write one
		frame as a PNG, and the frame to use when nothing picks one (about 9 seconds in: the
		opening hook, where the speaker is usually most engaged).
	]"
	author: "Larry Rix"

class
	PT_FRAME_PLAN

create
	make

feature {NONE} -- Initialization

	make (a_start, a_end: REAL_64)
			-- Candidates between `a_start' and `a_end' seconds of the source video (the speech).
		require
			ordered: 0 <= a_start and a_start < a_end
		local
			l_from, l_to: REAL_64
			i: INTEGER
		do
			l_from := a_start + Margin_s
			l_to := a_end - Margin_s
			if l_to <= l_from then
				l_from := a_start
				l_to := a_end
			end
			create times.make (Candidates)
			from i := 0 until i >= Candidates loop
				times.extend (l_from + (l_to - l_from) * i / (Candidates - 1))
				i := i + 1
			end
			fallback_index := 1
			from i := 2 until i > times.count loop
				if (times [i] - (a_start + Fallback_s)).abs < (times [fallback_index] - (a_start + Fallback_s)).abs then
					fallback_index := i
				end
				i := i + 1
			end
		ensure
			all_candidates: times.count = Candidates
			first_inside: times.first >= a_start
			last_inside: times.last <= a_end
		end

feature -- Constants

	Candidates: INTEGER = 24
			-- Frames on the contact sheet (6 by 4).
	Margin_s: REAL_64 = 3.0
	Fallback_s: REAL_64 = 9.0

feature -- Access

	times: ARRAYED_LIST [REAL_64]
			-- The candidates' times in the source, in order.

	fallback_index: INTEGER
			-- The candidate nearest 9 seconds into the speech.

feature -- ffmpeg

	frame_arguments (a_source: READABLE_STRING_32; a_time: REAL_64; a_png: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- ffmpeg's arguments to write the frame of `a_source' at `a_time' seconds to `a_png'.
		require
			source_present: not a_source.is_empty
			png_present: not a_png.is_empty
			time_not_negative: a_time >= 0
		do
			create Result.make (12)
			across (<<"-hide_banner", "-v", "error", "-y", "-ss">>) as ic loop
				Result.extend (ic.to_string_32)
			end
			Result.extend (seconds (a_time))
			Result.extend ({STRING_32} "-i")
			Result.extend (a_source.to_string_32.twin)
			Result.extend ({STRING_32} "-frames:v")
			Result.extend ({STRING_32} "1")
			Result.extend (a_png.to_string_32.twin)
		ensure
			png_last: Result.last.same_string (a_png)
		end

feature {NONE} -- Implementation

	seconds (a_time: REAL_64): STRING_32
			-- `a_time' with millisecond precision, as ffmpeg reads it.
		do
			Result := ((a_time * 1000).rounded / 1000).out.to_string_32
		end

invariant
	fallback_valid: fallback_index >= 1 and fallback_index <= times.count

end
