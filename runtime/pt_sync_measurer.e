note
	description: "[
		Runs PT_SYNC_MEASURE on a recorded take (0.3.6): reads the microphone copy
		(tee.f32, 16 kHz float), finds the claps, and for each asks ffmpeg for
		1.2 s of the raw video around it as 64 x 36 gray frames at 60 a second
		(a scratch file in the take's analysis folder, deleted after). Blocks for
		about a second per clap tried.
	]"
	author: "Larry Rix"

class
	PT_SYNC_MEASURER

create
	make

feature {NONE} -- Initialization

	make (a_ffmpeg: READABLE_STRING_32)
		require
			ffmpeg_present: not a_ffmpeg.is_empty
		do
			ffmpeg := a_ffmpeg.to_string_32
			create measure.make
			create summary.make_empty
		end

feature -- Constants

	Frame_width: INTEGER = 64
	Frame_height: INTEGER = 36

feature -- Access

	ffmpeg: STRING_32
	measure: PT_SYNC_MEASURE
			-- The last measurement.
	summary: STRING_32
			-- What the last measurement found, for the panel.

feature -- Measuring

	run (a_raw, a_tee, a_work_dir: READABLE_STRING_32)
			-- Measure the take recorded in `a_raw' with microphone copy `a_tee'; scratch files in `a_work_dir'.
		require
			raw_present: not a_raw.is_empty
			tee_present: not a_tee.is_empty
		local
			l_samples: SPECIAL [REAL_32]
			l_frames: ARRAY [NATURAL_8]
			l_gray, l_line, l_out: STRING_32
			l_start: REAL_64
			l_size: INTEGER
			l_ok: BOOLEAN
		do
			create measure.make
			if not (create {SIMPLE_FILE}.make (a_tee)).exists or not (create {SIMPLE_FILE}.make (a_raw)).exists then
				summary := {STRING_32} "this take's recording files are missing"
			else
				l_samples := tee_samples (a_tee)
				measure.find_claps (l_samples, l_samples.count)
				if measure.claps.is_empty then
					summary := {STRING_32} "no clap found: clap sharply 2 or 3 times, hands in the picture"
				else
					l_size := Frame_width * Frame_height
					l_gray := a_work_dir + {STRING_32} "\sync_frames.gray"
					across measure.claps as ic loop
						l_start := (ic - measure.Frames_before_seconds).max (0.0)
						l_line := quoted (ffmpeg) + {STRING_32} " -hide_banner -loglevel error -y -ss " + seconds (l_start)
							+ {STRING_32} " -t " + seconds (measure.Frames_seconds) + {STRING_32} " -i " + quoted (a_raw)
							+ {STRING_32} " -an -vf scale=" + Frame_width.out + {STRING_32} ":" + Frame_height.out
							+ {STRING_32} ",format=gray -r " + measure.Frame_rate.out + {STRING_32} " -fps_mode cfr -f rawvideo " + quoted (l_gray)
						l_out := (create {SIMPLE_PROCESS}.make).command_output (l_line)
						if (create {SIMPLE_FILE}.make (l_gray)).exists then
							l_frames := (create {SIMPLE_FILE}.make (l_gray)).binary_content
							if l_frames.count >= 2 * l_size then
								measure.add_clap_frames (ic, l_start, l_frames.area, l_size, l_frames.count // l_size)
							end
						end
					end
					l_ok := (create {SIMPLE_FILE}.make (l_gray)).delete
					if measure.is_found then
						summary := {STRING_32} "measured " + measure.delay_ms.out + {STRING_32} " ms from " + measure.delays.count.out
							+ (if measure.delays.count = 1 then {STRING_32} " clap" else {STRING_32} " claps" end)
					else
						summary := {STRING_32} "heard " + measure.claps.count.out + {STRING_32} " sharp sounds but saw no hands meet: clap with your hands in the picture"
					end
				end
			end
		end

feature {NONE} -- Implementation

	tee_samples (a_tee: READABLE_STRING_32): SPECIAL [REAL_32]
			-- The 32-bit little-endian float samples of `a_tee'.
		local
			l_bytes: ARRAY [NATURAL_8]
			l_mp: MANAGED_POINTER
			i, l_n: INTEGER
		do
			l_bytes := (create {SIMPLE_FILE}.make (a_tee)).binary_content
			l_n := l_bytes.count // 4
			create Result.make_filled (0.0, l_n.max (1))
			if l_n > 0 then
				create l_mp.make (l_n * 4)
				from i := 0 until i >= l_n * 4 loop
					l_mp.put_natural_8 (l_bytes.area [i], i)
					i := i + 1
				end
				from i := 0 until i >= l_n loop
					Result [i] := l_mp.read_real_32_le (i * 4)
					i := i + 1
				end
			end
		ensure
			one_per_four_bytes: Result.count >= 1
		end

	seconds (a_value: REAL_64): STRING_32
			-- `a_value' with three decimals ("1.200").
		require
			non_negative: a_value >= 0
		local
			l_ms: INTEGER
			l_frac: STRING_32
		do
			l_ms := (a_value * 1000).rounded
			l_frac := (l_ms \\ 1000).out.to_string_32
			from until l_frac.count >= 3 loop
				l_frac.prepend_character ('0')
			end
			Result := (l_ms // 1000).out.to_string_32 + {STRING_32} "." + l_frac
		end

	quoted (a_text: READABLE_STRING_32): STRING_32
		do
			Result := {STRING_32} "%"" + a_text + {STRING_32} "%""
		end

end
