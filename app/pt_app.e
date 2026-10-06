note
	description: "[
		simple_prompter, plan Step 1: the pill at constant speed. A small control
		window (state, speed, keys) owns the event pump; the pill is a
		capture-excluded panel under the webcam. The 16 ms tick finishes the
		count-in, advances the follower and the smoothed scroll, and repaints
		the pill when anything it shows has changed.

		Usage: simple_prompter_app [script.md|script.txt] [--capturable]
		(no script: the read test from the project fixtures, if present;
		--capturable lets screen captures see the pill, for screenshots).
	]"
	author: "Larry Rix"

class
	PT_APP

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Load settings and the script, build the windows, run until closed.
		local
			l_title: STRING_32
		do
			settings := new_settings
			create desktop
			desktop.become_dpi_aware
			create theme.make_dark
			theme.set_families ("Segoe UI", "Segoe UI", "Consolas")
			theme.set_text_scale (desktop.dpi_scale)
			create clock.make
			create measure.make (theme, settings.font_size)
			create prompter.make_with_settings (settings)
			prompter := prompter.with_mode ({PT_FOLLOW_MODE}.Constant).with_speed_wpm (settings.speed_wpm)
				.with_clock (clock).with_measure (measure, settings.column_width * theme.text_scale)
			load_script
			prompter.controller.set_count_in (settings.count_in_seconds)
			create pill.make (settings, theme, measure)
			if has_flag ({STRING_32} "--capturable") then
				pill.make_capturable
			end
			create router.make (prompter, pill, settings)
			geometry := new_geometry
			create status_canvas.make (Window_height * theme.text_scale)
			l_title := {STRING_32} "simple_prompter"
			create window.make (l_title, 80, 160, (Window_width * theme.text_scale).ceiling,
				(Window_height * theme.text_scale).ceiling, theme)
				-- Every attribute is set: only now may agents on Current be made (VEVI).
			status_canvas.set_on_paint (agent paint_status)
			window.set_root (status_canvas)
			window.set_on_shell_event (agent on_shell_event)
			window.set_on_tick (agent on_heartbeat)
			window.run
				-- The window closed: give everything back.
			router.release_all
			pill.close
		end

feature -- Constants

	Tick_ms: INTEGER = 16
	Window_width: INTEGER = 520
	Window_height: INTEGER = 460

feature -- Access

	settings: PT_SETTINGS
	desktop: SHELL_DESKTOP
	theme: SW_THEME
	clock: PT_QPC_CLOCK
	measure: PT_CAIRO_MEASURE
	prompter: SIMPLE_PROMPTER
	pill: PT_PILL
	router: PT_INPUT_ROUTER
	geometry: PT_PILL_GEOMETRY
	window: SW_WINDOW
	status_canvas: SW_CANVAS

	script_note: STRING_32
			-- Where the script came from, for the control window.
		attribute
			create Result.make_empty
		end

