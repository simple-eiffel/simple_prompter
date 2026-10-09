note
	description: "[
		Is the camera really sending a picture? Builds a short ffmpeg probe (`Probe_frames'
		frames through signalstats, nothing written) and reads its log into a verdict for the
		control window's Camera line.

		Measured on JACKJACK 2026-10-08 (ffmpeg dshow): with OBS closed, OBS Virtual Camera still
		delivers 1080p60 frames - OBS's "camera off" card - and they never change (YDIF = 0 on
		every frame, YAVG 55, YMAX 235), while the live FHD Camera in a dark room changes by ~1.4
		per frame from sensor noise alone (YAVG 18, YMAX 157). So frames arriving is not enough:
		the picture must move. A device another program holds fails with "Could not run graph
		(sometimes caused by a device already in use by other application)"; a missing one with
		"Could not find video device"; both then say "I/O error".
	]"
	author: "Larry Rix"

class
	PT_CAMERA_CHECK

create
	make

feature {NONE} -- Initialization

	make (a_devices: PT_DEVICE_CHOICE)
			-- A check of `a_devices'.camera, opened in the mode the recording will use.
		require
			has_camera: a_devices.has_camera
		do
			devices := a_devices
			create mode_text.make_empty
			verdict := Unchecked
		ensure
			devices_set: devices = a_devices
			unchecked: verdict = Unchecked
		end

feature -- Constants: verdicts

	Unchecked: INTEGER = 0
	Live: INTEGER = 1
			-- Frames arrive and the picture moves.
	Still: INTEGER = 2
			-- Frames arrive but never change (OBS's placeholder card, a frozen or still image).
	Black: INTEGER = 3
			-- Frames arrive but nothing on them is brighter than near-black.
	Busy: INTEGER = 4
			-- Another program holds the camera.
	Missing: INTEGER = 5
			-- No camera by that name.
	No_picture: INTEGER = 6
			-- Fewer than two frames arrived.

feature -- Constants: thresholds

	Probe_frames: INTEGER = 30
			-- Frames the probe reads (0.5 s at 60 fps, 1 s at 30).

	Motion_floor: REAL_64 = 0.05
			-- Largest frame-to-frame change (YDIF) below which the picture is still: OBS's card
			-- measured 0, a live webcam ~1.4.

	Black_peak: REAL_64 = 40.0
			-- Brightest pixel (YMAX) below which the picture is black.

	Dark_average: REAL_64 = 30.0
			-- Average brightness (YAVG, of 255) below which a live picture is called dark.

	Filters: STRING_32 = "signalstats,metadata=print:key=lavfi.signalstats.YDIF,metadata=print:key=lavfi.signalstats.YAVG,metadata=print:key=lavfi.signalstats.YMAX"
			-- Per frame: change from the last frame, average and brightest luma, printed to the log.

feature -- Access

	devices: PT_DEVICE_CHOICE

	verdict: INTEGER
			-- What the last `read' found.

	mode_text: STRING_32
			-- The camera's mode as ffmpeg opened it ("1920x1080, 60 fps"), empty if unknown.

	frames_seen: INTEGER
			-- Frames the last `read' found measured.

	motion: REAL_64
			-- Largest frame-to-frame change seen.

	brightness: REAL_64
			-- Average brightness of the last frame (0-255).

	peak: REAL_64
			-- Brightest pixel of the last frame (0-255).

	arguments: ARRAYED_LIST [STRING_32]
			-- Arguments after the ffmpeg executable: open the camera as the recording will, read
			-- `Probe_frames' frames, write nothing.
		do
			create Result.make (24)
			add (Result, <<"-hide_banner", "-f", "dshow", "-rtbufsize", "64M">>)
			if devices.uses_mjpeg then
				add (Result, <<"-vcodec", "mjpeg", "-video_size">>)
				Result.extend ((devices.width.out + "x" + devices.height.out).to_string_32)
				Result.extend ({STRING_32} "-framerate")
				Result.extend (devices.fps.out.to_string_32)
			end
			Result.extend ({STRING_32} "-i")
			Result.extend ({STRING_32} "video=" + devices.camera)
			Result.extend ({STRING_32} "-frames:v")
			Result.extend (Probe_frames.out.to_string_32)
			Result.extend ({STRING_32} "-vf")
			Result.extend (Filters.twin)
			add (Result, <<"-f", "null", "-">>)
		ensure
			dshow_input: has_pair (Result, "-f", "dshow")
			camera_input: has_pair (Result, "-i", {STRING_32} "video=" + devices.camera)
			recording_mode: devices.uses_mjpeg implies has_pair (Result, "-vcodec", "mjpeg")
			device_mode_otherwise: not devices.uses_mjpeg implies not has_pair (Result, "-vcodec", "mjpeg")
			frames_bounded: has_pair (Result, "-frames:v", Probe_frames.out)
			nothing_written: has_pair (Result, "-f", "null") and Result.last.same_string ("-")
		end

	summary: STRING_32
			-- One line for the control window.
		do
			Result := devices.camera.twin
			if not mode_text.is_empty then
				Result.append ({STRING_32} " (" + mode_text + {STRING_32} ")")
			end
			inspect verdict
			when Live then
				Result.append ({STRING_32} ": live")
				if is_dark then
					Result.append ({STRING_32} ", but dark (brightness " + brightness.rounded.out + {STRING_32} " of 255)")
				end
			when Still then
				if is_obs then
					Result.append ({STRING_32} ": picture not moving - OBS is closed, its Virtual Camera is stopped, or the scene has no live camera")
				else
					Result.append ({STRING_32} ": picture not moving (a frozen or still image)")
				end
			when Black then
				Result.append ({STRING_32} ": black picture")
			when Busy then
				Result.append ({STRING_32} ": another program is using it")
				if not is_obs then
					Result.append ({STRING_32} " (if OBS has the webcam, set camera = %"OBS Virtual Camera%")")
				end
			when Missing then
				Result.append ({STRING_32} ": not found")
			when No_picture then
				Result.append ({STRING_32} ": no picture arrived")
			else
				Result.append ({STRING_32} ": not checked yet")
			end
		ensure
			names_the_camera: Result.starts_with (devices.camera)
		end

feature -- Status

	is_live: BOOLEAN
		do
			Result := verdict = Live
		end

	is_dark: BOOLEAN
			-- Live, but dim?
		do
			Result := verdict = Live and brightness < Dark_average
		end

	is_obs: BOOLEAN
			-- Is the camera OBS's Virtual Camera?
		do
			Result := devices.camera.as_lower.has_substring ({STRING_32} "obs")
		end

	has_pair (a_args: LIST [STRING_32]; a_flag, a_value: READABLE_STRING_GENERAL): BOOLEAN
			-- Does `a_flag' appear immediately followed by `a_value'?
		local
			i: INTEGER
		do
			from i := 1 until Result or i >= a_args.count loop
				Result := a_args [i].same_string_general (a_flag) and a_args [i + 1].same_string_general (a_value)
				i := i + 1
			end
		end

feature -- Basic operations

	read (a_output: READABLE_STRING_GENERAL)
			-- Judge the probe from its whole log `a_output' (finished, or cut off by a timeout).
		local
			l_line: STRING_32
		do
			frames_seen := 0
			motion := 0.0
			brightness := 0.0
			peak := 0.0
			create mode_text.make_empty
			across a_output.to_string_32.split ('%N') as ic loop
				l_line := ic.twin
				l_line.prune_all ('%R')
				if mode_text.is_empty and l_line.has_substring ({STRING_32} "Video:") then
					mode_text := video_mode (l_line)
				end
				if l_line.has_substring ({STRING_32} "YDIF=") then
					motion := motion.max (value_after (l_line, {STRING_32} "YDIF="))
				elseif l_line.has_substring ({STRING_32} "YAVG=") then
					brightness := value_after (l_line, {STRING_32} "YAVG=")
					frames_seen := frames_seen + 1
				elseif l_line.has_substring ({STRING_32} "YMAX=") then
					peak := value_after (l_line, {STRING_32} "YMAX=")
				end
			end
			if a_output.to_string_32.as_lower.has_substring ({STRING_32} "other application") then
				verdict := Busy
			elseif a_output.to_string_32.as_lower.has_substring ({STRING_32} "could not find video device") then
				verdict := Missing
			elseif frames_seen < 2 then
				verdict := No_picture
			elseif motion < Motion_floor then
				verdict := Still
			elseif peak < Black_peak then
				verdict := Black
			else
				verdict := Live
			end
		ensure
			checked: verdict /= Unchecked
			live_moves: verdict = Live implies (motion >= Motion_floor and peak >= Black_peak and frames_seen >= 2)
			still_means_frames: verdict = Still implies frames_seen >= 2
		end

feature {NONE} -- Implementation

	video_mode (a_line: READABLE_STRING_32): STRING_32
			-- "WxH, N fps" from ffmpeg's stream line ("Stream #0:0: Video: rawvideo (NV12 / ...),
			-- nv12, 1920x1080, 60 fps, 60 tbr, ...").
		local
			l_size, l_fps, l_word: STRING_32
		do
			create l_size.make_empty
			create l_fps.make_empty
			across a_line.split (',') as ic loop
				l_word := ic.twin
				l_word.left_adjust
				l_word.right_adjust
				if l_word.has (' ') then
					if l_word.ends_with ({STRING_32} " fps") and l_fps.is_empty then
						l_fps := l_word
					end
					l_word := l_word.substring (1, l_word.index_of (' ', 1) - 1)
				end
				if l_size.is_empty and is_size (l_word) then
					l_size := l_word
				end
			end
			Result := l_size
			if not l_fps.is_empty then
				Result := (if Result.is_empty then l_fps else Result + {STRING_32} ", " + l_fps end)
			end
		end

	is_size (a_word: READABLE_STRING_32): BOOLEAN
			-- Is `a_word' digits, 'x', digits?
		local
			l_x: INTEGER
		do
			l_x := a_word.index_of ('x', 1)
			Result := l_x > 1 and l_x < a_word.count
				and then a_word.substring (1, l_x - 1).is_natural and then a_word.substring (l_x + 1, a_word.count).is_natural
		end

	value_after (a_line, a_key: READABLE_STRING_32): REAL_64
			-- The number after `a_key' in `a_line' (0 if none).
		local
			l_text: STRING_32
		do
			l_text := a_line.substring (a_line.substring_index (a_key, 1) + a_key.count, a_line.count)
			l_text.right_adjust
			if l_text.is_double then
				Result := l_text.to_double
			end
		end

	add (a_args: ARRAYED_LIST [STRING_32]; a_items: ARRAY [STRING_8])
		do
			across a_items as ic loop
				a_args.extend (ic.to_string_32)
			end
		ensure
			grown: a_args.count = old a_args.count + a_items.count
		end

invariant
	known_verdict: verdict >= Unchecked and verdict <= No_picture
	frames_non_negative: frames_seen >= 0

end
