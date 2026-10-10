note
	description: "Output and record clusters: timecodes, captions, review.srt, EDL, codecs, capture and render plans, preflight."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_OUTPUTS

inherit
	PT_TEST_SET

feature -- Tests: timecodes

	test_srt_and_vtt
		local
			t: PT_TIMECODE
		do
			create t
			assert_true ("srt", t.srt (102.31).same_string ("00:01:42,310"))
			assert_true ("vtt", t.vtt (102.31).same_string ("00:01:42.310"))
			assert_reals_equal ("parse back", 102.31, t.seconds_of_srt ("00:01:42,310"), 0.0005)
		end

	test_chapter_and_edl
		local
			t: PT_TIMECODE
		do
			create t
			assert_true ("start", t.chapter (0.4).same_string ("0:00"))
			assert_true ("minutes", t.chapter (185.9).same_string ("3:05"))
			assert_true ("hours", t.chapter (3723.0).same_string ("1:02:03"))
			assert_true ("edl 30 fps", t.edl (4.2, 30).same_string ("00:00:04:06"))
		end

feature -- Tests: writers (Phase 4 behavior)

	test_review_srt_one_cue_per_mark
		local
			w: PT_REVIEW_SRT_WRITER
			j: PT_JOURNAL
		do
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_resume (1.0, id (1), 1))
			j.append (create {PT_TAKE_EVENT}.make_flub (6.0, id (9), "clicker"))
			j.append (create {PT_TAKE_EVENT}.make_hold (9.0, "hotkey"))
			create w.make
			assert_integers_equal ("two shown marks", 2, w.shown_count (j))
			assert_integers_equal ("two cues", 2, w.cue_count (w.text (j, history_of (moody))))
		end

	test_edl_has_one_event_per_cut
		local
			w: PT_EDL_WRITER
			l: PT_CUT_LIST
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 4.2), <<id (1)>>, 1, 1, 1, False))
			l.extend (create {PT_CUT}.make (0, span (9.5, 17.0), <<id (2)>>, 2, 2, 2, False))
			create w.make
			assert_integers_equal ("two events", 2, w.event_lines (w.write (l, 30, "episode-12", "RAW")))
		end

	test_render_plan_follows_the_spike_recipe
		local
			p: PT_RENDER_PLAN
			l: PT_CUT_LIST
			g: STRING_8
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 4.2), <<id (1)>>, 1, 1, 1, False))
			l.extend (create {PT_CUT}.make (0, span (9.5, 17.0), <<id (2)>>, 2, 2, 2, False))
			l.extend (create {PT_CUT}.make (0, span (21.3, 30.0), <<id (3)>>, 3, 3, 3, False))
			create p.make ({STRING_32} "ffmpeg", 20, False)
			g := p.filter_script (l)
			assert_integers_equal ("three trims", 3, p.occurrences (g, "]trim="))
			assert_integers_equal ("one concat", 1, p.occurrences (g, "concat=n=3"))
			assert_integers_equal ("sound from the one input", 3, p.occurrences (g, "[0:a]atrim="))
			assert_false ("one input", across p.arguments ({STRING_32} "raw.mkv", {STRING_32} "f", {STRING_32} "o.mp4") as ic some ic.same_string ({STRING_32} "-itsoffset") end)
		end

	test_render_plan_moves_the_picture_by_the_sync
			-- 0.3.6: the picture input's times moved back by the sync; the sound from a second, untouched input.
		local
			p: PT_RENDER_PLAN
			l: PT_CUT_LIST
			a: ARRAYED_LIST [STRING_32]
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (2.0, 4.2), <<id (1)>>, 1, 1, 1, False))
			l.extend (create {PT_CUT}.make (0, span (9.5, 17.0), <<id (2)>>, 2, 2, 2, False))
			create p.make ({STRING_32} "ffmpeg", 20, False)
			p.set_video_delay (110)
			a := p.arguments ({STRING_32} "raw.mkv", {STRING_32} "f", {STRING_32} "o.mp4")
			assert_true ("picture moved back", p.has_pair (a, "-itsoffset", "-0.110"))
			assert_true ("then the picture input", p.has_pair (a, "-0.110", "-i"))
			assert_true ("exact order", a [1].same_string ({STRING_32} "-hide_banner") and a [2].same_string ({STRING_32} "-y")
				and a [3].same_string ({STRING_32} "-itsoffset") and a [5].same_string ({STRING_32} "-i") and a [6].same_string ({STRING_32} "raw.mkv")
				and a [7].same_string ({STRING_32} "-i") and a [8].same_string ({STRING_32} "raw.mkv"))
			assert_integers_equal ("raw opened twice", 2, count_of (a, {STRING_32} "raw.mkv"))
			assert_integers_equal ("sound from the second input", 2, p.occurrences (p.filter_script (l), "[1:a]atrim="))
			assert_integers_equal ("picture from the first", 2, p.occurrences (p.filter_script (l), "[0:v]trim="))
			p.set_video_delay (-40)
			assert_true ("picture ahead: moved later", p.has_pair (p.arguments ({STRING_32} "raw.mkv", {STRING_32} "f", {STRING_32} "o.mp4"), "-itsoffset", "0.040"))
			assert_true ("signed seconds", p.signed_seconds (-1250).same_string ("-1.250"))
		end

	count_of (a_list: ARRAYED_LIST [STRING_32]; a_item: STRING_32): INTEGER
		do
			across a_list as ic loop
				if ic.same_string (a_item) then
					Result := Result + 1
				end
			end
		end

	test_cut_codec_round_trip
		local
			k: PT_CUT_CODEC
			l: PT_CUT_LIST
		do
			create l.make
			l.extend (create {PT_CUT}.make (0, span (2.18, 101.95), <<id (1), id (2)>>, 1, 2, 1, False))
			create k.make
			k.decode (k.encode (l))
			assert_true ("decoded", k.has_cuts)
			assert_integers_equal ("one cut", 1, k.last_cuts.count)
		end

