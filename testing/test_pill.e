note
	description: "[
		Plan Step 1 library additions for the pill: word geometry and hit
		testing (PT_PILL_GEOMETRY), the remembered pill position
		(PT_SETTINGS), and the bindings list the app registers (PT_KEYMAP).
	]"
	author: "Larry Rix"

class
	TEST_PILL

inherit
	PT_TEST_SET

feature -- Geometry

	test_word_positions_match_the_layout
			-- Fixed measure: 10 px per character, 30 px lines; padding 12, reading line 30.
			-- "This is Moody." -> This at 12 (40 wide), is at 12 + 40 + 10 = 62.
		local
			g: PT_PILL_GEOMETRY
		do
			g := geometry (0.0)
			assert_reals_equal ("first word inset", 12.0, g.word_x (1), 1.0e-9)
			assert_reals_equal ("first word width", 40.0, g.word_width (1), 1.0e-9)
			assert_reals_equal ("second word after one space", 62.0, g.word_x (2), 1.0e-9)
				-- 12 padding + 30 reading line; the reading point is centred half a line down,
				-- and until the reader is half a line in the first line sits in the reading row.
			assert_reals_equal ("line 1 in the reading row before reading", 42.0, g.line_top (1, 0.0), 1.0e-9)
			assert_reals_equal ("line 2 one line lower", 72.0, g.line_top (2, 0.0), 1.0e-9)
			assert_reals_equal ("scrolling moves lines up", 27.0, g.line_top (1, 30.0), 1.0e-9)
			assert_reals_equal ("halfway through line 1 it fills the reading row", 42.0, g.line_top (1, 15.0), 1.0e-9)
		end

	test_hit_testing
		local
			g: PT_PILL_GEOMETRY
		do
			g := geometry (0.0)
			assert_integers_equal ("on This", 1, g.word_at (15.0, 65.0, 0.0))
			assert_integers_equal ("on is", 2, g.word_at (65.0, 65.0, 0.0))
			assert_integers_equal ("in the gap between words", 0, g.word_at (55.0, 65.0, 0.0))
			assert_integers_equal ("above the first line", 0, g.word_at (15.0, 10.0, 0.0))
			assert_integers_equal ("same point after scrolling one line: line 2's first word",
				g.layout.line (2).first_word, g.word_at (15.0, 65.0, 30.0))
		end

	test_visible_lines
		local
			g: PT_PILL_GEOMETRY
		do
			g := geometry (0.0)
			assert_integers_equal ("first visible", 1, g.first_visible_line (0.0))
			assert_integers_equal ("three lines start above 132 px", 3, g.last_visible_line (0.0, 132.0))
			assert_integers_equal ("scrolled past line 1: it has left the top", 2, g.first_visible_line (90.0))
		end

feature -- Hold

	test_hold_offers_the_passage_start
			-- F-01: holding offers a restart point - the start of the passage being read -
			-- so Go restarts that sentence instead of jumping back to where reading began.
		local
			c: PT_TAKE_CONTROLLER
			l_expected: INTEGER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Play)
			c.perform ({PT_ACTION}.Count_in_done)
			c.follower.advance (12.0)
			l_expected := moody.passage (moody.passage_of (c.reader_position)).first_word
			assert_true ("well past the first passage", c.reader_position > moody.passage (2).first_word)
			c.perform ({PT_ACTION}.Hold)
			assert_integers_equal ("caret offered at the start of the passage being read", l_expected, c.caret)
		end

	test_hold_never_offers_a_cue
			-- Just past a cue line, the restart point is the next sentence, not the cue
			-- (a cue is never read aloud) and not the sentence before it.
		local
			c: PT_TAKE_CONTROLLER
			r: PT_SCRIPT_REVISION
			p: PT_SCRIPT_PARSER
			l_four: INTEGER
		do
			create p.make
			p.parse ({STRING_32} "t", {STRING_32} "One two three.%N%N[CUE: take a breath here]%N%NFour five six seven.", 1, create {PT_ID_SOURCE}.make)
			r := p.last_revision
			c := controller_for (r)
			c.perform ({PT_ACTION}.Play)
			c.perform ({PT_ACTION}.Count_in_done)
				-- Put the reader inside the cue line (a constant follower reads through cues).
			c.follower.set_caret (4)
			c.perform ({PT_ACTION}.Hold)
			from l_four := 1 until r.word (l_four).normalized.same_string ({STRING_32} "four") loop
				l_four := l_four + 1
			end
			assert_integers_equal ("restart at Four", l_four, c.caret)
		end

