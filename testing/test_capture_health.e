note
	description: "[
		Camera and recording health (2026-10-08): PT_CAMERA_CHECK judges a camera probe's log,
		PT_CAPTURE_PROGRESS follows a recording's -progress output. The logs below are ffmpeg's
		own output, captured on JACKJACK 2026-10-08 (trimmed to the lines that matter).
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_CAPTURE_HEALTH

inherit
	PT_TEST_SET

feature -- Tests: camera check

	test_obs_placeholder_is_still
			-- OBS closed: the Virtual Camera sends its "camera off" card, frames never change.
		local
			c: PT_CAMERA_CHECK
		do
			c := obs_check
			c.read (Obs_placeholder_log)
			assert_integers_equal ("still", {PT_CAMERA_CHECK}.Still, c.verdict)
			assert_integers_equal ("three frames measured", 3, c.frames_seen)
			assert_true ("mode", c.mode_text.same_string ({STRING_32} "1920x1080, 60 fps"))
			assert_true ("names OBS as the cause", c.summary.has_substring ({STRING_32} "OBS is closed"))
			assert_false ("not live", c.is_live)
		end

	test_live_webcam_in_a_dark_room
			-- The FHD Camera with nobody moving: sensor noise alone moves the picture.
		local
			c: PT_CAMERA_CHECK
		do
			c := webcam_check
			c.read (Webcam_log)
			assert_integers_equal ("live", {PT_CAMERA_CHECK}.Live, c.verdict)
			assert_true ("mode, past the comma inside the parentheses", c.mode_text.same_string ({STRING_32} "1280x720, 60 fps"))
			assert_reals_equal ("largest change", 1.63982, c.motion, 0.00001)
			assert_true ("dark", c.is_dark)
			assert_true ("says dark", c.summary.has_substring ({STRING_32} "live, but dark (brightness 19 of 255)"))
		end

	test_busy_camera_is_not_called_missing
			-- Both errors end in "I/O error"; the busy one names the other application.
		local
			c: PT_CAMERA_CHECK
		do
			c := webcam_check
			c.read (Busy_log)
			assert_integers_equal ("busy", {PT_CAMERA_CHECK}.Busy, c.verdict)
			assert_true ("points at OBS", c.summary.has_substring ({STRING_32} "OBS Virtual Camera"))
		end

	test_missing_camera
		local
			c: PT_CAMERA_CHECK
		do
			c := webcam_check
			c.read (Missing_log)
			assert_integers_equal ("missing", {PT_CAMERA_CHECK}.Missing, c.verdict)
			assert_true ("says so", c.summary.ends_with ({STRING_32} ": not found"))
		end

	test_no_frames_is_no_picture
			-- The probe timed out after opening the device: no measured frame.
		local
			c: PT_CAMERA_CHECK
		do
			c := obs_check
			c.read ("  Stream #0:0: Video: rawvideo (NV12 / 0x3231564E), nv12, 1920x1080, 60 fps, 60 tbr%N")
			assert_integers_equal ("no picture", {PT_CAMERA_CHECK}.No_picture, c.verdict)
			c.read ("")
			assert_integers_equal ("empty log", {PT_CAMERA_CHECK}.No_picture, c.verdict)
		end

	test_black_picture
			-- Frames move (noise) but nothing is brighter than near-black: a covered lens.
		local
			c: PT_CAMERA_CHECK
		do
			c := webcam_check
			c.read ("lavfi.signalstats.YDIF=0%Nlavfi.signalstats.YAVG=3%Nlavfi.signalstats.YMAX=21%N"
				+ "lavfi.signalstats.YDIF=0.4%Nlavfi.signalstats.YAVG=3%Nlavfi.signalstats.YMAX=22%N")
			assert_integers_equal ("black", {PT_CAMERA_CHECK}.Black, c.verdict)
		end

	test_probe_opens_the_camera_as_the_recording_will
		local
			c: PT_CAMERA_CHECK
		do
			c := webcam_check
			assert_true ("mjpeg", c.has_pair (c.arguments, "-vcodec", "mjpeg"))
			assert_true ("1080p", c.has_pair (c.arguments, "-video_size", "1920x1080"))
			assert_true ("camera only", c.has_pair (c.arguments, "-i", "video=FHD Camera"))
			c := obs_check
			assert_false ("device mode", c.has_pair (c.arguments, "-vcodec", "mjpeg"))
			assert_true ("vcam", c.has_pair (c.arguments, "-i", "video=OBS Virtual Camera"))
			assert_true ("writes nothing", c.arguments.last.same_string ("-"))
			assert_true ("unchecked at first", c.summary.ends_with ({STRING_32} "not checked yet"))
		end