feature -- Tests: capture plan and preflight

	test_capture_plan_recording_arguments
		local
			p: PT_CAPTURE_PLAN
		do
			create p.make_recording ({STRING_32} "ffmpeg", create {PT_DEVICE_CHOICE}.make_default,
				{STRING_32} "s\raw.mkv", {STRING_32} "s\tee.f32")
			assert_true ("mjpeg", p.has_pair (p.arguments, "-vcodec", "mjpeg"))
			assert_true ("nvenc", p.has_pair (p.arguments, "-c:v", "h264_nvenc"))
			assert_true ("pcm", p.has_pair (p.arguments, "-c:a", "pcm_s16le"))
			assert_true ("tee flushed", p.has_pair (p.arguments, "-flush_packets", "1"))
			assert_true ("tee last", p.arguments.last.same_string ({STRING_32} "s\tee.f32"))
		end

	test_capture_plan_sets_a_small_audio_buffer
			-- Review H6.
		local
			p: PT_CAPTURE_PLAN
		do
			create p.make_audio_only ({STRING_32} "ffmpeg", create {PT_DEVICE_CHOICE}.make_default, {STRING_32} "s	ee.f32")
			assert_true ("50 ms buffer", p.has_pair (p.arguments, "-audio_buffer_size", "50"))
		end

	test_capture_plan_practice_is_audio_only
		local
			p: PT_CAPTURE_PLAN
		do
			create p.make_audio_only ({STRING_32} "ffmpeg", create {PT_DEVICE_CHOICE}.make_default, {STRING_32} "s\tee.f32")
			assert_false ("no video encode", p.has_pair (p.arguments, "-c:v", "h264_nvenc"))
			assert_true ("16 kHz tee", p.has_pair (p.arguments, "-ar", "16000"))
		end

	test_webcam_is_recorded_as_mjpeg
			-- FHD Camera's listing (ffmpeg -list_options, 2026-10-07) offers MJPEG at 1080p.
		local
			d: PT_DEVICE_CHOICE
			p: PT_CAPTURE_PLAN
		do
			d := (create {PT_DEVICE_PROBE}).choice (Webcam_listing, {STRING_32} "FHD Camera", {STRING_32} "Mic")
			assert_true ("mjpeg chosen", d.uses_mjpeg)
			create p.make_recording ({STRING_32} "ffmpeg", d, {STRING_32} "raw.mkv", {STRING_32} "tee.f32")
			assert_true ("mjpeg asked", p.has_pair (p.arguments, "-vcodec", "mjpeg"))
			assert_true ("size asked", p.has_pair (p.arguments, "-video_size", "1920x1080"))
			assert_true ("one input", p.has_pair (p.arguments, "-i", "video=FHD Camera:audio=Mic"))
			assert_false ("no second input", p.has_pair (p.arguments, "-map", "1:a"))
		end

	test_obs_virtual_camera_uses_its_own_mode
			-- OBS Virtual Camera's listing (OBS 32, 2026-10-07): raw 1080p60 only, no MJPEG.
		local
			d: PT_DEVICE_CHOICE
			p: PT_CAPTURE_PLAN
		do
			d := (create {PT_DEVICE_PROBE}).choice (Obs_listing, {STRING_32} "OBS Virtual Camera", {STRING_32} "Mic")
			assert_false ("no mjpeg", d.uses_mjpeg)
			create p.make_recording ({STRING_32} "ffmpeg", d, {STRING_32} "raw.mkv", {STRING_32} "tee.f32")
			assert_false ("no mjpeg asked", p.has_pair (p.arguments, "-vcodec", "mjpeg"))
			assert_false ("no size forced", p.has_pair (p.arguments, "-video_size", "1920x1080"))
			assert_true ("still nvenc", p.has_pair (p.arguments, "-c:v", "h264_nvenc"))
				-- One input on one clock (0.3.5): two inputs each started at 0 and the picture ran
				-- 0.35 s behind the sound (clap test, 2026-10-10).
			assert_true ("one input", p.has_pair (p.arguments, "-i", "video=OBS Virtual Camera:audio=Mic"))
			assert_true ("frames on the capture clock", p.has_pair (p.arguments, "-use_video_device_timestamps", "0"))
			assert_true ("audio from the one input", p.has_pair (p.arguments, "-map", "0:a"))
			assert_false ("no second input", p.has_pair (p.arguments, "-map", "1:a"))
			assert_false ("picture as it arrived", across p.arguments as ic some ic.same_string ({STRING_32} "-vf") end)
		end

	test_empty_listing_uses_device_mode
			-- ffmpeg missing or the camera gone: nothing to match, so nothing is forced.
		do
			assert_false ("device mode", (create {PT_DEVICE_PROBE}).choice ("", {STRING_32} "X", {STRING_32} "Mic").uses_mjpeg)
		end

	Webcam_listing: STRING_32 = "[
