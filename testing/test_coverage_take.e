note
	description: "[
		Phase 5 coverage: take studio, configuration, recording and the facade. Every
		exported feature the earlier tests did not exercise, checked against its contract
		and its documented behavior (spec 07, intent-v2).
	]"
	author: "Larry Rix"

class
	TEST_COVERAGE_TAKE

inherit
	PT_TEST_SET

feature -- Session folder

	test_session_folder_paths
		local
			f: PT_SESSION_FOLDER
		do
			create f.make ({STRING_32} "C:\Videos\simple_prompter\2026-10-05.take")
			assert_true ("root", f.root.same_string ({STRING_32} "C:\Videos\simple_prompter\2026-10-05.take"))
			assert_true ("raw", f.raw_path.same_string (f.root + {STRING_32} "\raw.mkv"))
			assert_true ("tee", f.tee_path.same_string (f.root + {STRING_32} "\tee.f32"))
			assert_true ("journal", f.journal_path.same_string (f.root + {STRING_32} "\journal.jsonl"))
			assert_true ("settings", f.session_settings_path.same_string (f.root + {STRING_32} "\session.toml"))
			assert_true ("review", f.review_srt_path.same_string (f.root + {STRING_32} "\review.srt"))
			assert_true ("cuts", f.cut_path.same_string (f.root + {STRING_32} "\cut.json"))
			assert_true ("script dir", f.script_dir.same_string (f.root + {STRING_32} "\script"))
			assert_true ("analysis dir", f.analysis_dir.same_string (f.root + {STRING_32} "\analysis"))
			assert_true ("out dir", f.out_dir.same_string (f.root + {STRING_32} "\out"))
			assert_true ("revision file", f.revision_path (3).same_string (f.script_dir + {STRING_32} "\r3.md"))
			assert_refused ("trailing separator refused", agent new_folder ({STRING_32} "C:\x\"))
			assert_refused ("revision 0 refused", agent f.revision_path (0))
		end

feature -- Recorder health

	test_recorder_health
		local
			h: PT_RECORDER_HEALTH
		do
			create h.make (True, 64_000.0, 0.0, Void)
			assert_true ("alive", h.is_alive)
			assert_false ("flowing", h.is_stalled)
			assert_false ("no drops", h.needs_drop_warning)
			assert_true ("no error", h.last_error = Void)
			create h.make (True, 1_000.0, 0.01, {STRING_32} "dshow buffer overrun")
			assert_true ("stalled below half the expected rate", h.is_stalled)
			assert_true ("drops above half a percent", h.needs_drop_warning)
			assert_true ("error kept", attached h.last_error as al_e and then al_e.has_substring ({STRING_32} "overrun"))
			assert_true ("rates kept", h.tee_bytes_per_s = 1_000.0 and h.drop_ratio = 0.01)
			create h.make (False, 0.0, 0.0, Void)
			assert_false ("a dead recorder is not stalled", h.is_stalled)
			assert_true ("thresholds", h.Expected_bytes_per_s = 64_000.0 and h.Drop_warning = 0.005)
			assert_refused ("drop ratio above 1 refused", agent new_health (1.5))
		end

feature -- Camera anchor

	test_camera_anchor
		local
			c: PT_CAMERA_ANCHOR
		do
			create c.make ({STRING_32} "\\.\DISPLAY1 2560x1440", 1280, 0)
			assert_true ("monitor", c.monitor_key.same_string ({STRING_32} "\\.\DISPLAY1 2560x1440"))
			assert_true ("point", c.x = 1280 and c.y = 0)
			assert_refused ("empty monitor refused", agent new_anchor ({STRING_32} ""))
		end

feature -- Scripted transcriber

	test_scripted_transcriber
		local
			t: PT_SCRIPTED_TRANSCRIBER
		do
			create t.make (create {PT_SPEECH_MAP}.make (3.0), heard (0, <<{STRING_32} "one">>))
			assert_false ("succeeds", t.fails)
			t.transcribe ({STRING_32} "raw.mkv", 7.0)
			assert_true ("success", t.is_success)
			assert_true ("map sized to the recording", attached t.last_map as al_m and then al_m.duration = 7.0)
			assert_true ("words", attached t.last_heard as al_h and then al_h.count = 1)
			create t.make_failing ({STRING_32} "no GPU")
			t.transcribe ({STRING_32} "raw.mkv", 7.0)
			assert_false ("failed", t.is_success)
			assert_true ("reason kept", t.fails and attached t.reason as al_r and then al_r.same_string ({STRING_32} "no GPU"))
			assert_true ("error reported", attached t.last_error)
			assert_refused ("zero duration refused", agent t.transcribe ({STRING_32} "raw.mkv", 0.0))
		end

feature -- Settings

	test_settings_defaults_and_setters
		local
			s: PT_SETTINGS
		do
			create s.make_in_memory
			assert_integers_equal ("default lines", s.Default_lines, s.lines_visible)
			assert_integers_equal ("default width", s.Default_width, s.column_width)
			assert_integers_equal ("default font", s.Default_font, s.font_size)
			assert_integers_equal ("default speed", s.Default_wpm, s.speed_wpm)
			assert_true ("ranges ordered", s.Min_lines <= s.Default_lines and s.Default_lines <= s.Max_lines
				and s.Min_width <= s.Default_width and s.Default_width <= s.Max_width
				and s.Min_font <= s.Default_font and s.Default_font <= s.Max_font
				and s.Min_wpm <= s.Default_wpm and s.Default_wpm <= s.Max_wpm)
			s.set_lines_visible (s.Max_lines)
			s.set_column_width (s.Min_width)
			s.set_opacity (200)
			s.set_count_in_seconds (3.5)
			s.set_pads (0.1, 0.25)
			s.set_sessions_root ({STRING_32} "D:\Takes")
			s.set_devices ({STRING_32} "FHD Camera", {STRING_32} "Microphone (FHD Camera Microphone)")
			assert_integers_equal ("one save per setter", 7, s.save_count)
			assert_integers_equal ("lines", s.Max_lines, s.lines_visible)
			assert_integers_equal ("width", s.Min_width, s.column_width)
			assert_integers_equal ("opacity", 200, s.opacity)
			assert_true ("count-in", s.count_in_seconds = 3.5)
			assert_true ("pads", s.head_pad = 0.1 and s.tail_pad = 0.25)
			assert_true ("root", s.sessions_root.same_string ({STRING_32} "D:\Takes"))
			assert_true ("camera", s.camera_name.same_string ({STRING_32} "FHD Camera"))
			assert_false ("tracking not proven yet", s.is_tracking_proven)
			assert_integers_equal ("voice-gated until proven", {PT_FOLLOW_MODE}.Voice_gated, s.default_mode (True))
			s.mark_tracking_proven
			assert_integers_equal ("tracking once proven, with a GPU", {PT_FOLLOW_MODE}.Tracking, s.default_mode (True))
			assert_integers_equal ("never tracking without a GPU", {PT_FOLLOW_MODE}.Voice_gated, s.default_mode (False))
			assert_refused ("too many lines refused", agent s.set_lines_visible (s.Max_lines + 1))
			assert_refused ("too wide refused", agent s.set_column_width (s.Max_width + 1))
			assert_refused ("opacity above 255 refused", agent s.set_opacity (256))
			assert_refused ("count-in above 5 s refused", agent s.set_count_in_seconds (5.5))
			assert_refused ("pads above 2 s refused", agent s.set_pads (2.5, 0.0))
			assert_refused ("missing microphone refused", agent s.set_devices ({STRING_32} "cam", {STRING_32} ""))
		end

feature -- Keys

	test_key_binding_codes
		local
			b: PT_KEY_BINDING
		do
			create b.make ({PT_CONTROL}.Again, {PT_KEY_BINDING}.Mod_control | {PT_KEY_BINDING}.Mod_alt, {PT_KEYMAP}.Vk_space, False)
			assert_true ("modifiers", b.modifiers = ({PT_KEY_BINDING}.Mod_control | {PT_KEY_BINDING}.Mod_alt))
			assert_integers_equal ("vkey", 0x20, b.vkey)
			assert_true ("code is the combo code", b.key_code = b.combo_code (b.modifiers, b.vkey))
			assert_false ("not bare", b.is_bare or b.is_bare_while_recording)
			assert_true ("vkey in the low word", b.combo_code ({PT_KEY_BINDING}.Mod_shift, 0x41) \\ 65_536 = 0x41)
			assert_true ("modifiers distinguish combos",
				b.combo_code ({PT_KEY_BINDING}.Mod_shift, 0x41) /= b.combo_code ({PT_KEY_BINDING}.Mod_win, 0x41))
			assert_true ("all modifiers", {PT_KEY_BINDING}.All_modifiers = 0xF)
			create b.make ({PT_CONTROL}.Clicker_forward, 0, {PT_KEYMAP}.Vk_next, True)
			assert_true ("bare clicker key", b.is_bare and b.is_bare_while_recording)
			assert_refused ("bare key without the recording flag refused", agent new_binding (0, 0x41, False))
			assert_refused ("vkey 0 refused", agent new_binding ({PT_KEY_BINDING}.Mod_alt, 0, False))
			assert_refused ("unknown modifier refused", agent new_binding (0x10, 0x41, False))
		end

	test_keymap_bare_keys_follow_recording
		local
			k: PT_KEYMAP
		do
			create k.make_default
			assert_true ("bindings counted", k.binding_count > 0 and k.combos_model.count = k.binding_count)
			k.bind_clicker_defaults
			assert_integers_equal ("bare keys dead before recording", 0, k.control_for (0, k.Vk_next))
			k.set_recording (True)
			k.activate_bare_keys
			assert_integers_equal ("PageDown", {PT_CONTROL}.Clicker_forward, k.control_for (0, k.Vk_next))
			assert_integers_equal ("PageUp", {PT_CONTROL}.Clicker_back, k.control_for (0, k.Vk_prior))
			assert_integers_equal ("B holds", {PT_CONTROL}.Clicker_hold, k.control_for (0, k.Vk_b))
			assert_integers_equal ("period holds", {PT_CONTROL}.Clicker_hold, k.control_for (0, k.Vk_oem_period))
			k.deactivate_bare_keys
			assert_integers_equal ("deactivated", 0, k.control_for (0, k.Vk_next))
			k.activate_bare_keys
			k.set_recording (False)
			assert_false ("ending the recording releases bare keys", k.bare_keys_active)
		end

	test_win32_virtual_key_codes
			-- The constants are Win32 values (winuser.h); a wrong one binds the wrong key.
		local
			k: PT_KEYMAP
		do
			create k.make
			assert_integers_equal ("VK_BACK", 0x08, k.Vk_back)
			assert_integers_equal ("VK_RETURN", 0x0D, k.Vk_return)
			assert_integers_equal ("VK_SPACE", 0x20, k.Vk_space)
			assert_integers_equal ("VK_PRIOR", 0x21, k.Vk_prior)
			assert_integers_equal ("VK_NEXT", 0x22, k.Vk_next)
			assert_integers_equal ("VK_END", 0x23, k.Vk_end)
			assert_integers_equal ("VK_LEFT", 0x25, k.Vk_left)
			assert_integers_equal ("VK_RIGHT", 0x27, k.Vk_right)
			assert_integers_equal ("B", 0x42, k.Vk_b)
			assert_integers_equal ("E", 0x45, k.Vk_e)
			assert_integers_equal ("H", 0x48, k.Vk_h)
			assert_integers_equal ("I", 0x49, k.Vk_i)
			assert_integers_equal ("N", 0x4E, k.Vk_n)
			assert_integers_equal ("P", 0x50, k.Vk_p)
			assert_integers_equal ("S", 0x53, k.Vk_s)
			assert_integers_equal ("X", 0x58, k.Vk_x)
			assert_integers_equal ("VK_OEM_PERIOD", 0xBE, k.Vk_oem_period)
		end

	test_control_resolver_routes
		local
			r: PT_CONTROL_RESOLVER
		do
			create r.make
			assert_integers_equal ("clicker back reading = Again", {PT_ACTION}.Again, r.action_for ({PT_CONTROL}.Clicker_back, {PT_TAKE_STATE}.Reading, True))
			assert_integers_equal ("clicker back held = Back", {PT_ACTION}.Back, r.action_for ({PT_CONTROL}.Clicker_back, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("clicker forward held = Go", {PT_ACTION}.Go, r.action_for ({PT_CONTROL}.Clicker_forward, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("hold toggle held = Go", {PT_ACTION}.Go, r.action_for ({PT_CONTROL}.Hold_toggle, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("forward held", {PT_ACTION}.Forward, r.action_for ({PT_CONTROL}.Forward, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("back paragraph held", {PT_ACTION}.Back_paragraph, r.action_for ({PT_CONTROL}.Back_paragraph, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("forward paragraph held", {PT_ACTION}.Forward_paragraph, r.action_for ({PT_CONTROL}.Forward_paragraph, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("edit held", {PT_ACTION}.Edit_open, r.action_for ({PT_CONTROL}.Edit, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("abort reading", {PT_ACTION}.Abort, r.action_for ({PT_CONTROL}.Abort, {PT_TAKE_STATE}.Reading, True))
			assert_integers_equal ("play from idle", {PT_ACTION}.Play, r.action_for ({PT_CONTROL}.Play_stop, {PT_TAKE_STATE}.Idle, False))
			assert_integers_equal ("hide is app-level", 0, r.action_for ({PT_CONTROL}.Hide, {PT_TAKE_STATE}.Reading, True))
			assert_integers_equal ("click-through is app-level", 0, r.action_for ({PT_CONTROL}.Click_through, {PT_TAKE_STATE}.Idle, False))
			assert_integers_equal ("marker refused in practice", 0, r.action_for ({PT_CONTROL}.Marker, {PT_TAKE_STATE}.Reading, False))
		end

feature -- Take controller

	test_controller_marker_count_in_and_queries
		local
			c: PT_TAKE_CONTROLLER
			l_before: INTEGER
		do
			c := controller_for (moody)
			assert_true ("default count-in", c.count_in_seconds = c.Default_count_in)
			c.set_count_in (3.5)
			assert_true ("count-in set", c.count_in_seconds = 3.5)
			assert_refused ("count-in above 5 s refused", agent c.set_count_in (6.0))
			assert_true ("argument actions", c.needs_argument ({PT_ACTION}.Pick_word) and c.needs_argument ({PT_ACTION}.Edit_commit)
				and c.needs_argument ({PT_ACTION}.Marker))
			assert_false ("play needs no argument", c.needs_argument ({PT_ACTION}.Play))
			assert_true ("browse actions", c.is_browse ({PT_ACTION}.Back) and c.is_browse ({PT_ACTION}.Forward)
				and c.is_browse ({PT_ACTION}.Back_paragraph) and c.is_browse ({PT_ACTION}.Forward_paragraph))
			assert_false ("again is not browse", c.is_browse ({PT_ACTION}.Again))
			c.sample_alignment (create {PT_ALIGNMENT}.make (5, 0.8, 4, 3, 2.0, 0))
			assert_true ("confidence taken", c.alignment_confidence = 0.8)
			assert_integers_equal ("confident word", 5, c.last_confident_word)
			assert_integers_equal ("practice is not journaled", 0, c.journal.count)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Count_in_done)
			l_before := c.journal.count
			c.add_marker ({STRING_32} "chapter: numbers")
			assert_integers_equal ("marker journaled", l_before + 1, c.journal.count)
			assert_integers_equal ("marker kind", {PT_EVENT_KIND}.Marker, c.journal.last_event.kind)
			assert_integers_equal ("still reading", {PT_TAKE_STATE}.Reading, c.state)
			assert_true ("recording time", c.current_rt >= 0 and c.recording_clock.rt = c.current_rt)
			assert_true ("again target in script", c.again_target >= 1 and c.again_target <= c.revision.word_count)
			c.sample_alignment (create {PT_ALIGNMENT}.make (14, 0.3, 2, 1, 2.5, 16_000))
			assert_true ("low confidence taken", c.alignment_confidence = 0.3)
			assert_integers_equal ("low confidence does not move the confident word", 5, c.last_confident_word)
			assert_true ("confident level", c.Confident_level = 0.6)
		end

	test_controller_edit_range_again_and_wrap
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Hold)
			c.pick_word (20)
			c.perform ({PT_ACTION}.Edit_open)
			assert_integers_equal ("editing", {PT_TAKE_STATE}.Editing, c.state)
			assert_true ("edit range holds the caret", c.edit_first <= 20 and 20 <= c.edit_last)
			assert_true ("edit range is the caret's passage", c.revision.passage_of (c.edit_first) = c.revision.passage_of (20)
				and c.revision.passage_of (c.edit_last) = c.revision.passage_of (20))
			c.perform ({PT_ACTION}.Edit_cancel)
			assert_integers_equal ("cancel returns to held", {PT_TAKE_STATE}.Held, c.state)
			c.perform ({PT_ACTION}.Go)
			c.perform ({PT_ACTION}.Count_in_done)
			c.perform ({PT_ACTION}.Again)
			assert_integers_equal ("again target is the caret", c.caret, c.last_again_target)
			assert_true ("again journals a rewind", c.journal.count_of ({PT_EVENT_KIND}.Rewind_to) >= 1)
			c.perform ({PT_ACTION}.Count_in_done)
			assert_true ("reader in script", c.reader_position >= 0 and c.reader_position <= c.revision.word_count)
			c.perform ({PT_ACTION}.Reject)
			c.perform ({PT_ACTION}.Wrap)
			assert_integers_equal ("analyzing", {PT_TAKE_STATE}.Analyzing, c.state)
			c.perform ({PT_ACTION}.Analysis_done)
			assert_integers_equal ("wrapped", {PT_TAKE_STATE}.Wrapped, c.state)
			assert_integers_equal ("one reject journaled", 1, c.journal.count_of ({PT_EVENT_KIND}.Reject))
		end

	test_transitions_partition_actions
		local
			t: PT_TRANSITIONS
		do
			create t.make
			assert_true ("recording only", t.is_recording_only ({PT_ACTION}.Star) and t.is_recording_only ({PT_ACTION}.Reject)
				and t.is_recording_only ({PT_ACTION}.Marker) and t.is_recording_only ({PT_ACTION}.Wrap) and t.is_recording_only ({PT_ACTION}.Abort))
			assert_false ("play is not recording only", t.is_recording_only ({PT_ACTION}.Play))
			assert_true ("stop is practice only", t.is_practice_only ({PT_ACTION}.Stop))
			assert_false ("record is not practice only", t.is_practice_only ({PT_ACTION}.Record))
			assert_integers_equal ("record counts in", {PT_TAKE_STATE}.Count_in, t.next_state ({PT_TAKE_STATE}.Idle, {PT_ACTION}.Record))
			assert_integers_equal ("go is not listed from idle", 0, t.table_entry ({PT_TAKE_STATE}.Idle, {PT_ACTION}.Go))
			assert_false ("star refused in practice", t.is_allowed ({PT_TAKE_STATE}.Reading, {PT_ACTION}.Star, False))
			assert_refused ("unlisted next state refused", agent t.next_state ({PT_TAKE_STATE}.Idle, {PT_ACTION}.Go))
		end

feature -- Recording clock, preflight, capture

	test_recording_clock_samples_and_interpolation
		local
			k: PT_RECORDING_CLOCK
		do
			create k.make
			k.observe_bytes (64_000, 1_000.0)
			assert_true ("bytes", k.byte_count = 64_000)
			assert_true ("time", k.observed_at_ms = 1_000.0)
			assert_true ("samples are float32: 4 bytes each", k.sample_count = 16_000)
			assert_true ("one second", (k.rt - 1.0).abs < 1.0e-9)
			assert_integers_equal ("byte rate", 64_000, k.Bytes_per_second)
			assert_true ("interpolates forward", k.rt_at (1_100.0) > k.rt and k.rt_at (1_100.0) <= k.rt + k.Max_interpolation_s)
			assert_true ("never past the bound", k.rt_at (9_000.0) <= k.rt + k.Max_interpolation_s + 1.0e-9)
			assert_refused ("shrinking file refused", agent k.observe_bytes (100, 2_000.0))
		end

	test_preflight_reports_problems
		local
			p: PT_PREFLIGHT
		do
			create p.make
			p.check_ready (True, True, True, True, p.required_bytes (8_000_000, 30) + 1, 8_000_000, 30)
			assert_true ("ready", p.is_ready and p.problems.is_empty)
			p.check_ready (False, False, True, False, 0, 8_000_000, 30)
			assert_false ("not ready", p.is_ready)
			assert_true ("ffmpeg, devices, model and disk reported", p.problems.count >= 4)
			assert_true ("margin needs disk even for zero minutes", p.required_bytes (8_000_000, 0) > 0)
			assert_true ("longer sessions need more", p.required_bytes (8_000_000, 30) > p.required_bytes (8_000_000, 0))
			assert_integers_equal ("margin", 10, p.Margin_minutes)
		end

	test_capture_plan_fields
		local
			d: PT_DEVICE_CHOICE
			c: PT_CAPTURE_PLAN
		do
			create d.make_default
			assert_true ("default camera mode", d.width = 1920 and d.height = 1080 and d.fps = 30 and d.has_camera)
			create c.make_recording ({STRING_32} "ffmpeg.exe", d, {STRING_32} "raw.mkv", {STRING_32} "tee.f32")
			assert_true ("devices", c.devices = d)
			assert_true ("paths", c.raw_path.same_string ({STRING_32} "raw.mkv") and c.tee_path.same_string ({STRING_32} "tee.f32"))
			assert_false ("recording", c.is_audio_only)
			assert_true ("16 kHz tee", c.Tee_rate = 16_000 and c.has_pair (c.arguments, "-ar", c.Tee_rate.out))
			assert_true ("small audio buffer", c.has_pair (c.arguments, "-audio_buffer_size", c.Audio_buffer_ms.out))
			assert_integers_equal ("one keyframe a second at 30 fps", 30, c.Gop_frames)
			create d.make ({STRING_32} "", {STRING_32} "USB Mic", 640, 480, 30)
			assert_false ("no camera", d.has_camera)
			create c.make_audio_only ({STRING_32} "ffmpeg.exe", d, {STRING_32} "tee.f32")
			assert_true ("audio only has no raw file", c.is_audio_only and c.raw_path.is_empty)
		end

feature -- Session and facade

	test_session_analysis_and_cuts
		local
			s: PT_SESSION
			l_folder: PT_SESSION_FOLDER
			l_cuts: PT_CUT_LIST
			l_analysis: PT_ANALYSIS
		do
			create l_folder.make ({STRING_32} "C:\Takes\one.take")
			create s.make (l_folder, history_of (moody), create {PT_JOURNAL}.make_in_memory)
			assert_true ("folder", s.folder = l_folder)
			assert_false ("not analyzed", s.is_analyzed)
			create l_analysis.make_failed ({STRING_32} "no GPU")
			s.set_analysis (l_analysis)
			assert_true ("analysis kept", s.analysis = l_analysis)
			create l_cuts.make
			s.set_cuts (l_cuts)
			assert_true ("edited cuts", s.cuts = l_cuts and s.analysis = l_analysis)
		end

	test_facade_feeds_voice_and_heard
		local
			p: SIMPLE_PROMPTER
			l_measure: PT_FIXED_MEASURE
			l_text: STRING_32
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			create l_measure.make (10.0, 30.0)
			p := p.with_mode ({PT_FOLLOW_MODE}.Tracking).with_measure (l_measure, 600.0)
			assert_true ("measure", p.measure = l_measure)
			assert_integers_equal ("column width", 600, p.column_width)
			create l_text.make_empty
			across moody_sentences as ic loop
				l_text.append (ic)
				l_text.append_character (' ')
			end
			p.load_script_text ({STRING_32} "moody", l_text)
			p.perform ({PT_ACTION}.Play)
			p.perform ({PT_ACTION}.Count_in_done)
			p.feed_voice (frame (0, True))
			assert_true ("speaking", p.follower.is_speaking)
			p.feed_heard (heard (0, <<{STRING_32} "This", {STRING_32} "is", {STRING_32} "Moody", {STRING_32} "Moody",
				{STRING_32} "is", {STRING_32} "a", {STRING_32} "notch">>))
			assert_true ("aligned forward", p.aligner.position >= 3)
			assert_true ("controller sampled", p.controller.alignment_confidence = p.aligner.last_alignment.confidence)
			assert_true ("recording clock idle in practice", p.recording_clock.rt = 0)
			assert_integers_equal ("prompt words", 40, p.Prompt_words)
			assert_true ("no error", p.last_error = Void)
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.open_script ({STRING_32} "testing/fixtures/no_such_script.md")
			assert_false ("missing file not loaded", p.has_script)
			assert_true ("error reported", attached p.last_error)
		end

feature {NONE} -- Creation helpers (agents cannot target creation)

	new_folder (a_root: READABLE_STRING_32)
		local
			f: PT_SESSION_FOLDER
		do
			create f.make (a_root)
		end

	new_health (a_drop: REAL_64)
		local
			h: PT_RECORDER_HEALTH
		do
			create h.make (True, 64_000.0, a_drop, Void)
		end

	new_anchor (a_key: READABLE_STRING_32)
		local
			c: PT_CAMERA_ANCHOR
		do
			create c.make (a_key, 0, 0)
		end

	new_binding (a_modifiers: NATURAL_32; a_vkey: INTEGER; a_bare: BOOLEAN)
		local
			b: PT_KEY_BINDING
		do
			create b.make ({PT_CONTROL}.Again, a_modifiers, a_vkey, a_bare)
		end

end