feature {NONE} -- The clock

	is_started: BOOLEAN
			-- Have the pill, the hotkeys and the fast tick been set up?

	count_in_started_ms: REAL_64
	previous_state: INTEGER
	last_signature: INTEGER_64
	last_status: STRING_32
		attribute
			create Result.make_empty
		end

	on_heartbeat
			-- The 250 ms heartbeat: first time round, the native window exists, so set up.
		do
			if not is_started then
				is_started := True
				pill.open
				router.register_all
				window.set_fast_timer (Tick_ms)
				window.request_render
			end
			refresh_status
		end

	on_shell_event (a_type, a_a, a_b: INTEGER)
		do
			inspect a_type
			when 25 then
				on_tick
			when {SHELL_HOTKEYS}.Event_hotkey then
				router.on_hotkey (a_a)
				on_tick
			when {SHELL_PANEL}.Event_press then
				router.on_press (geometry.word_at (a_a, a_b, prompter.scroll.y_offset))
				on_tick
			when {SHELL_PANEL}.Event_right_press then
				router.on_right_press
				on_tick
			when {SHELL_PANEL}.Event_wheel then
				router.on_wheel (a_a)
				on_tick
			when {SHELL_PANEL}.Event_moved then
				pill.remember_position (a_a, a_b)
			when {SHELL_PANEL}.Event_expose then
				last_signature := -1
				on_tick
			else
			end
		end

	on_tick
			-- Count-in, follower, scroll, repaint when something visible changed.
		local
			l_now: REAL_64
			l_state: INTEGER
			l_signature: INTEGER_64
		do
			if is_started then
				l_now := clock.now_ms
				l_state := prompter.controller.state
				if l_state = {PT_TAKE_STATE}.Count_in and previous_state /= {PT_TAKE_STATE}.Count_in then
					count_in_started_ms := l_now
				end
				previous_state := l_state
				if l_state = {PT_TAKE_STATE}.Count_in
					and then l_now - count_in_started_ms >= prompter.controller.count_in_seconds * 1000
					and then prompter.controller.is_allowed ({PT_ACTION}.Count_in_done) then
					prompter.perform ({PT_ACTION}.Count_in_done)
					previous_state := prompter.controller.state
				end
				prompter.tick (l_now)
				l_signature := (prompter.scroll.position * 64).rounded.to_integer_64 * 1000
					+ prompter.controller.state * 100 + badge.count + caret_shown
				if pill.is_click_through then
					l_signature := l_signature + 50
				end
				if l_signature /= last_signature then
					last_signature := l_signature
					pill.paint (prompter, geometry, caret_shown, badge)
				end
			end
		end

feature {NONE} -- Pill content

	caret_shown: INTEGER
			-- The caret word while held (where Go will start), else 0.
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Held then
				Result := prompter.controller.caret
			end
		end

	badge: STRING_32
			-- Small status at the pill's corner.
		local
			l_left: INTEGER
		do
			inspect prompter.controller.state
			when {PT_TAKE_STATE}.Held then
				Result := {STRING_32} "HELD"
			when {PT_TAKE_STATE}.Count_in then
				l_left := (prompter.controller.count_in_seconds - (clock.now_ms - count_in_started_ms) / 1000).ceiling.max (1)
				Result := l_left.out
			when {PT_TAKE_STATE}.Idle then
				Result := {STRING_32} "Ctrl+Alt+P"
			else
				create Result.make_empty
			end
			if pill.is_click_through then
				if not Result.is_empty then
					Result.append ({STRING_32} "  ")
				end
				Result.append ({STRING_32} "CLICK-THROUGH")
			end
		end

