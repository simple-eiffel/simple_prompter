note
	description: "[
		User preferences, persisted as TOML (%APPDATA%\simple_prompter\settings.toml)
		with simple_toml in Phase 4. simple_speed_reader's SR_SETTINGS pattern:
		clamped getters fall back to defaults on bad data, and every setter saves.
		Default mode is Voice-gated until Tracking is proven (approved Q5).
	]"
	author: "Larry Rix"

class
	PT_SETTINGS

create
	make_in_memory, make_with_file

feature {NONE} -- Initialization

	make_in_memory
			-- Defaults, never written to disk (tests).
		do
			font_size := Default_font
			lines_visible := Default_lines
			column_width := Default_width
			opacity := 255
			speed_wpm := Default_wpm
			count_in_seconds := 2.0
			head_pad := 0.12
			tail_pad := 0.20
			create sessions_root.make_empty
			create camera_name.make_from_string ({STRING_32} "FHD Camera")
			create microphone_name.make_from_string ({STRING_32} "Microphone (FHD Camera Microphone)")
			follow_mode := {PT_FOLLOW_MODE}.Tracking
		ensure
			memory_only: path = Void
			nothing_saved: save_count = 0
		end

	make_with_file (a_path: READABLE_STRING_32)
			-- Load from `a_path' (defaults where absent or out of range).
		require
			path_present: not a_path.is_empty
		do
			make_in_memory
			path := a_path.to_string_32
			load
		ensure
			persistent: attached path
		end

feature -- Constants

	Min_font: INTEGER = 12
	Max_font: INTEGER = 96
	Default_font: INTEGER = 28
	Min_lines: INTEGER = 1
	Max_lines: INTEGER = 12
	Default_lines: INTEGER = 5
	Min_width: INTEGER = 200
	Max_width: INTEGER = 2400
	Default_width: INTEGER = 560
	Min_wpm: INTEGER = 40
	Max_wpm: INTEGER = 400
	Default_wpm: INTEGER = 130

feature -- Access

	path: detachable STRING_32
	save_count: INTEGER
			-- Number of saves (each setter saves once).

	font_size: INTEGER
	lines_visible: INTEGER
	column_width: INTEGER
	opacity: INTEGER
			-- 0..255 (whole-window alpha; capture-exclusion compatible).
	speed_wpm: INTEGER
	count_in_seconds: REAL_64
	head_pad, tail_pad: REAL_64
	sessions_root: STRING_32
			-- Empty = %USERPROFILE%\Videos\simple_prompter (resolved by the app; approved Q8).
	camera_name, microphone_name: STRING_32
	is_tracking_proven: BOOLEAN
			-- Set once Tracking passes its acceptance test (approved Q5).

	default_mode (a_gpu_available: BOOLEAN): INTEGER
			-- Mode to start in.
		do
			if is_tracking_proven and a_gpu_available then
				Result := {PT_FOLLOW_MODE}.Tracking
			else
				Result := {PT_FOLLOW_MODE}.Voice_gated
			end
		ensure
			tracking_only_when_proven: Result = {PT_FOLLOW_MODE}.Tracking implies (is_tracking_proven and a_gpu_available)
			known: Result >= {PT_FOLLOW_MODE}.Constant and Result <= {PT_FOLLOW_MODE}.Tracking
		end

feature -- Element change

	set_font_size (a_px: INTEGER)
		require
			in_range: a_px >= Min_font and a_px <= Max_font
		do
			font_size := a_px
			save
		ensure
			set: font_size = a_px
			saved: save_count = old save_count + 1
		end

	set_lines_visible (a_lines: INTEGER)
		require
			in_range: a_lines >= Min_lines and a_lines <= Max_lines
		do
			lines_visible := a_lines
			save
		ensure
			set: lines_visible = a_lines
			saved: save_count = old save_count + 1
		end

	set_column_width (a_px: INTEGER)
		require
			in_range: a_px >= Min_width and a_px <= Max_width
		do
			column_width := a_px
			save
		ensure
			set: column_width = a_px
			saved: save_count = old save_count + 1
		end

	set_opacity (a_alpha: INTEGER)
		require
			in_range: a_alpha >= 0 and a_alpha <= 255
		do
			opacity := a_alpha
			save
		ensure
			set: opacity = a_alpha
			saved: save_count = old save_count + 1
		end

	set_speed_wpm (a_wpm: INTEGER)
		require
			in_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		do
			speed_wpm := a_wpm
			save
		ensure
			set: speed_wpm = a_wpm
			saved: save_count = old save_count + 1
		end

	mark_tracking_proven
		do
			is_tracking_proven := True
			save
		ensure
			proven: is_tracking_proven
			saved: save_count = old save_count + 1
		end

feature {NONE} -- Implementation

	save
			-- Persist (Phase 4: simple_toml serialize to `path' when attached).
		local
			l_toml: SIMPLE_TOML
			l_table, l_root: TOML_TABLE
			l_ok: BOOLEAN
		do
			save_count := save_count + 1
			if attached path as al_path then
				create l_toml
				create l_table.make
				l_table := l_table.with_integer ("font_size", font_size).with_integer ("lines_visible", lines_visible)
					.with_integer ("column_width", column_width).with_integer ("opacity", opacity)
					.with_integer ("speed_wpm", speed_wpm).with_float ("count_in_seconds", count_in_seconds)
					.with_float ("head_pad", head_pad).with_float ("tail_pad", tail_pad)
					.with_string ("sessions_root", sessions_root).with_string ("camera", camera_name)
					.with_string ("microphone", microphone_name).with_boolean ("tracking_proven", is_tracking_proven)
					.with_boolean ("pill_placed", has_pill_position).with_integer ("pill_x", pill_x).with_integer ("pill_y", pill_y)
					.with_string ("last_script", last_script).with_integer ("follow_mode", follow_mode)
				create l_root.make
				l_root := l_root.with_table ("prompter", l_table)
					-- simple_toml.save_file narrows to STRING_8 (lossy); write UTF-8 through simple_file instead.
				l_ok := (create {SIMPLE_FILE}.make (al_path)).set_content (l_toml.serialize (l_root))
			end
		ensure
			counted: save_count = old save_count + 1
		end