feature -- Settings and keys

	test_pill_position_survives_a_restart
		local
			s: PT_SETTINGS
			l_path: STRING_32
			l_ok: BOOLEAN
		do
			l_path := {STRING_32} "testing/out/pill_settings.toml"
			if (create {SIMPLE_FILE}.make (l_path)).exists then
				l_ok := (create {SIMPLE_FILE}.make (l_path)).delete
			end
			ensure_out_dir
			create s.make_with_file (l_path)
			assert_false ("not placed yet", s.has_pill_position)
			s.set_pill_position (-1200, 24)
			s.set_last_script ({STRING_32} "C:\Scripts\Episode 12 - caf%/233/.md")
			create s.make_with_file (l_path)
			assert_true ("placed after reload", s.has_pill_position)
			assert_true ("last script after reload (non-ASCII kept)", s.last_script.same_string ({STRING_32} "C:\Scripts\Episode 12 - caf%/233/.md"))
			assert_integers_equal ("x", -1200, s.pill_x)
			assert_integers_equal ("y", 24, s.pill_y)
		end

	test_all_bindings_lists_every_binding
		local
			k: PT_KEYMAP
		do
			create k.make_default
			assert_integers_equal ("every default binding", k.binding_count, k.all_bindings.count)
			assert_true ("each has a modifier", across k.all_bindings as ic all not ic.is_bare end)
		end

feature -- Tests: transport bar (0.3.2)

	test_transport_bar_hits_every_button
			-- A 400 px pill at scale 1: each button answers at its own centre, the band above
			-- the row is the progress line, the script text above the bar never hits.
		local
			b: PT_TRANSPORT_BAR
			i: INTEGER
		do
			create b.make (1.0)
			b.lay_out (0.0, 100.0, 400.0)
			from i := 1 until i > b.Button_count loop
				assert_integers_equal ("button " + i.out + " at its centre", i, b.hit (b.button_centre_x (i), b.button_centre_y))
				i := i + 1
			end
			assert_integers_equal ("progress band", b.Progress_hit, b.hit (200.0, 102.0))
			assert_integers_equal ("script text", 0, b.hit (200.0, 99.0))
			assert_integers_equal ("gap between groups",
				0, b.hit ((b.button_left (b.Forward_button) + b.button_size + b.button_left (b.Record_button)) / 2, b.button_centre_y))
			assert_true ("in the bar", b.is_in_bar (100.0) and not b.is_in_bar (99.9))
			assert_true ("full size when it fits", (b.button_size - b.Design_button).abs < 0.001)
		end

	test_transport_bar_narrows_to_fit
			-- The narrowest pill (200 px column + padding) at 150 % scale still holds every button.
		local
			b: PT_TRANSPORT_BAR
		do
			create b.make (1.5)
			b.lay_out (0.0, 0.0, 224.0 * 1.5)
			assert_true ("narrowed", b.button_size < b.Design_button * 1.5)
			assert_true ("first inside", b.button_left (1) >= 0.0)
			assert_true ("last inside", b.button_left (b.Button_count) + b.button_size <= 224.0 * 1.5 + 0.001)
			assert_integers_equal ("still hits", b.Faster_button, b.hit (b.button_centre_x (b.Faster_button), b.button_centre_y))
		end

	test_transport_bar_progress_and_jump
			-- The progress line maps x to a fraction and a fraction to a word.
		local
			b: PT_TRANSPORT_BAR
		do
			create b.make (1.0)
			b.lay_out (0.0, 0.0, 400.0)
			assert_true ("left end", b.fraction_at (b.progress_left) = 0.0)
			assert_true ("right end", b.fraction_at (b.progress_right) = 1.0)
			assert_true ("past the ends clamps", b.fraction_at (-50.0) = 0.0 and b.fraction_at (900.0) = 1.0)
			assert_integers_equal ("start is word 1", 1, b.word_at_fraction (0.0, 50))
			assert_integers_equal ("end is the last word", 50, b.word_at_fraction (1.0, 50))
			assert_integers_equal ("half way", 25, b.word_at_fraction (0.5, 50))
			b.set_progress (25.0, 50)
			assert_true ("half read", (b.progress - 0.5).abs < 0.001)
			b.set_progress (80.0, 50)
			assert_true ("never past the end", b.progress = 1.0)
			b.set_progress (3.0, 0)
			assert_true ("no script, no progress", b.progress = 0.0)
		end

	test_transport_bar_signature_tracks_what_is_drawn
			-- Anything the buttons draw changes the signature; hiding forgets the hover.
		local
			b: PT_TRANSPORT_BAR
			s: INTEGER
		do
			create b.make (1.0)
			s := b.signature
			b.set_enabled (b.Star_button, True)
			assert_true ("enabled changes it", b.signature /= s)
			s := b.signature
			b.set_pointer_in (True)
			b.set_hovered (b.Play_button, 0.0)
			assert_true ("hovered changes it", b.signature /= s)
			s := b.signature
			b.update_tooltip (1000.0)
			assert_true ("tooltip changes it", b.signature /= s)
			b.set_pointer_in (False)
			assert_integers_equal ("leaving forgets the hover", 0, b.hovered)
			s := b.signature
			b.set_transport (True, True, True)
			assert_true ("transport changes it", b.signature /= s)
		end

	test_transport_bar_tooltips
			-- A tooltip waits for the pointer to rest, names the key, follows the state,
			-- and goes when the pointer moves on or leaves.
		local
			b: PT_TRANSPORT_BAR
		do
			create b.make (1.0)
			b.set_pointer_in (True)
			b.set_hovered (b.Play_button, 1000.0)
			b.update_tooltip (1200.0)
			assert_false ("not yet", b.is_tooltip_shown)
			b.update_tooltip (1000.0 + b.Tooltip_delay_ms)
			assert_true ("after resting", b.is_tooltip_shown)
			assert_true ("idle: play and its key", b.tooltip.has_substring ({STRING_32} "Play") and b.tooltip.has_substring ({STRING_32} "Ctrl+Alt+P"))
			b.set_transport (True, True, False)
			assert_true ("reading: hold", b.tooltip.starts_with ({STRING_32} "Hold"))
			b.set_transport (False, True, False)
			assert_true ("held: go", b.tooltip.starts_with ({STRING_32} "Go"))
			b.set_hovered (b.Record_button, 2000.0)
			assert_false ("a new target waits again", b.is_tooltip_shown)
			b.set_transport (True, True, True)
			assert_true ("recording: wrap", b.tooltip.starts_with ({STRING_32} "Wrap"))
			b.set_hovered (b.Progress_hit, 3000.0)
			assert_true ("the progress line has one too", b.tooltip.starts_with ({STRING_32} "Jump"))
			b.update_tooltip (5000.0)
			b.set_pointer_in (False)
			assert_false ("leaving hides it", b.is_tooltip_shown)
		end