feature {NONE} -- Control window

	refresh_status
			-- Repaint the control window when its text changed.
		local
			l_status: STRING_32
		do
			l_status := state_name + settings.speed_wpm.out + pill.is_shown.out + pill.is_click_through.out + pill.capture_note
			if not l_status.same_string (last_status) then
				last_status := l_status
				window.request_render
			end
		end

	paint_status (p: SW_PAINTER; a_x, a_y, a_w, a_h: REAL_64)
		local
			l_y, k: REAL_64
		do
			k := theme.text_scale
			p.set_color (theme.background)
			p.fill_rect (a_x, a_y, a_w, a_h)
			l_y := a_y + 30 * k
			p.font (p.Role_ui, 18, True)
			p.set_color (theme.ink)
			p.text (a_x + 18 * k, l_y, {STRING_32} "simple_prompter")
			l_y := l_y + 28 * k
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			p.text (a_x + 18 * k, l_y, script_note)
			l_y := l_y + 22 * k
			p.text (a_x + 18 * k, l_y, {STRING_32} "State: " + state_name + {STRING_32} "    Speed: " + settings.speed_wpm.out + {STRING_32} " wpm (constant)")
			l_y := l_y + 22 * k
			p.text (a_x + 18 * k, l_y, {STRING_32} "Pill: " + (if pill.is_shown then {STRING_32} "shown" else {STRING_32} "hidden" end)
				+ {STRING_32} ", " + pill.capture_note
				+ (if pill.is_click_through then {STRING_32} ", click-through" else {STRING_32} "" end))
			l_y := l_y + 32 * k
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.ink)
			p.text (a_x + 18 * k, l_y, {STRING_32} "Keys (work in any program)")
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			across router.key_names as ic loop
				l_y := l_y + 20 * k
				p.text (a_x + 30 * k, l_y, ic)
			end
			l_y := l_y + 30 * k
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.ink)
			p.text (a_x + 18 * k, l_y, {STRING_32} "Mouse on the pill")
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			l_y := l_y + 20 * k
			p.text (a_x + 30 * k, l_y, {STRING_32} "click: hold    held: click a word to start there")
			l_y := l_y + 20 * k
			p.text (a_x + 30 * k, l_y, {STRING_32} "right-click: go    wheel: back / forward    Shift+drag: move")
			across router.refused as ic loop
				l_y := l_y + 22 * k
				p.set_color (theme.danger)
				p.text (a_x + 18 * k, l_y, ic)
			end
			l_y := l_y + 30 * k
			p.set_color (theme.ink_muted)
			p.text (a_x + 18 * k, l_y, {STRING_32} "Close this window to quit.")
		end

	state_name: STRING_32
		do
			inspect prompter.controller.state
			when {PT_TAKE_STATE}.Idle then Result := {STRING_32} "ready"
			when {PT_TAKE_STATE}.Count_in then Result := {STRING_32} "counting in"
			when {PT_TAKE_STATE}.Reading then Result := {STRING_32} "reading"
			when {PT_TAKE_STATE}.Held then Result := {STRING_32} "held"
			when {PT_TAKE_STATE}.Editing then Result := {STRING_32} "editing"
			when {PT_TAKE_STATE}.Analyzing then Result := {STRING_32} "analyzing"
			else
				Result := {STRING_32} "wrapped"
			end
		end

feature {NONE} -- Setup

	new_settings: PT_SETTINGS
			-- Settings from %APPDATA%\simple_prompter\settings.toml (created on first save).
		local
			l_dir: DIRECTORY
			l_root: STRING_32
		do
			if attached (create {EXECUTION_ENVIRONMENT}).item ("APPDATA") as al_appdata and then not al_appdata.is_empty then
				l_root := al_appdata + {STRING_32} "\simple_prompter"
				create l_dir.make (l_root)
				if not l_dir.exists then
					l_dir.recursive_create_dir
				end
				create Result.make_with_file (l_root + {STRING_32} "\settings.toml")
			else
				create Result.make_in_memory
			end
		end

	load_script
			-- The script named on the command line, else the read test, else a sample.
		local
			l_path: STRING_32
		do
			l_path := Default_script
			across 1 |..| argument_count as ic loop
				if not argument (ic).starts_with ({STRING_32} "--") then
					l_path := argument (ic)
				end
			end
			if (create {SIMPLE_FILE}.make (l_path)).exists then
				prompter.open_script (l_path)
			end
			if prompter.has_script then
				script_note := {STRING_32} "Script: " + l_path + {STRING_32} " (" + prompter.history.current_revision.word_count.out + {STRING_32} " words)"
			else
				prompter.load_script_text ({STRING_32} "Sample", Sample_text)
				script_note := {STRING_32} "Sample text (no script found at " + l_path + {STRING_32} ")"
			end
		ensure
			loaded: prompter.has_script
		end

	has_flag (a_flag: READABLE_STRING_32): BOOLEAN
			-- Was `a_flag' given on the command line?
		do
			Result := across 1 |..| argument_count as ic some argument (ic).same_string (a_flag) end
		end

	new_geometry: PT_PILL_GEOMETRY
		require
			loaded: prompter.has_script
		do
			create Result.make (prompter.history.current_revision, prompter.layout, measure, pill.padding, pill.reading_line)
		end

	Default_script: STRING_32 = "D:\prod\simple_prompter\testing\fixtures\read_test_01.md"

	Sample_text: STRING_32 = "This is simple prompter. Press Control Alt P to start, and Control Alt Space to hold. The text scrolls at a steady speed for now; following your voice comes next."

end