feature -- Script

	last_script: STRING_32
			-- Path of the script opened last (empty: none yet).
		attribute
			create Result.make_empty
		end

	set_last_script (a_path: READABLE_STRING_32)
			-- Remember `a_path' as the script to reopen at the next start.
		do
			last_script := a_path.to_string_32
			save
		ensure
			set: last_script.same_string (a_path)
			saved: save_count = old save_count + 1
		end

feature -- Following

	follow_mode: INTEGER
			-- How the app moves the text (a PT_FOLLOW_MODE); Tracking unless chosen otherwise.

	set_follow_mode (a_mode: INTEGER)
			-- Remember `a_mode' for the next start.
		require
			known: a_mode >= {PT_FOLLOW_MODE}.Constant and a_mode <= {PT_FOLLOW_MODE}.Tracking
		do
			follow_mode := a_mode
			save
		ensure
			set: follow_mode = a_mode
			saved: save_count = old save_count + 1
		end

feature -- Pill placement

	pill_x, pill_y: INTEGER
			-- Top-left of the pill on the virtual screen, when `has_pill_position'.

	has_pill_position: BOOLEAN
			-- Has the reader placed the pill (Shift+drag) at least once?

	set_pill_position (a_x, a_y: INTEGER)
			-- Remember where the reader put the pill.
		do
			pill_x := a_x
			pill_y := a_y
			has_pill_position := True
			save
		ensure
			set: pill_x = a_x and pill_y = a_y
			placed: has_pill_position
			saved: save_count = old save_count + 1
		end

feature -- Element change (review L20)

	set_count_in_seconds (a_seconds: REAL_64)
		require
			in_range: a_seconds >= 0 and a_seconds <= 5
		do
			count_in_seconds := a_seconds
			save
		ensure
			set: count_in_seconds = a_seconds
			saved: save_count = old save_count + 1
		end

	set_pads (a_head, a_tail: REAL_64)
		require
			non_negative: a_head >= 0 and a_tail >= 0
			sane: a_head <= 2 and a_tail <= 2
		do
			head_pad := a_head
			tail_pad := a_tail
			save
		ensure
			set: head_pad = a_head and tail_pad = a_tail
			saved: save_count = old save_count + 1
		end

	set_sessions_root (a_root: READABLE_STRING_32)
		do
			sessions_root := a_root.to_string_32
			save
		ensure
			set: sessions_root.same_string (a_root)
			saved: save_count = old save_count + 1
		end

	set_devices (a_camera, a_microphone: READABLE_STRING_32)
		require
			microphone_present: not a_microphone.is_empty
		do
			camera_name := a_camera.to_string_32
			microphone_name := a_microphone.to_string_32
			save
		ensure
			set: camera_name.same_string (a_camera) and microphone_name.same_string (a_microphone)
			saved: save_count = old save_count + 1
		end

feature {NONE} -- Loading

	load
			-- Read `path' if it exists; out-of-range or missing values keep their defaults.
		local
			l_file: SIMPLE_FILE
			l_raw: STRING_8
			l_text: STRING_32
			l_encoding: SIMPLE_ENCODING
		do
			if attached path as al_path then
				create l_file.make (al_path)
				if l_file.exists then
					create l_raw.make (256)
					across l_file.binary_content as ic loop
						l_raw.append_character (ic.to_character_8)
					end
					create l_encoding.make
					l_text := l_encoding.utf_8_to_utf_32 (l_raw)
					if not l_text.is_empty and then attached (create {SIMPLE_TOML}).parse (l_text) as al_root
						and then attached al_root.table_item ("prompter") as t then
						apply (t)
					end
				end
			end
		end

	apply (t: TOML_TABLE)
			-- Adopt each in-range value of `t'.
		do
			if t.has ("font_size") and then in_range (t.integer_item ("font_size"), Min_font, Max_font) then
				font_size := t.integer_item ("font_size").to_integer_32
			end
			if t.has ("lines_visible") and then in_range (t.integer_item ("lines_visible"), Min_lines, Max_lines) then
				lines_visible := t.integer_item ("lines_visible").to_integer_32
			end
			if t.has ("column_width") and then in_range (t.integer_item ("column_width"), Min_width, Max_width) then
				column_width := t.integer_item ("column_width").to_integer_32
			end
			if t.has ("opacity") and then in_range (t.integer_item ("opacity"), 0, 255) then
				opacity := t.integer_item ("opacity").to_integer_32
			end
			if t.has ("speed_wpm") and then in_range (t.integer_item ("speed_wpm"), Min_wpm, Max_wpm) then
				speed_wpm := t.integer_item ("speed_wpm").to_integer_32
			end
			if t.has ("count_in_seconds") and then t.float_item ("count_in_seconds") >= 0 and then t.float_item ("count_in_seconds") <= 5 then
				count_in_seconds := t.float_item ("count_in_seconds")
			end
			if t.has ("head_pad") and then t.float_item ("head_pad") >= 0 and then t.float_item ("head_pad") <= 2 then
				head_pad := t.float_item ("head_pad")
			end
			if t.has ("tail_pad") and then t.float_item ("tail_pad") >= 0 and then t.float_item ("tail_pad") <= 2 then
				tail_pad := t.float_item ("tail_pad")
			end
			if attached t.string_item ("sessions_root") as al_s then
				sessions_root := al_s
			end
			if attached t.string_item ("camera") as al_s then
				camera_name := al_s
			end
			if attached t.string_item ("microphone") as al_s and then not al_s.is_empty then
				microphone_name := al_s
			end
			if t.has ("tracking_proven") then
				is_tracking_proven := t.boolean_item ("tracking_proven")
			end
			if attached t.string_item ("last_script") as al_s then
				last_script := al_s
			end
			if t.has ("follow_mode") and then in_range (t.integer_item ("follow_mode"), {PT_FOLLOW_MODE}.Constant, {PT_FOLLOW_MODE}.Tracking) then
				follow_mode := t.integer_item ("follow_mode").to_integer_32
			end
			if t.has ("pill_placed") and then t.boolean_item ("pill_placed") and then t.has ("pill_x") and then t.has ("pill_y")
				and then in_range (t.integer_item ("pill_x"), -100_000, 100_000) and then in_range (t.integer_item ("pill_y"), -100_000, 100_000) then
				pill_x := t.integer_item ("pill_x").to_integer_32
				pill_y := t.integer_item ("pill_y").to_integer_32
				has_pill_position := True
			end
		end

	in_range (a_value: INTEGER_64; a_min, a_max: INTEGER): BOOLEAN
		do
			Result := a_value >= a_min and a_value <= a_max
		end

invariant
	font_range: font_size >= Min_font and font_size <= Max_font
	lines_range: lines_visible >= Min_lines and lines_visible <= Max_lines
	width_range: column_width >= Min_width and column_width <= Max_width
	opacity_range: opacity >= 0 and opacity <= 255
	wpm_range: speed_wpm >= Min_wpm and speed_wpm <= Max_wpm
	count_in_range: count_in_seconds >= 0 and count_in_seconds <= 5
	pads_non_negative: head_pad >= 0 and tail_pad >= 0

end
