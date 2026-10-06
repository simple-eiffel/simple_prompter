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