feature -- Tests: Settings page (0.3.5)

	test_device_list_reads_ffmpeg_listing
			-- JACKJACK's listing, 2026-10-10 (ffmpeg 8.0 -list_devices true -f dshow -i dummy).
		local
			d: PT_DEVICE_LIST
		do
			create d.make_from_listing (Device_listing)
			assert_integers_equal ("three cameras", 3, d.cameras.count)
			assert_true ("first camera", d.cameras [1].same_string ({STRING_32} "FHD Camera"))
			assert_true ("obs", d.has_camera ({STRING_32} "OBS Virtual Camera"))
			assert_integers_equal ("two microphones", 2, d.microphones.count)
			assert_true ("broadcast microphone", d.has_microphone ({STRING_32} "Microphone (NVIDIA Broadcast)"))
			assert_false ("alternative names skipped", d.has_camera ({STRING_32} "@device_pnp_usb#vid_1234"))
			create d.make_from_listing ({STRING_32} "")
			assert_true ("nothing listed", d.cameras.is_empty and d.microphones.is_empty)
		end

	test_settings_page_lists_and_chooses
		local
			pg: PT_SETTINGS_PAGE
			d: PT_DEVICE_LIST
			l_zone: detachable TUPLE [code: INTEGER; x, y, w, h: REAL_64]
		do
			create d.make_from_listing (Device_listing)
			create pg.make
			pg.offer (d, {STRING_32} "OBS Virtual Camera", {STRING_32} "Microphone (FHD Camera Microphone)", 110)
			assert_true ("camera found", pg.is_camera_found)
			assert_integers_equal ("only Windows' cameras", 3, pg.cameras.count)
			pg.lay_out (10, 100, 480, 1.5)
			l_zone := pg.zone (pg.Camera_base + 1)
			assert_true ("first camera row placed", attached l_zone)
			if attached l_zone as al_z then
				assert_integers_equal ("hit the first camera", pg.Camera_base + 1, pg.hit (al_z.x + 5, al_z.y + 5))
				pg.choose_camera (pg.hit (al_z.x + 5, al_z.y + 5) - pg.Camera_base)
			end
			assert_true ("webcam chosen", pg.camera.same_string ({STRING_32} "FHD Camera"))
			if attached pg.zone (pg.Microphone_base + 1) as al_z then
				assert_true ("mic row is a mic row", pg.is_microphone_row (pg.hit (al_z.x + 5, al_z.y + 5)))
				pg.choose_microphone (1)
			end
			assert_true ("broadcast chosen", pg.microphone.same_string ({STRING_32} "Microphone (NVIDIA Broadcast)"))
			assert_integers_equal ("outside", pg.Nothing_hit, pg.hit (5000, 5000))
			if attached pg.zone (pg.Done_hit) as al_z then
				assert_integers_equal ("done", pg.Done_hit, pg.hit (al_z.x + 1, al_z.y + 1))
				assert_true ("done below the rest", across pg.zones as ic all ic.y <= al_z.y end)
			end
		end

	test_settings_page_keeps_a_missing_device_visible
			-- A chosen device Windows no longer offers is listed, marked, never swapped silently.
		local
			pg: PT_SETTINGS_PAGE
		do
			create pg.make
			pg.offer (create {PT_DEVICE_LIST}.make_from_listing (Device_listing), {STRING_32} "Old Camera",
				{STRING_32} "Microphone (High Definition Audio Device)", 0)
			assert_false ("camera missing", pg.is_camera_found)
			assert_false ("microphone missing", pg.is_microphone_found)
			assert_integers_equal ("missing camera listed last", 4, pg.cameras.count)
			assert_true ("still chosen", pg.camera.same_string ({STRING_32} "Old Camera"))
			assert_true ("marked", pg.device_text (pg.camera, False).has_substring ({STRING_32} "not found"))
			pg.choose_camera (2)
			assert_true ("a found one chosen", pg.is_camera_found)
		end

	test_settings_page_delay_steps_and_locks
		local
			pg: PT_SETTINGS_PAGE
		do
			create pg.make
			pg.offer (create {PT_DEVICE_LIST}.make_empty, {STRING_32} "", {STRING_32} "Mic", 110)
			pg.step_delay (1)
			assert_integers_equal ("up 10", 120, pg.video_delay_ms)
			pg.step_delay (-20)
			assert_integers_equal ("below 0 allowed (picture ahead)", -80, pg.video_delay_ms)
			pg.step_delay (-100)
			assert_integers_equal ("never below the minimum", {PT_TAKE_SYNC}.Min_ms, pg.video_delay_ms)
			pg.step_delay (500)
			assert_integers_equal ("never above the maximum", {PT_TAKE_SYNC}.Max_ms, pg.video_delay_ms)
			assert_true ("text", pg.delay_text.same_string ({STRING_32} "1000 ms"))
			pg.set_locked (True)
			assert_true ("locked", pg.is_locked)
			pg.lay_out (0, 0, 400, 1.0)
			assert_integers_equal ("no camera rows without a camera", 0, pg.cameras.count)
			assert_integers_equal ("mic, delay buttons, done", 4, pg.zones.count)
		end

	Device_listing: STRING_32 = "[
[dshow @ 000001] "FHD Camera" (video)
[dshow @ 000001]   Alternative name "@device_pnp_usb#vid_1234"
[dshow @ 000001] "Camera (NVIDIA Broadcast)" (video)
[dshow @ 000001] "OBS Virtual Camera" (video)
[dshow @ 000001] "Microphone (NVIDIA Broadcast)" (audio)
[dshow @ 000001]   Alternative name "@device_cm_33D9A762_wave"
[dshow @ 000001] "Microphone (FHD Camera Microphone)" (audio)
]"

feature {NONE} -- Fixtures

	geometry (a_unused: REAL_64): PT_PILL_GEOMETRY
			-- Moody laid out 300 px wide with a 10 px / 30 px fixed measure.
		local
			l_layout: PT_LAYOUT
			l_measure: PT_FIXED_MEASURE
		do
			create l_measure.make (10.0, 30.0)
			create l_layout.make
			l_layout.build (moody, l_measure, 300.0)
			create Result.make (moody, l_layout, l_measure, 12.0, 30.0)
		end

	ensure_out_dir
		local
			l_dir: DIRECTORY
		do
			create l_dir.make ("testing/out")
			if not l_dir.exists then
				l_dir.create_dir
			end
		end

end
