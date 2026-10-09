note
	description: "[
		Is the recording getting video? Reads ffmpeg's `-progress pipe:2' output as it arrives
		(PT_CAPTURE_PLAN asks for it): blocks of key=value lines about every 0.5 s - frame=,
		fps=, dup_frames=, drop_frames=, progress=continue (measured 2026-10-08 on the OBS
		Virtual Camera recording command). Text arrives in arbitrary chunks, so an unfinished
		last line waits for the next `feed'. The video has stalled when the frame count has not
		grown for `Stall_ms', or no first frame came within `First_frame_ms'. Time is passed in,
		so this is pure.
	]"
	author: "Larry Rix"

class
	PT_CAPTURE_PROGRESS

create
	make

feature {NONE} -- Initialization

	make
		do
			create pending.make_empty
		ensure
			not_started: not has_started
			no_frames: frames = 0
		end

feature -- Constants

	First_frame_ms: REAL_64 = 5000.0
			-- How long a recording may take to deliver its first frame (OBS Virtual Camera +
			-- NVENC delivered frame 47 at 0.7 s in the 2026-10-08 measurement).

	Stall_ms: REAL_64 = 1500.0
			-- No new frame for this long: the video has stopped (three missed progress blocks).

	Pending_limit: INTEGER = 65_536
			-- An unfinished line longer than this is dropped (ffmpeg's lines are short).

feature -- Access

	frames: INTEGER
			-- Video frames written so far.

	fps: REAL_64
			-- ffmpeg's running frame rate.

	dropped, duplicated: INTEGER
			-- Frames ffmpeg dropped or duplicated to keep the output rate.

	started_ms: REAL_64
			-- When the recording started.

	last_frame_ms: REAL_64
			-- When the frame count last grew (`started_ms' until the first frame).

	summary (a_now_ms: REAL_64): STRING_32
			-- One line for the control window.
		require
			started: has_started
		do
			if frames = 0 then
				Result := {STRING_32} "no frames yet (" + seconds_text (a_now_ms - started_ms) + {STRING_32} ")"
			elseif is_stalled (a_now_ms) then
				Result := {STRING_32} "STOPPED " + seconds_text (a_now_ms - last_frame_ms) + {STRING_32} " ago at frame " + frames.out
			else
				Result := frames.out.to_string_32 + {STRING_32} " frames, " + fps.rounded.out + {STRING_32} " fps"
			end
			if dropped > 0 or duplicated > 0 then
				Result.append ({STRING_32} ", " + dropped.out + {STRING_32} " dropped, " + duplicated.out + {STRING_32} " duplicated")
			end
		end

feature -- Status

	has_started: BOOLEAN
			-- Is a recording being followed?

	is_stalled (a_now_ms: REAL_64): BOOLEAN
			-- Has the video stopped (or never started)?
		do
			if has_started then
				if frames = 0 then
					Result := a_now_ms - started_ms > First_frame_ms
				else
					Result := a_now_ms - last_frame_ms > Stall_ms
				end
			end
		ensure
			only_while_started: Result implies has_started
		end

feature -- Element change

	restart (a_now_ms: REAL_64)
			-- A recording starts at `a_now_ms'.
		do
			frames := 0
			fps := 0.0
			dropped := 0
			duplicated := 0
			pending.wipe_out
			started_ms := a_now_ms
			last_frame_ms := a_now_ms
			has_started := True
		ensure
			started: has_started
			fresh: frames = 0 and dropped = 0 and duplicated = 0
			clock_set: started_ms = a_now_ms and last_frame_ms = a_now_ms
		end

	stop
			-- The recording ended.
		do
			has_started := False
		ensure
			stopped: not has_started
		end

	feed (a_text: READABLE_STRING_GENERAL; a_now_ms: REAL_64)
			-- Take more of ffmpeg's output, received at `a_now_ms'.
		require
			started: has_started
			time_forward: a_now_ms >= last_frame_ms
		local
			l_end: INTEGER
			l_line: STRING_32
		do
			pending.append_string_general (a_text)
			from
				l_end := pending.index_of ('%N', 1)
			until
				l_end = 0
			loop
				l_line := pending.substring (1, l_end - 1)
				l_line.prune_all ('%R')
				take_line (l_line, a_now_ms)
				pending.remove_head (l_end)
				l_end := pending.index_of ('%N', 1)
			end
			if pending.count > Pending_limit then
				pending.wipe_out
			end
		ensure
			frames_never_fall: frames >= old frames
			growth_is_timed: frames > old frames implies last_frame_ms = a_now_ms
		end

feature {NONE} -- Implementation

	pending: STRING_32
			-- Text after the last complete line.

	take_line (a_line: STRING_32; a_now_ms: REAL_64)
			-- One key=value line; anything else is ignored.
		local
			l_eq: INTEGER
			l_key, l_value: STRING_32
		do
			l_eq := a_line.index_of ('=', 1)
			if l_eq > 1 then
				l_key := a_line.substring (1, l_eq - 1)
				l_value := a_line.substring (l_eq + 1, a_line.count)
				l_value.left_adjust
				l_value.right_adjust
				if l_key.same_string ({STRING_32} "frame") and l_value.is_integer then
					if l_value.to_integer > frames then
						frames := l_value.to_integer
						last_frame_ms := a_now_ms
					end
				elseif l_key.same_string ({STRING_32} "fps") and l_value.is_double then
					fps := l_value.to_double.max (0.0)
				elseif l_key.same_string ({STRING_32} "drop_frames") and l_value.is_integer then
					dropped := l_value.to_integer.max (0)
				elseif l_key.same_string ({STRING_32} "dup_frames") and l_value.is_integer then
					duplicated := l_value.to_integer.max (0)
				end
			end
		ensure
			frames_never_fall: frames >= old frames
		end

	seconds_text (a_ms: REAL_64): STRING_32
			-- "2.4 s", from whole tenths (REAL_64.out can print 1.6000000000000001).
		local
			l_tenths: INTEGER
		do
			l_tenths := (a_ms / 100).rounded.max (0)
			Result := (l_tenths // 10).out.to_string_32 + {STRING_32} "." + (l_tenths \\ 10).out.to_string_32 + {STRING_32} " s"
		end

invariant
	counts_non_negative: frames >= 0 and dropped >= 0 and duplicated >= 0
	fps_non_negative: fps >= 0.0
	frame_after_start: last_frame_ms >= started_ms

end