feature -- Tests: recording progress

	test_progress_counts_frames_across_chunks
			-- A chunk can end in the middle of a line.
		local
			p: PT_CAPTURE_PROGRESS
		do
			create p.make
			p.restart (1000.0)
			p.feed ("frame=4", 1500.0)
			assert_integers_equal ("unfinished line waits", 0, p.frames)
			p.feed ("7%Nfps=0.00%Ndrop_frames=0%Nprogress=continue%N", 1600.0)
			assert_integers_equal ("47", 47, p.frames)
			assert_reals_equal ("frame time", 1600.0, p.last_frame_ms, 0.0)
			p.feed (Progress_block, 2100.0)
			assert_integers_equal ("78", 78, p.frames)
			assert_reals_equal ("fps", 76.4, p.fps, 0.001)
			assert_false ("flowing", p.is_stalled (2200.0))
			assert_true ("summary", p.summary (2200.0).same_string ({STRING_32} "78 frames, 76 fps"))
		end

	test_progress_stalls_when_frames_stop
			-- Audio keeps the blocks coming; the frame count does not grow.
		local
			p: PT_CAPTURE_PROGRESS
		do
			create p.make
			p.restart (0.0)
			p.feed (Progress_block, 1000.0)
			p.feed (Progress_block, 1500.0)
			p.feed (Progress_block, 2000.0)
			assert_reals_equal ("last growth", 1000.0, p.last_frame_ms, 0.0)
			assert_false ("1.5 s is the limit", p.is_stalled (2500.0))
			assert_true ("stalled after", p.is_stalled (2600.0))
			assert_true ("says stopped", p.summary (2600.0).starts_with ({STRING_32} "STOPPED 1.6 s ago at frame 78"))
		end

	test_progress_waits_for_the_first_frame
		local
			p: PT_CAPTURE_PROGRESS
		do
			create p.make
			assert_false ("not started, never stalled", p.is_stalled (99_999.0))
			p.restart (0.0)
			assert_false ("grace", p.is_stalled (5000.0))
			assert_true ("no first frame", p.is_stalled (5001.0))
			assert_true ("says so", p.summary (5001.0).starts_with ({STRING_32} "no frames yet"))
			p.stop
			assert_false ("stopped", p.is_stalled (9000.0))
		end

	test_progress_reports_drops
		local
			p: PT_CAPTURE_PROGRESS
		do
			create p.make
			p.restart (0.0)
			p.feed ("frame=300%R%Nfps=59.9%R%Ndup_frames=2%R%Ndrop_frames=5%R%N", 100.0)
			assert_integers_equal ("crlf ok", 300, p.frames)
			assert_integers_equal ("dropped", 5, p.dropped)
			assert_integers_equal ("duplicated", 2, p.duplicated)
			assert_true ("shown", p.summary (100.0).has_substring ({STRING_32} "5 dropped, 2 duplicated"))
		end

feature {NONE} -- Fixtures

	obs_check: PT_CAMERA_CHECK
		do
			create Result.make (create {PT_DEVICE_CHOICE}.make_device_mode ({STRING_32} "OBS Virtual Camera", {STRING_32} "Mic"))
		end

	webcam_check: PT_CAMERA_CHECK
		do
			create Result.make (create {PT_DEVICE_CHOICE}.make ({STRING_32} "FHD Camera", {STRING_32} "Mic", 1920, 1080, 30))
		end

	Obs_placeholder_log: STRING_32 = "[
Input #0, dshow, from 'video=OBS Virtual Camera':
  Duration: N/A, start: 141393.222000, bitrate: N/A
  Stream #0:0: Video: rawvideo (NV12 / 0x3231564E), nv12, 1920x1080, 60 fps, 60 tbr, 10000k tbn, start 141393.222000
[Parsed_metadata_1 @ 000001] lavfi.signalstats.YDIF=0
[Parsed_metadata_2 @ 000002] lavfi.signalstats.YAVG=55.2125
[Parsed_metadata_3 @ 000003] lavfi.signalstats.YMAX=235
[Parsed_metadata_1 @ 000001] lavfi.signalstats.YDIF=0
[Parsed_metadata_2 @ 000002] lavfi.signalstats.YAVG=55.2125
[Parsed_metadata_3 @ 000003] lavfi.signalstats.YMAX=235
[Parsed_metadata_1 @ 000001] lavfi.signalstats.YDIF=0
[Parsed_metadata_2 @ 000002] lavfi.signalstats.YAVG=55.2125
[Parsed_metadata_3 @ 000003] lavfi.signalstats.YMAX=235
]"

	Webcam_log: STRING_32 = "[
Input #0, dshow, from 'video=FHD Camera':
  Stream #0:0: Video: mjpeg (Baseline) (MJPG / 0x47504A4D), yuvj422p(pc, bt470bg/bt709/unknown), 1280x720, 60 fps, 60 tbr, 10000k tbn, start 70731.102581
[Parsed_metadata_1 @ 000001] lavfi.signalstats.YDIF=0
[Parsed_metadata_2 @ 000002] lavfi.signalstats.YAVG=18.8839
[Parsed_metadata_3 @ 000003] lavfi.signalstats.YMAX=157
[Parsed_metadata_1 @ 000001] lavfi.signalstats.YDIF=1.63982
[Parsed_metadata_2 @ 000002] lavfi.signalstats.YAVG=18.8629
[Parsed_metadata_3 @ 000003] lavfi.signalstats.YMAX=157
[Parsed_metadata_1 @ 000001] lavfi.signalstats.YDIF=1.37363
[Parsed_metadata_2 @ 000002] lavfi.signalstats.YAVG=18.8629
[Parsed_metadata_3 @ 000003] lavfi.signalstats.YMAX=157
]"

	Busy_log: STRING_32 = "[
[dshow @ 000001ee0b315840] Could not run graph (sometimes caused by a device already in use by other application)
[in#0 @ 000001ee0b3155c0] Error opening input: I/O error
Error opening input file video=FHD Camera.
Error opening input files: I/O error
]"

	Missing_log: STRING_32 = "[
[dshow @ 0000019cfc3a5140] Could not find video device with name [No Such Cam] among source devices of type video.
[in#0 @ 0000019cfc3a4ec0] Error opening input: I/O error
Error opening input file video=No Such Cam.
]"

	Progress_block: STRING_32 = "[
frame=78
fps=76.40
stream_0_0_q=11.0
bitrate=1937.5kbits/s
total_size=302739
out_time_us=1249995
dup_frames=0
drop_frames=0
speed=1.22x
progress=continue

]"

end