[dshow @ 0000] DirectShow video device options (from video devices)
[dshow @ 0000]  Pin "Capture" (alternative pin name "0")
[dshow @ 0000]   vcodec=mjpeg  min s=1920x1080 fps=5 max s=1920x1080 fps=60.0002
[dshow @ 0000]   pixel_format=yuyv422  min s=1920x1080 fps=5 max s=1920x1080 fps=5
]"

	Obs_listing: STRING_32 = "[
[dshow @ 0000] DirectShow video device options (from video devices)
[dshow @ 0000]  Pin "Video" (alternative pin name "0")
[dshow @ 0000]   pixel_format=nv12  min s=1920x1080 fps=60.0002 max s=1920x1080 fps=60.0002
[dshow @ 0000]   pixel_format=yuv420p  min s=1920x1080 fps=60.0002 max s=1920x1080 fps=60.0002
[dshow @ 0000]   pixel_format=yuyv422  min s=1920x1080 fps=60.0002 max s=1920x1080 fps=60.0002
]"

	test_preflight_disk_check
		local
			f: PT_PREFLIGHT
		do
			create f.make
				-- 12 Mbps for 10 minutes + 10 minutes margin needs 1.8 GB.
			f.check_ready (True, True, False, False, 1_000_000_000, 12_000_000, 10)
			assert_false ("1 GB is not enough", f.is_ready)
			f.check_ready (True, True, False, False, 5_000_000_000, 12_000_000, 10)
			assert_true ("5 GB is enough", f.is_ready)
		end

end
