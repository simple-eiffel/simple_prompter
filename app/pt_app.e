note
	description: "[
		simple_prompter: the pill follows your voice. Since 0.4.0 the pill is the
		whole program - a capture-excluded panel under the webcam with its rails,
		callouts and slide handle, and an icon in the notification area. The old
		control window still owns the event pump, hidden (--window shows it). Speech runs on its own
		processor (PT_SPEECH_WORKER: Silero + whisper on the GPU, ffmpeg on the
		microphone); the 16 ms tick takes what it heard from the slot, feeds the
		facade while reading, keeps the recording clock and the already-read
		prompt current, finishes the count-in, advances the follower and the
		smoothed scroll, and repaints the pill when anything it shows has changed.

		Usage: simple_prompter_app [script.md|script.txt] [--capturable] [--window]
		(no script: the read test from the project fixtures, if present;
		--capturable lets screen captures see the pill, for screenshots;
		--window shows the old control window).
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
			create last_status.make_empty
			settings := new_settings
			create desktop
			desktop.become_dpi_aware
			create theme.make_dark
			theme.set_families ("Segoe UI", "Segoe UI", "Consolas")
			theme.set_text_scale (desktop.dpi_scale)
			create clock.make
			create measure.make (theme, settings.font_size)
			create prompter.make_with_settings (settings)
			prompter := prompter.with_mode (settings.follow_mode).with_speed_wpm (settings.speed_wpm)
				.with_clock (clock).with_measure (measure, settings.column_width * theme.text_scale)
			load_script
			prompter.controller.set_count_in (settings.count_in_seconds)
			create pill.make (settings, theme, measure)
			if has_flag ({STRING_32} "--capturable") then
				pill.make_capturable
			end
			create router.make (prompter, pill, settings)
			create codec.make
			create incoming.make (4096)
			create speech_status.make_from_string ({STRING_32} "loading the speech models")
			create camera_status.make_from_string ({STRING_32} "checked once the speech models are loaded")
			create video_status.make_empty
			create mode_note.make_empty
			create take_note.make_empty
			create speech_slot.make
			ffmpeg_path := resolved_ffmpeg
			create edit_floor.make (ffmpeg_path)
			edit_floor.set_on_sync_changed (agent settings.set_video_delay)
			geometry := new_geometry
			create status_canvas.make (Window_height * theme.text_scale)
			l_title := {STRING_32} "simple_prompter"
			create window.make (l_title, 80, 160, (Window_width * theme.text_scale).ceiling,
				(Window_height * theme.text_scale).ceiling, theme)
				-- Every attribute is set: only now may agents on Current be made (VEVI).
			status_canvas.set_on_paint (agent paint_status)
			status_canvas.set_on_press (agent on_status_press)
			status_canvas.set_on_files (agent on_files)
			edit_floor.set_on_publish (agent publish_take)
			router.set_on_open (agent choose_script)
			router.set_on_mode (agent switch_mode)
			router.set_on_record (agent start_take)
			start_speech
			window.set_root (status_canvas)
			window.set_on_shell_event (agent on_shell_event)
			window.set_on_tick (agent on_heartbeat)
			window.set_starts_hidden (not has_flag ({STRING_32} "--window"))
			window.run
				-- The window closed: give everything back.
			if attached tray as al_tray then
				al_tray.remove
			end
			across callouts as ic loop
				ic.close
			end
			slide_handle.close
			edit_floor.close
			stop_speech
			router.release_all
			pill.close
		end

feature -- Constants

	Version: STRING_32 = "0.5.0"
			-- Shown in the control window; keep in step with installer/simple_prompter.iss.

	Tick_ms: INTEGER = 16
	Window_width: INTEGER = 1040
			-- Two columns: the prompter's controls, and the Edit Floor (Step 4c).
	Window_height: INTEGER = 560

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

	settings_page: PT_SETTINGS_PAGE
			-- The Settings page (camera, microphone, picture delay), shown in the left column.
		attribute
			create Result.make
		end

	is_settings_shown: BOOLEAN
			-- Does the left column show the Settings page?

	status_callout: PT_CALLOUT
			-- Left of the pill: microphone, camera, following, keys (0.4.0).
		attribute
			create Result.make ({PT_CALLOUT}.Side_left, 300, theme)
		end

	script_callout: PT_CALLOUT
			-- Right of the pill: the script, Open script..., recent scripts.
		attribute
			create Result.make ({PT_CALLOUT}.Side_right, 320, theme)
			Result.set_takes_files (True)
		end

	settings_callout: PT_CALLOUT
			-- Right of the pill: camera, microphone, sync start, tooltips.
		attribute
			create Result.make ({PT_CALLOUT}.Side_right, 380, theme)
		end

	take_callout: PT_CALLOUT
			-- Below the pill: the Last take panel.
		attribute
			create Result.make ({PT_CALLOUT}.Side_below, 560, theme)
		end

	callouts: ARRAY [PT_CALLOUT]
		do
			Result := <<status_callout, script_callout, settings_callout, take_callout>>
		end

	slide_handle: PT_SLIDE_HANDLE
			-- The tab under the pill that slides it left and right.
		attribute
			create Result.make (theme)
		end

	last_callout_ms: REAL_64
	last_callout_signature: INTEGER
	last_rails_signature: INTEGER

feature {NONE} -- The clock

	is_started: BOOLEAN
			-- Have the pill, the hotkeys and the fast tick been set up?

	count_in_started_ms: REAL_64
	previous_state: INTEGER
	last_signature: INTEGER_64
	last_bar_signature: INTEGER
			-- `pill.bar.signature' at the last repaint.
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
				if pill.panel.is_open then
					pill.panel.set_accepts_files (True)
				end
				start_tray
				router.register_all
				window.set_fast_timer (Tick_ms)
				show_latest_take
				place_handle
				apply_tooltips
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
			when {SHELL_TRAY}.Event_click then
				if attached tray as al_tray and then window.event_extra = al_tray.id then
					on_tray_click (al_tray, a_a)
				end
			when {SHELL_PANEL}.Event_press .. {SHELL_PANEL}.Event_dropped then
				if attached callout_at_slot (window.event_extra) as al_callout then
					on_callout_event (al_callout, a_type, a_a, a_b)
				elseif slide_handle.slot >= 0 and window.event_extra = slide_handle.slot then
					on_handle_event (a_type, a_a, a_b)
				else
					on_pill_event (a_type, a_a, a_b)
				end
			else
			end
		end

	on_pill_event (a_type, a_a, a_b: INTEGER)
			-- An event from the pill's panel.
		local
			l_rail: INTEGER
		do
			inspect a_type
			when {SHELL_PANEL}.Event_press then
				if pill.rails.is_laid_out then
					l_rail := pill.rails.hit (a_a, a_b)
				end
				if pill.bar.is_laid_out and then pill.bar.is_in_bar (a_b) then
					on_bar_press (a_a, a_b)
				elseif l_rail /= 0 then
					on_rail_press (l_rail)
				elseif not pill.rails.is_in_rail (a_a, pill.panel.width) then
					router.on_press (geometry.word_at (a_a - pill.text_left.rounded, a_b, prompter.scroll.y_offset))
				end
				on_tick
			when {SHELL_PANEL}.Event_move then
				pill.track_pointer (a_a, a_b, clock.now_ms)
				on_tick
			when {SHELL_PANEL}.Event_right_press then
				router.on_right_press
				on_tick
			when {SHELL_PANEL}.Event_wheel then
				router.on_wheel (a_a)
				on_tick
			when {SHELL_PANEL}.Event_dropped then
				on_files (window.take_dropped_paths)
			when {SHELL_PANEL}.Event_moving then
				pill.panel.sync_geometry
				follow_pill
			when {SHELL_PANEL}.Event_moved then
				pill.remember_position (a_a, a_b)
				place_callouts
				place_handle
			when {SHELL_PANEL}.Event_resized then
				on_pill_resized (a_a, a_b)
				place_callouts
				place_handle
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
				poll_speech (l_now)
				edit_floor.tick
				l_state := prompter.controller.state
				if l_state = {PT_TAKE_STATE}.Count_in and previous_state /= {PT_TAKE_STATE}.Count_in then
					count_in_started_ms := l_now
				end
				previous_state := l_state
				if l_state = {PT_TAKE_STATE}.Count_in
					and then l_now - count_in_started_ms >= prompter.controller.count_in_seconds * 1000
					and then (not prompter.controller.is_recording or recording_live)
					and then prompter.controller.is_allowed ({PT_ACTION}.Count_in_done) then
						-- While recording, reading starts only once the camera's stream is live: the
						-- aligner re-anchors here on the recording's own sample clock.
					prompter.perform ({PT_ACTION}.Count_in_done)
					previous_state := prompter.controller.state
				end
				prompter.tick (l_now)
				follow_road
				pill.refresh_hover (l_now)
				router.refresh_bar (pill.bar)
				if pill.bar.signature /= last_bar_signature then
					last_bar_signature := pill.bar.signature
					last_signature := -1
				end
				update_lights
				follow_visibility (l_now)
				if pill.rails.signature /= last_rails_signature then
					last_rails_signature := pill.rails.signature
					last_signature := -1
				end
				follow_callouts (l_now)
				if pill.is_shift_held /= grips_shown then
					grips_shown := not grips_shown
					pill.set_shows_grips (grips_shown)
					last_signature := -1
				end
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

feature {NONE} -- Opening scripts

	choose_script
			-- Ask for a script with the Open dialog and load it.
		local
			l_dialog: SHELL_FILE_DIALOG
			l_dir: STRING_32
		do
			create l_dir.make_empty
			if not settings.last_script.is_empty then
				l_dir := (create {PATH}.make_from_string (settings.last_script)).parent.name
			end
			create l_dialog.make
			l_dialog.choose_file ({STRING_32} "Open a script", {STRING_32} "Scripts (*.md, *.txt)|*.md;*.txt|All files|*.*", l_dir)
			if l_dialog.has_choice then
				open_script_file (l_dialog.chosen_path)
			end
		end

	on_files (a_paths: ARRAYED_LIST [STRING_32])
			-- Files dropped on the pill, the Script callout or the control window: open the
			-- first script among them.
		local
			l_done: BOOLEAN
		do
			across a_paths as ic until l_done loop
				if ic.as_lower.ends_with ({STRING_32} ".md") or ic.as_lower.ends_with ({STRING_32} ".txt") then
					open_script_file (ic)
					l_done := True
				end
			end
			if not l_done and not a_paths.is_empty then
				script_note := {STRING_32} "Not a script: drop a .md or .txt file."
				window.request_render
			end
		end

	on_status_press (a_x, a_y: REAL_64)
			-- A click on the control window: the Open button opens a script, the Settings button
			-- shows or hides the Settings page, a click on the page changes a setting.
		do
			if a_x >= open_button_x and a_x <= open_button_x + open_button_width
				and a_y >= open_button_y and a_y <= open_button_y + open_button_height then
				choose_script
			elseif a_x >= settings_button_x and a_x <= settings_button_x + settings_button_width
				and a_y >= open_button_y and a_y <= open_button_y + open_button_height then
				toggle_settings
			elseif is_settings_shown and then settings_page.hit (a_x, a_y) /= settings_page.Nothing_hit then
				on_settings_press (settings_page.hit (a_x, a_y))
			else
				edit_floor.press (a_x, a_y)
				last_status := {STRING_32} ""
				refresh_status
			end
		end

	open_script_file (a_path: READABLE_STRING_32)
			-- Load `a_path' as the script, rewire the pill, and remember it.
		do
			if prompter.has_script and then prompter.controller.is_recording then
				script_note := {STRING_32} "Cannot open a script while recording."
			else
				prompter.open_script (a_path)
				if attached prompter.last_error as al_error and then not al_error.is_empty then
					script_note := al_error.twin
				else
					prompter.controller.set_count_in (settings.count_in_seconds)
					geometry := new_geometry
					settings.set_last_script (a_path)
					note_script (a_path)
					previous_state := prompter.controller.state
					last_signature := -1
				end
			end
			last_status := {STRING_32} ""
			window.request_render
			on_tick
		end

	on_bar_press (a_x, a_y: INTEGER)
			-- A click on the pill's transport bar: a button, or a jump along the progress line.
		require
			laid_out: pill.bar.is_laid_out
		local
			l_hit, l_word, l_count: INTEGER
		do
			l_hit := pill.bar.hit (a_x, a_y)
			l_count := prompter.history.current_revision.word_count
			if pill.bar.valid_button (l_hit) then
				router.on_bar (l_hit, 0)
			elseif l_hit = pill.bar.Progress_hit and l_count >= 1 then
				l_word := pill.bar.word_at_fraction (pill.bar.fraction_at (a_x), l_count)
				router.on_bar (l_hit, l_word)
			end
		end

	open_button_x, open_button_y, open_button_width, open_button_height: REAL_64

	settings_button_x, settings_button_width: REAL_64
			-- The Settings button, on the Open button's row.

	toggle_settings
			-- Show the Settings page (listing Windows' devices afresh), or go back.
		do
			if is_settings_shown then
				is_settings_shown := False
			else
				offer_devices
				is_settings_shown := True
			end
			window.request_render
		end

	offer_devices
			-- Fill the Settings page with Windows' devices, listed afresh, and the current choices.
		local
			l_listing: STRING_32
		do
			l_listing := (create {SIMPLE_PROCESS}.make).command_output ({STRING_32} "%"" + ffmpeg_path
				+ {STRING_32} "%" -hide_banner -list_devices true -f dshow -i dummy")
			settings_page.offer (create {PT_DEVICE_LIST}.make_from_listing (l_listing), settings.camera_name,
				settings.microphone_name, settings.video_delay_ms)
			settings_page.set_tooltips_on (settings.shows_tooltips)
		end

	on_settings_press (a_code: INTEGER)
			-- A click on the Settings page's `a_code' target: each change is saved and used at once.
		do
			if a_code = settings_page.Done_hit then
				is_settings_shown := False
				settings_callout.hide
				sync_rails
			elseif a_code = settings_page.Tooltips_hit then
				settings.set_shows_tooltips (not settings.shows_tooltips)
				apply_tooltips
			elseif not prompter.controller.is_recording then
				settings_page.set_locked (False)
				if settings_page.is_camera_row (a_code) then
					settings_page.choose_camera (a_code - settings_page.Camera_base)
					apply_devices
				elseif settings_page.is_microphone_row (a_code) then
					settings_page.choose_microphone (a_code - settings_page.Microphone_base)
					apply_devices
				elseif a_code = settings_page.Delay_down_hit then
					settings_page.step_delay (-1)
					settings.set_video_delay (settings_page.video_delay_ms)
				elseif a_code = settings_page.Delay_up_hit then
					settings_page.step_delay (1)
					settings.set_video_delay (settings_page.video_delay_ms)
				end
			end
			window.request_render
		end

	apply_devices
			-- Save the page's devices and hand them to the speech worker, when they changed.
		do
			if not settings_page.camera.same_string (settings.camera_name)
				or not settings_page.microphone.same_string (settings.microphone_name) then
				settings.set_devices (settings_page.camera, settings_page.microphone)
				camera_status := (if settings.camera_name.is_empty then {STRING_32} "none set" else settings.camera_name + {STRING_32} ": checking" end)
				if speech_started then
					ask_devices (speech_slot, settings.camera_name, settings.microphone_name)
				end
			end
		end
			-- Where the Open button was last drawn (canvas coordinates).

feature {NONE} -- Callouts (0.4.0)

	callout_at_slot (a_slot: INTEGER): detachable PT_CALLOUT
			-- The callout whose panel has `a_slot', if any.
		do
			across callouts as ic until attached Result loop
				if ic.slot >= 0 and ic.slot = a_slot then
					Result := ic
				end
			end
		end

	tray: detachable SHELL_TRAY
			-- The icon in the notification area: a click shows or hides the pill, a right
			-- click offers a menu (0.4.0). Void where Windows refused one.

	start_tray
			-- Put the icon in the notification area.
		local
			l_tray: SHELL_TRAY
		do
			create l_tray.make ({STRING_32} "simple_prompter - click to show or hide the pill")
			if l_tray.is_installed then
				tray := l_tray
			end
		end

	on_tray_click (a_tray: SHELL_TRAY; a_button: INTEGER)
			-- The tray icon: a click shows or hides the pill; a right click offers a menu.
		local
			l_choice: INTEGER
		do
			if a_button = a_tray.Click_left then
				router.on_control ({PT_CONTROL}.Hide)
			elseif a_button = a_tray.Click_right then
				l_choice := a_tray.choose (<<
					(if pill.is_shown then {STRING_32} "Hide the pill%T(Ctrl+Alt+H)" else {STRING_32} "Show the pill%T(Ctrl+Alt+H)" end),
					{STRING_32} "Open a script...%T(Ctrl+Alt+O)",
					{STRING_32} "-",
					{STRING_32} "Quit simple_prompter">>)
				inspect l_choice
				when 1 then
					router.on_control ({PT_CONTROL}.Hide)
				when 2 then
					choose_script
				when 4 then
					window.close
				else
				end
			end
			on_tick
		end

	on_rail_press (a_code: INTEGER)
			-- A rail button: open or close its callout, or quit.
		do
			inspect a_code
			when {PT_PILL_RAILS}.Status_hit then
				toggle_callout (status_callout)
			when {PT_PILL_RAILS}.Quit_hit then
				window.close
			when {PT_PILL_RAILS}.Script_hit then
				settings_callout.hide
				toggle_callout (script_callout)
			when {PT_PILL_RAILS}.Settings_hit then
				script_callout.hide
				if not settings_callout.is_shown then
					offer_devices
				end
				toggle_callout (settings_callout)
			when {PT_PILL_RAILS}.Take_hit then
				toggle_callout (take_callout)
			else
			end
			sync_rails
		end

	toggle_callout (a_callout: PT_CALLOUT)
		do
			if a_callout.is_shown then
				a_callout.hide
			else
				a_callout.hover.set_enabled (settings.shows_tooltips)
				a_callout.show_beside (pill.panel.x, pill.panel.y, pill.panel.width, pill.panel.height, pill.is_capturable)
				render_callout (a_callout)
			end
		end

	sync_rails
			-- Light the rail buttons whose callouts are open.
		do
			pill.rails.set_open (status_callout.is_shown, script_callout.is_shown, settings_callout.is_shown, take_callout.is_shown)
		end

	place_callouts
			-- Keep the open callouts beside the pill (it moved or changed size).
		do
			across callouts as ic loop
				if ic.is_shown then
					ic.show_beside (pill.panel.x, pill.panel.y, pill.panel.width, pill.panel.height, pill.is_capturable)
					render_callout (ic)
				end
			end
		end

	render_callout (a_callout: PT_CALLOUT)
		do
			if a_callout = status_callout then
				a_callout.render (agent paint_status_callout)
			elseif a_callout = script_callout then
				a_callout.render (agent paint_script_callout)
			elseif a_callout = settings_callout then
				a_callout.render (agent paint_settings_callout)
			else
				a_callout.render (agent paint_take_callout)
			end
		end

	follow_callouts (a_now: REAL_64)
			-- Each tick: forget hovers the pointer left, and repaint the open callouts when their
			-- hover changed or every 400 ms (status and render progress change on their own).
		local
			l_signature: INTEGER
		do
			across callouts as ic loop
				if ic.is_shown then
					ic.refresh_hover (a_now)
					l_signature := l_signature * 31 + ic.hover.signature + 1
				end
			end
			if l_signature /= last_callout_signature or a_now - last_callout_ms >= 400 then
				last_callout_signature := l_signature
				last_callout_ms := a_now
				across callouts as ic loop
					if ic.is_shown then
						render_callout (ic)
					end
				end
			end
		end

	on_callout_event (a_callout: PT_CALLOUT; a_type, a_x, a_y: INTEGER)
			-- An event from one of the callouts.
		local
			l_code: INTEGER
		do
			inspect a_type
			when {SHELL_PANEL}.Event_press then
				l_code := a_callout.zone_at (a_x, a_y)
				if l_code = a_callout.Close_zone then
					a_callout.hide
					sync_rails
				elseif a_callout = settings_callout then
					if l_code /= 0 then
						on_settings_press (l_code)
					end
				elseif a_callout = script_callout then
					on_script_press (l_code)
				elseif a_callout = take_callout then
					edit_floor.press (a_x, a_y)
				end
				if a_callout.is_shown then
					render_callout (a_callout)
				end
				on_tick
			when {SHELL_PANEL}.Event_move then
				a_callout.track (a_x, a_y, clock.now_ms)
			when {SHELL_PANEL}.Event_expose then
				render_callout (a_callout)
			when {SHELL_PANEL}.Event_dropped then
				on_files (window.take_dropped_paths)
				if a_callout.is_shown then
					render_callout (a_callout)
				end
			else
			end
		end

	on_handle_event (a_type, a_a, a_b: INTEGER)
			-- The slide handle: the pill and its callouts follow it.
		do
			inspect a_type
			when {SHELL_PANEL}.Event_moving then
				pill.panel.place (slide_handle.pill_left_for (a_a, pill.panel.width), pill.panel.y, pill.panel.width, pill.panel.height)
				follow_callouts_only
			when {SHELL_PANEL}.Event_moved then
				pill.remember_position (pill.panel.x, pill.panel.y)
				place_callouts
				place_handle
			when {SHELL_PANEL}.Event_move then
				slide_handle.track (clock.now_ms)
			else
			end
		end

	place_handle
			-- The slide handle, centred under the pill.
		do
			if pill.is_shown then
				slide_handle.show_under (pill.panel.x, pill.panel.y, pill.panel.width, pill.panel.height, pill.is_capturable)
			end
		end

	follow_pill
			-- The pill is moving (Shift+drag): its handle and callouts come along.
		do
			if slide_handle.is_shown then
				slide_handle.panel.place (pill.panel.x + pill.panel.width // 2 - slide_handle.width // 2,
					pill.panel.y + pill.panel.height, slide_handle.width, slide_handle.height)
			end
			follow_callouts_only
		end

	follow_callouts_only
		do
			across callouts as ic loop
				ic.follow (pill.panel.x, pill.panel.y, pill.panel.width, pill.panel.height)
			end
		end

	follow_visibility (a_now: REAL_64)
			-- Hidden pill (Ctrl+Alt+H): its handle and callouts go too, and come back with it. The
			-- handle's tooltip shows on the pill.
		local
			l_tip: STRING_32
		do
			if pill.is_shown and not slide_handle.is_shown then
				place_handle
			elseif not pill.is_shown and slide_handle.is_shown then
				slide_handle.hide
				across callouts as ic loop
					ic.hide
				end
				sync_rails
			end
			slide_handle.refresh_hover (a_now)
			l_tip := (if slide_handle.hover.is_tooltip_shown then slide_handle.Tip else {STRING_32} "" end)
			if not l_tip.same_string (pill.renderer.handle_tip) then
				pill.renderer.set_handle_tip (l_tip)
				last_signature := -1
			end
		end

	apply_tooltips
			-- Tooltips on or off everywhere, as Settings says.
		do
			pill.set_tooltips_enabled (settings.shows_tooltips)
			slide_handle.hover.set_enabled (settings.shows_tooltips)
			across callouts as ic loop
				ic.hover.set_enabled (settings.shows_tooltips)
			end
			settings_page.set_tooltips_on (settings.shows_tooltips)
		end

	update_lights
			-- The Status lights on the pill's left rail.
		local
			l_microphone, l_camera, l_follow: INTEGER
		do
			if speech_state = {PT_SPEECH_SLOT}.Failed then
				l_microphone := {PT_PILL_RAILS}.Light_problem
			elseif speech_state = {PT_SPEECH_SLOT}.Listening or speech_state = {PT_SPEECH_SLOT}.Recording then
				l_microphone := {PT_PILL_RAILS}.Light_good
			else
				l_microphone := {PT_PILL_RAILS}.Light_check
			end
			if prompter.controller.is_recording and video_stalled then
				l_camera := {PT_PILL_RAILS}.Light_problem
			elseif camera_verdict = {PT_CAMERA_CHECK}.Live then
				l_camera := (if camera_dark then {PT_PILL_RAILS}.Light_check else {PT_PILL_RAILS}.Light_good end)
			elseif camera_verdict = {PT_CAMERA_CHECK}.Unchecked then
				l_camera := {PT_PILL_RAILS}.Light_off
			else
				l_camera := {PT_PILL_RAILS}.Light_problem
			end
			if prompter.mode = {PT_FOLLOW_MODE}.Constant then
				l_follow := {PT_PILL_RAILS}.Light_off
			elseif speech_state = {PT_SPEECH_SLOT}.Failed then
				l_follow := {PT_PILL_RAILS}.Light_problem
			elseif not mode_note.is_empty or badge.has_substring ({STRING_32} "OFF SCRIPT") then
				l_follow := {PT_PILL_RAILS}.Light_check
			else
				l_follow := {PT_PILL_RAILS}.Light_good
			end
			pill.rails.set_lights (l_microphone, l_camera, l_follow)
		end

	paint_status_callout (p: SW_PAINTER; c: PT_CALLOUT)
			-- Microphone, camera, following (and video while recording), then the keys.
		local
			k, x, y, w: REAL_64
		do
			k := theme.text_scale
			x := c.padding
			w := c.width - 2 * c.padding
			y := c.padding + 16 * k
			p.font (p.Role_ui, 15, True)
			p.set_color (theme.ink)
			p.text (x, y, {STRING_32} "Status")
			y := y + 16 * k
			y := status_row (p, c, x, y, w, {STRING_32} "Microphone", speech_status, pill.rails.microphone_light, 101,
				{STRING_32} "The microphone voice following listens to and takes record (change it in Settings)", k)
			y := status_row (p, c, x, y, w, {STRING_32} "Camera", camera_status, pill.rails.camera_light, 102,
				{STRING_32} "The camera takes record; a virtual camera is checked every 10 seconds for a live picture", k)
			y := status_row (p, c, x, y, w, {STRING_32} "Following", state_name + {STRING_32} " - " + mode_name, pill.rails.follow_light, 103,
				{STRING_32} "How the pill follows you, and what it is doing now", k)
			if prompter.controller.is_recording and not video_status.is_empty then
				y := status_row (p, c, x, y, w, {STRING_32} "Video", video_status,
					(if video_stalled then {PT_PILL_RAILS}.Light_problem else {PT_PILL_RAILS}.Light_good end), 104,
					{STRING_32} "Frames reaching the recording, live", k)
			end
			y := y + 6 * k
			p.set_color (theme.outline)
			p.fill_rect (x, y, w, 1)
			y := y + 22 * k
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.ink)
			p.text (x, y, {STRING_32} "Keys (work in any program)")
			c.add_zone (105, x, y - 16 * k, w, 22 * k, {STRING_32} "These keys work even while another program has the focus")
			p.font (p.Role_ui, 12, False)
			p.set_color (theme.ink_muted)
			across router.key_names as ic loop
				y := wrap_to (p, x + 8 * k, y + 19 * k, w - 8 * k, ic, 18 * k) - 18 * k
			end
			y := y + 28 * k
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.ink)
			p.text (x, y, {STRING_32} "Mouse on the pill")
			p.font (p.Role_ui, 12, False)
			p.set_color (theme.ink_muted)
			across <<{STRING_32} "click: hold    held: click a word to start there", {STRING_32} "right-click: go    wheel: back / forward",
					{STRING_32} "hold Shift: drag to move, drag an edge or corner to size">> as ic loop
				y := wrap_to (p, x + 8 * k, y + 19 * k, w - 8 * k, ic, 18 * k) - 18 * k
			end
			c.set_content_height (y + 6 * k)
		end

	status_row (p: SW_PAINTER; c: PT_CALLOUT; a_x, a_y, a_w: REAL_64; a_title, a_text: READABLE_STRING_32; a_light, a_code: INTEGER;
			a_tip: READABLE_STRING_32; k: REAL_64): REAL_64
			-- One status line: its light, its name, what it says; answers the y below it.
		local
			l_top: REAL_64
		do
			l_top := a_y
			p.set_color (pill.renderer.light_colour (a_light))
			p.circle_fill (a_x + 5 * k, a_y + 12 * k, 4.5 * k)
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.ink)
			p.text (a_x + 18 * k, a_y + 16 * k, a_title)
			p.font (p.Role_ui, 12, False)
			p.set_color (theme.ink_muted)
			Result := wrap_to (p, a_x + 18 * k, a_y + 34 * k, a_w - 18 * k, a_text, 17 * k) + 2 * k
			c.add_zone (a_code, a_x, l_top, a_w, Result - l_top, a_tip)
		end

	paint_script_callout (p: SW_PAINTER; c: PT_CALLOUT)
			-- The script now, Open script..., and the recent scripts.
		local
			k, x, y, w, l_bw: REAL_64
			i: INTEGER
			l_name: STRING_32
		do
			k := theme.text_scale
			x := c.padding
			w := c.width - 2 * c.padding
			y := c.padding + 16 * k
			p.font (p.Role_ui, 15, True)
			p.set_color (theme.ink)
			p.text (x, y, {STRING_32} "Script")
			p.font (p.Role_ui, 12, False)
			p.set_color (theme.ink_muted)
			y := wrap_to (p, x, y + 24 * k, w, script_note, 18 * k)
			y := y + 4 * k
			l_bw := 140 * k
			p.set_color (theme.accent)
			p.rrect_fill (x, y, l_bw, 30 * k, 7 * k)
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.background)
			p.text (x + 14 * k, y + 20 * k, {STRING_32} "Open script...")
			c.add_zone (201, x, y, l_bw, 30 * k, {STRING_32} "Choose a script file (.md or .txt)  (Ctrl+Alt+O)")
			p.font (p.Role_ui, 12, False)
			p.set_color (theme.ink_muted)
			p.text (x, y + 30 * k + 22 * k, {STRING_32} "or drop a .md or .txt file on the pill or here")
			y := y + 30 * k + 22 * k + 32 * k
			if not settings.recent_scripts.is_empty then
				p.font (p.Role_ui, 12, True)
				p.set_color (theme.ink)
				p.text (x, y, {STRING_32} "Recent")
				y := y + 8 * k
				from i := 1 until i > settings.recent_scripts.count loop
					l_name := file_name (settings.recent_scripts [i])
					if i = 1 then
						p.set_color (theme.outline)
						p.rrect_fill (x - 4 * k, y, w + 8 * k, 26 * k, 5 * k)
					end
					p.font (p.Role_ui, 12, i = 1)
					p.set_color (if i = 1 then theme.ink else theme.ink_muted end)
					p.text (x + 4 * k, y + 18 * k, short_name (l_name, 40))
					c.add_zone (210 + i, x - 4 * k, y, w + 8 * k, 26 * k,
						(if i = 1 then {STRING_32} "Open again: " else {STRING_32} "Open " end) + settings.recent_scripts [i])
					y := y + 28 * k
					i := i + 1
				end
			end
			c.set_content_height (y + 4 * k)
		end

	on_script_press (a_code: INTEGER)
			-- A click on the Script callout.
		local
			l_index: INTEGER
		do
			if a_code = 201 then
				choose_script
			elseif a_code > 210 and a_code <= 210 + settings.recent_scripts.count then
				l_index := a_code - 210
				open_script_file (settings.recent_scripts [l_index].twin)
			end
		end

	paint_settings_callout (p: SW_PAINTER; c: PT_CALLOUT)
		do
			paint_settings_content (p, c.padding, c.padding - 4 * theme.text_scale, c.width - 2 * c.padding - 30 * theme.text_scale,
				theme.text_scale, c)
		end

	paint_take_callout (p: SW_PAINTER; c: PT_CALLOUT)
			-- The Last take panel.
		local
			i: INTEGER
			k: REAL_64
		do
			k := theme.text_scale
			edit_floor.paint (p, c.padding, 0, c.width - 2 * c.padding - 30 * k, k)
			from i := 1 until i > edit_floor.clickables.count loop
				c.add_zone (1000 + i, edit_floor.clickables [i].x, edit_floor.clickables [i].y, edit_floor.clickables [i].w,
					edit_floor.clickables [i].h, edit_floor.row_tip (edit_floor.clickables [i].action, edit_floor.clickables [i].index))
				i := i + 1
			end
			c.set_content_height (edit_floor.bottom)
		end

	wrap_to (p: SW_PAINTER; a_x, a_y, a_w: REAL_64; a_text: READABLE_STRING_32; a_step: REAL_64): REAL_64
			-- Draw `a_text' from (`a_x', `a_y') wrapped to `a_w'; answer the y below it.
		local
			l_y: REAL_64
		do
			l_y := a_y
			across (create {PT_WRAP}).lines (p, a_text, a_w) as ic loop
				p.text (a_x, l_y, ic)
				l_y := l_y + a_step
			end
			Result := l_y
		end

	file_name (a_path: READABLE_STRING_32): STRING_32
		do
			if attached (create {PATH}.make_from_string (a_path)).entry as al_entry then
				Result := al_entry.name
			else
				Result := a_path.to_string_32
			end
		end

	short_name (a_text: READABLE_STRING_32; a_max: INTEGER): STRING_32
		do
			if a_text.count <= a_max then
				Result := a_text.to_string_32
			else
				Result := a_text.substring (1, a_max - 3).to_string_32 + {STRING_32} "..."
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
			when {PT_TAKE_STATE}.Analyzing, {PT_TAKE_STATE}.Wrapped then
				Result := (if analysis_pending then {STRING_32} "ANALYZING" else {STRING_32} "SAVING" end)
			else
				create Result.make_empty
			end
			if prompter.controller.is_recording then
				Result := {STRING_32} "REC " + clock_text (prompter.recording_clock.rt) + (if Result.is_empty then {STRING_32} "" else {STRING_32} "  " + Result end)
				if video_stalled then
					Result.append ({STRING_32} "  NO VIDEO")
				elseif camera_verdict = {PT_CAMERA_CHECK}.Still or camera_verdict = {PT_CAMERA_CHECK}.Black then
					Result.append ({STRING_32} "  NO PICTURE")
				end
			end
			if off_road then
				Result := (if Result.is_empty then {STRING_32} "" else Result + {STRING_32} "  " end) + {STRING_32} "OFF SCRIPT"
			end
			if prompter.mode /= {PT_FOLLOW_MODE}.Constant and speech_state /= {PT_SPEECH_SLOT}.Listening
				and prompter.controller.state /= {PT_TAKE_STATE}.Idle then
				if not Result.is_empty then
					Result.append ({STRING_32} "  ")
				end
				Result.append ({STRING_32} "MIC OFF")
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
				+ prompter.mode.out + speech_status + camera_status + video_status + mode_note + take_note
				+ edit_floor.renderer.status + edit_floor.status_note + edit_floor.has_take.out
			if not l_status.same_string (last_status) then
				last_status := l_status
				window.request_render
			end
		end

	camera_color: NATURAL_32
			-- The Camera line's color: green when live, amber when live but dark or not yet
			-- checked, red when the camera is not giving a usable picture.
		do
			if camera_verdict = {PT_CAMERA_CHECK}.Live then
				Result := (if camera_dark then theme.warning else theme.success end)
			elseif camera_verdict = {PT_CAMERA_CHECK}.Unchecked then
				Result := theme.ink_muted
			else
				Result := theme.danger
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
			p.text (a_x + 18 * k, l_y, {STRING_32} "simple_prompter " + Version)
			l_y := l_y + 28 * k
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			l_y := wrapped (p, a_x + 18 * k, l_y, script_note, 20 * k) - 8 * k
			open_button_x := 18 * k
			open_button_y := l_y - a_y
			open_button_width := 150 * k
			open_button_height := 28 * k
			p.set_color (theme.accent)
			p.rrect_fill (a_x + open_button_x, a_y + open_button_y, open_button_width, open_button_height, 6 * k)
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.background)
			p.text (a_x + open_button_x + 14 * k, a_y + open_button_y + 19 * k, {STRING_32} "Open script...")
			settings_button_x := open_button_x + open_button_width + 10 * k
			settings_button_width := 110 * k
			p.set_color (if is_settings_shown then theme.accent else theme.outline end)
			p.rrect_fill (a_x + settings_button_x, a_y + open_button_y, settings_button_width, open_button_height, 6 * k)
			p.set_color (if is_settings_shown then theme.background else theme.ink end)
			p.text (a_x + settings_button_x + 14 * k, a_y + open_button_y + 19 * k, {STRING_32} "Settings...")
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			p.text (a_x + settings_button_x + settings_button_width + 14 * k, a_y + open_button_y + 19 * k, {STRING_32} "or drop a script here")
			if is_settings_shown then
				paint_settings_page (p, a_x + 18 * k, l_y + open_button_height, k)
			else
				paint_overview (p, a_x, a_y, l_y + open_button_height + 26 * k, k)
			end
				-- The Edit Floor, in the right-hand column (rows are hit-tested in canvas coordinates).
			p.set_color (theme.outline)
			p.fill_rect (a_x + 520 * k, a_y + 16 * k, 1, Window_height * k - 32 * k)
			edit_floor.paint (p, 540 * k, 0, 480 * k, k)
		end

	paint_overview (p: SW_PAINTER; a_x, a_y, a_from_y, k: REAL_64)
			-- The left column below the buttons: state, speech, camera, keys and mouse help.
		local
			l_y: REAL_64
		do
			l_y := a_from_y
			l_y := wrapped (p, a_x + 18 * k, l_y, {STRING_32} "State: " + state_name + {STRING_32} "    Follows: " + mode_name, 22 * k)
			if speech_state = {PT_SPEECH_SLOT}.Failed then
				p.set_color (theme.danger)
			end
			l_y := wrapped (p, a_x + 18 * k, l_y, {STRING_32} "Speech: " + speech_status, 22 * k)
			p.set_color (camera_color)
			l_y := wrapped (p, a_x + 18 * k, l_y, {STRING_32} "Camera: " + camera_status, 22 * k)
			if prompter.controller.is_recording and not video_status.is_empty then
				p.set_color (if video_stalled then theme.danger else theme.success end)
				l_y := wrapped (p, a_x + 18 * k, l_y, {STRING_32} "Video: " + video_status, 22 * k)
			end
			p.set_color (theme.ink_muted)
			if not mode_note.is_empty then
				p.set_color (theme.danger)
				l_y := wrapped (p, a_x + 18 * k, l_y, mode_note, 22 * k)
				p.set_color (theme.ink_muted)
			end
			if not take_note.is_empty then
				l_y := wrapped (p, a_x + 18 * k, l_y, take_note, 22 * k)
			end
			l_y := wrapped (p, a_x + 18 * k, l_y, {STRING_32} "Pill: " + (if pill.is_shown then {STRING_32} "shown" else {STRING_32} "hidden" end)
				+ {STRING_32} ", " + pill.capture_note
				+ (if pill.is_click_through then {STRING_32} ", click-through" else {STRING_32} "" end), 22 * k) + 10 * k
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
			p.text (a_x + 30 * k, l_y, {STRING_32} "right-click: go    wheel: back / forward")
			l_y := l_y + 20 * k
			p.text (a_x + 30 * k, l_y, {STRING_32} "hold Shift: drag to move, drag an edge or corner to size")
			across router.refused as ic loop
				p.set_color (theme.danger)
				l_y := wrapped (p, a_x + 18 * k, l_y + 22 * k, ic, 22 * k) - 22 * k
			end
			l_y := l_y + 30 * k
			p.set_color (theme.ink_muted)
			p.text (a_x + 18 * k, l_y, {STRING_32} "Close this window to quit.")
		end

	paint_settings_page (p: SW_PAINTER; a_left, a_top, k: REAL_64)
			-- The Settings page in the control window's left column.
		do
			paint_settings_content (p, a_left, a_top, Left_column_width * k, k, Void)
		end

	paint_settings_content (p: SW_PAINTER; a_left, a_top, a_width, k: REAL_64; a_callout: detachable PT_CALLOUT)
			-- The Settings page: camera and microphone lists, the sync start, the tooltips switch, Done.
			-- In `a_callout', every target also gets its tooltip.
		local
			l_i: INTEGER
			l_name, l_tip: STRING_32
			l_found: BOOLEAN
		do
			settings_page.set_locked (prompter.controller.is_recording)
			settings_page.set_tooltips_on (settings.shows_tooltips)
			settings_page.lay_out (a_left, a_top, a_width, k)
			p.font (p.Role_ui, 16, True)
			p.set_color (theme.ink)
			p.text (a_left, settings_page.title_y, {STRING_32} "Settings")
			p.font (p.Role_ui, 13, False)
			if settings_page.is_locked then
				p.set_color (theme.warning)
				p.text (a_left + 90 * k, settings_page.title_y, {STRING_32} "locked while a take records")
			else
				p.set_color (theme.ink_muted)
				p.text (a_left + 90 * k, settings_page.title_y, {STRING_32} "click to choose; saved at once")
			end
			settings_heading (p, a_left, settings_page.camera_heading_y, {STRING_32} "Camera (the picture)", k)
			settings_heading (p, a_left, settings_page.microphone_heading_y, {STRING_32} "Microphone (the sound)", k)
			settings_heading (p, a_left, settings_page.delay_heading_y, {STRING_32} "Sync: where each new take starts", k)
			across settings_page.zones as ic loop
				create l_tip.make_empty
				if settings_page.is_camera_row (ic.code) then
					l_i := ic.code - settings_page.Camera_base
					l_name := settings_page.cameras [l_i]
					l_found := l_i <= settings_page.found_cameras
					settings_row (p, ic.x, ic.y, ic.w, ic.h, settings_page.device_text (l_name, l_found),
						l_name.same_string (settings_page.camera), l_found, k)
					l_tip := {STRING_32} "Record the picture from " + l_name
						+ (if l_found then {STRING_32} "" else {STRING_32} " (Windows does not offer it now)" end)
				elseif settings_page.is_microphone_row (ic.code) then
					l_i := ic.code - settings_page.Microphone_base
					l_name := settings_page.microphones [l_i]
					l_found := l_i <= settings_page.found_microphones
					settings_row (p, ic.x, ic.y, ic.w, ic.h, settings_page.device_text (l_name, l_found),
						l_name.same_string (settings_page.microphone), l_found, k)
					l_tip := {STRING_32} "Record the sound from " + l_name + {STRING_32} " (voice following listens to it too)"
				elseif ic.code = settings_page.Delay_down_hit or ic.code = settings_page.Delay_up_hit then
					p.set_color (theme.outline)
					p.rrect_fill (ic.x, ic.y, ic.w, ic.h, 6 * k)
					p.set_color (if settings_page.is_locked then theme.ink_muted else theme.ink end)
					p.font (p.Role_ui, 15, True)
					p.text (ic.x + ic.w / 2 - 4 * k, ic.y + 19 * k, (if ic.code = settings_page.Delay_down_hit then {STRING_32} "-" else {STRING_32} "+" end))
					if ic.code = settings_page.Delay_down_hit then
						p.font (p.Role_ui, 14, True)
						p.set_color (theme.ink)
						p.text (ic.x + ic.w + 18 * k, ic.y + 19 * k, settings_page.delay_text)
						l_tip := {STRING_32} "New takes start with the picture 10 ms later"
					else
						l_tip := {STRING_32} "New takes start with the picture 10 ms earlier"
					end
				elseif ic.code = settings_page.Tooltips_hit then
					settings_row (p, ic.x, ic.y, ic.w, ic.h, {STRING_32} "Show tooltips", settings_page.is_tooltips_on, True, k)
					l_tip := (if settings_page.is_tooltips_on then {STRING_32} "Turn tooltips off (turn them back on here)" else {STRING_32} "Turn tooltips on" end)
				elseif ic.code = settings_page.Done_hit then
					p.set_color (theme.accent)
					p.rrect_fill (ic.x, ic.y, ic.w, ic.h, 6 * k)
					p.font (p.Role_ui, 13, True)
					p.set_color (theme.background)
					p.text (ic.x + 36 * k, ic.y + 19 * k, {STRING_32} "Done")
					l_tip := {STRING_32} "Close Settings"
				end
				if attached a_callout as al_c and then not l_tip.is_empty then
					al_c.add_zone (ic.code, ic.x, ic.y, ic.w, ic.h, l_tip)
				end
			end
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			l_name := {STRING_32} "How far the picture runs behind the sound. Adjust or Measure any take in Last take; your last choice starts the next take."
			if attached a_callout as al_c then
				al_c.set_content_height (settings_page.bottom)
				if wrap_to (p, a_left, settings_page.hint_y, a_width, l_name, 18 * k) > 0 then
				end
			elseif wrapped (p, a_left, settings_page.hint_y, l_name, 18 * k) > 0 then
			end
		end

	settings_heading (p: SW_PAINTER; a_x, a_y: REAL_64; a_text: STRING_32; k: REAL_64)
		do
			p.font (p.Role_ui, 13, True)
			p.set_color (theme.ink)
			p.text (a_x, a_y, a_text)
		end

	settings_row (p: SW_PAINTER; a_x, a_y, a_w, a_h: REAL_64; a_text: STRING_32; a_chosen, a_found: BOOLEAN; k: REAL_64)
			-- One device row: a radio dot and the name; the chosen row on a light slab.
		do
			if a_chosen then
				p.set_color (theme.outline)
				p.rrect_fill (a_x - 6 * k, a_y + 1 * k, a_w, a_h - 2 * k, 5 * k)
			end
			p.set_color (if a_chosen then theme.accent else theme.ink_muted end)
			p.set_line_width (1.5 * k)
			p.rrect_stroke (a_x + 2 * k, a_y + 7 * k, 12 * k, 12 * k, 6 * k)
			if a_chosen then
				p.rrect_fill (a_x + 5 * k, a_y + 10 * k, 6 * k, 6 * k, 3 * k)
			end
			p.font (p.Role_ui, 13, a_chosen)
			p.set_color (if not a_found then theme.danger elseif a_chosen then theme.ink else theme.ink_muted end)
			p.text (a_x + 24 * k, a_y + 18 * k, a_text)
		end

	Left_column_width: REAL_64 = 486.0
			-- Text width of the left column, design pixels (the divider is at 520).

	wrapped (p: SW_PAINTER; a_x, a_y: REAL_64; a_text: READABLE_STRING_32; a_step: REAL_64): REAL_64
			-- Draw `a_text' from (`a_x', `a_y'), wrapped to the left column; answer the y below it.
		local
			l_y: REAL_64
		do
			l_y := a_y
			across (create {PT_WRAP}).lines (p, a_text, Left_column_width * theme.text_scale) as ic loop
				p.text (a_x, l_y, ic)
				l_y := l_y + a_step
			end
			Result := l_y
		ensure
			moved_down: Result > a_y
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

feature {NONE} -- Pill size

	grips_shown: BOOLEAN
			-- Are the pill's resize grips drawn (Shift held)?

	on_pill_resized (a_width, a_height: INTEGER)
			-- The reader finished a Shift+drag: snap the pill to whole lines and lay the script
			-- out again at the new column width.
		do
			if a_width > 0 and a_height > 0 then
				pill.apply_resize (a_width, a_height)
				prompter.set_column_width (pill.column_width)
				geometry := new_geometry
				last_signature := -1
				on_tick
			end
		end

feature {NONE} -- Speech

	speech_slot: separate PT_SPEECH_SLOT
			-- Where the speech worker leaves what it heard.

	codec: PT_SPEECH_CODEC
	incoming: STRING_8
			-- Records taken from the slot this tick.

	speech_state: INTEGER
			-- The worker's state as last seen (a PT_SPEECH_SLOT state; 0 before the worker runs).

	speech_status: STRING_32
			-- What the worker says it is doing.

	camera_verdict: INTEGER
			-- The worker's last camera check (a PT_CAMERA_CHECK verdict).

	camera_dark: BOOLEAN
			-- Was it live but dim?

	camera_status: STRING_32
			-- The last camera check, for the Camera line.

	video_stalled: BOOLEAN
			-- Has the running recording's video stopped?

	video_status: STRING_32
			-- The running recording's video, for the Video line.

	speech_samples: INTEGER_64
			-- Microphone samples the worker has consumed: the recording clock.

	speech_stopped: BOOLEAN
	speech_started: BOOLEAN
	listen_asked: BOOLEAN
	fell_back: BOOLEAN
	prompt_at: INTEGER
			-- Reader position the decoder's prompt was last built for.

	mode_note: STRING_32
			-- Why a mode switch did not happen, or that voice following is unavailable.

	Model_name: STRING_32 = "ggml-large-v3-turbo-q5_0.bin"
	Vad_name: STRING_32 = "ggml-silero-v6.2.0.bin"
	Developer_models: STRING_32 = "D:\prod\simple_speech\models\"
	Chocolatey_ffmpeg: STRING_32 = "C:\ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe"

	start_speech
			-- Start the speech worker on its own processor; it loads the models there,
			-- so the window opens at once.
		local
			l_model, l_vad: STRING_32
			l_worker: separate PT_SPEECH_WORKER
		do
			l_model := first_existing (<<program_folder + {STRING_32} "\models\" + Model_name, Developer_models + Model_name>>)
			l_vad := first_existing (<<program_folder + {STRING_32} "\models\" + Vad_name, Developer_models + Vad_name>>)
			if l_model.is_empty or l_vad.is_empty then
				speech_state := {PT_SPEECH_SLOT}.Failed
				speech_status := {STRING_32} "the speech models were not found (" + Model_name + {STRING_32} ", " + Vad_name + {STRING_32} ")"
			else
				if settings.camera_name.is_empty then
					camera_status := {STRING_32} "none set (settings.toml: camera = %"OBS Virtual Camera%" or your webcam)"
				end
				create l_worker.make (ffmpeg_path, settings.camera_name, settings.microphone_name, tee_path, l_model, l_vad)
				launch (l_worker, speech_slot)
				speech_started := True
			end
		end

	poll_speech (a_now: REAL_64)
			-- Take what the worker heard and feed it while reading; keep the recording clock
			-- and the already-read prompt current; start the microphone once the models are ready.
		local
			l_voice, l_reading: BOOLEAN
		do
			if speech_started then
				take_speech (speech_slot)
				l_voice := prompter.mode /= {PT_FOLLOW_MODE}.Constant
				l_reading := l_voice and prompter.controller.state = {PT_TAKE_STATE}.Reading
				if not incoming.is_empty then
					across incoming.split ('%N') as ic loop
						if not ic.is_empty then
							codec.decode (ic)
							if l_reading then
								if attached codec.last_frame as al_frame then
									prompter.feed_voice (al_frame)
								elseif attached codec.last_heard as al_heard then
									prompter.feed_heard (al_heard)
								end
							end
						end
					end
				end
				if speech_stream /= stream_seen then
						-- A new capture: its sample clock starts at zero.
					stream_seen := speech_stream
					prompter.recording_clock.restart (a_now)
					prompt_at := 0
					if record_pending then
						recording_live := True
					end
				end
				if not (record_pending and not recording_live)
					and then speech_samples * 4 > prompter.recording_clock.byte_count and a_now >= prompter.recording_clock.observed_at_ms then
						-- While a recording is starting, the old stream's samples are not recording time.
					prompter.recording_clock.observe_bytes (speech_samples * 4, a_now)
				end
				if l_reading and then prompter.controller.reader_position /= prompt_at then
					prompt_at := prompter.controller.reader_position
					send_prompt (speech_slot, prompter.prompt_text)
				end
				if l_voice and not listen_asked and speech_state = {PT_SPEECH_SLOT}.Ready then
					ask_listen (speech_slot)
					listen_asked := True
				end
				follow_take (a_now)
			end
			if speech_state = {PT_SPEECH_SLOT}.Failed and not fell_back and prompter.mode /= {PT_FOLLOW_MODE}.Constant
				and prompter.controller.state = {PT_TAKE_STATE}.Idle then
					-- No voice following: constant speed for now, so the pill still moves (not saved).
				fell_back := True
				apply_mode ({PT_FOLLOW_MODE}.Constant)
				mode_note := {STRING_32} "Voice following is unavailable, so the text moves at a constant speed."
			end
		end

	stop_speech
			-- Ask the worker to stop (it stops ffmpeg and frees the GPU) and give it a moment.
		local
			l_waited: INTEGER
		do
			if speech_started then
				ask_stop (speech_slot)
				from
					take_speech (speech_slot)
				until
					speech_stopped or l_waited >= 3_000
				loop
					(create {EXECUTION_ENVIRONMENT}).sleep (50_000_000)
					l_waited := l_waited + 50
					take_speech (speech_slot)
				end
			end
		end

	switch_mode
			-- Ctrl+Alt+M: your voice <-> constant speed, while stopped.
		do
			if prompter.controller.state /= {PT_TAKE_STATE}.Idle then
				mode_note := {STRING_32} "Stop first (Ctrl+Alt+P), then switch the follow mode (Ctrl+Alt+M)."
			elseif prompter.mode = {PT_FOLLOW_MODE}.Constant then
				settings.set_follow_mode ({PT_FOLLOW_MODE}.Tracking)
				apply_mode ({PT_FOLLOW_MODE}.Tracking)
				mode_note := {STRING_32} ""
			else
				settings.set_follow_mode ({PT_FOLLOW_MODE}.Constant)
				apply_mode ({PT_FOLLOW_MODE}.Constant)
				mode_note := {STRING_32} ""
			end
			window.request_render
			on_tick
		end

	apply_mode (a_mode: INTEGER)
			-- Follow in `a_mode' (the script reloads with a follower of that mode).
		require
			known: a_mode >= {PT_FOLLOW_MODE}.Constant and a_mode <= {PT_FOLLOW_MODE}.Tracking
			idle: prompter.controller.state = {PT_TAKE_STATE}.Idle
		do
			prompter.set_mode (a_mode)
			prompter.controller.set_count_in (settings.count_in_seconds)
			geometry := new_geometry
			previous_state := prompter.controller.state
			prompt_at := 0
			last_signature := -1
			last_status := {STRING_32} ""
		ensure
			set: prompter.mode = a_mode
		end

	mode_name: STRING_32
		do
			inspect prompter.mode
			when {PT_FOLLOW_MODE}.Constant then
				Result := {STRING_32} "constant speed, " + settings.speed_wpm.out + {STRING_32} " wpm"
			when {PT_FOLLOW_MODE}.Voice_gated then
				Result := {STRING_32} "your voice (moves while you speak)"
			else
				Result := {STRING_32} "your voice, word by word"
			end
		end

	ffmpeg_path: STRING_32
			-- The ffmpeg the speech worker and the Edit Floor run.

	edit_floor: PT_EDIT_FLOOR
			-- The last take: cuts, things to check, preview, render (Step 4c).

	resolved_ffmpeg: STRING_32
			-- ffmpeg beside the program, else Chocolatey's, else ffmpeg.exe on PATH.
		do
			Result := first_existing (<<program_folder + {STRING_32} "\ffmpeg.exe", Chocolatey_ffmpeg>>)
			if Result.is_empty then
				Result := {STRING_32} "ffmpeg.exe"
			end
		ensure
			present: not Result.is_empty
		end

	tee_path: STRING_32
			-- Where ffmpeg writes the microphone for the worker (removed when it stops).
		do
			if attached (create {EXECUTION_ENVIRONMENT}).temporary_directory_path as al_temp then
				Result := al_temp.extended ("simple_prompter_live.f32").name
			else
				Result := program_folder + {STRING_32} "\simple_prompter_live.f32"
			end
		end

feature {NONE} -- Take Studio (plan Step 4a)

	take_note: STRING_32
			-- The current or last take, for the control window.

	record_pending: BOOLEAN
			-- Has a recording been requested and not yet finished?

	recording_live: BOOLEAN
			-- Has the recording's stream started (so reading may begin)?

	finish_asked: BOOLEAN
	recording_finished: BOOLEAN
	recorded_seconds: REAL_64
	publish_pending: BOOLEAN
			-- Has a publish been asked for and not yet finished?
	publish_finished: BOOLEAN
	publish_summary: STRING_32
		attribute
			create Result.make_empty
		end
	analysis_pending: BOOLEAN
	analysis_finished: BOOLEAN
	analysis_summary: STRING_32
		attribute
			create Result.make_empty
		end
	off_road: BOOLEAN
			-- Speaking for a while with nothing matching the script (Larry's idea I-1)?

	Off_road_s: REAL_64 = 2.0
			-- Seconds of speech without a matched word before the pill says OFF SCRIPT.
	speech_stream, stream_seen: INTEGER

	start_take
			-- Ctrl+Alt+R: open a session folder and record a take (camera + microphone).
		local
			l_folder: PT_SESSION_FOLDER
		do
			if prompter.controller.state /= {PT_TAKE_STATE}.Idle or record_pending then
				mode_note := {STRING_32} "Stop first (Ctrl+Alt+P), then record (Ctrl+Alt+R)."
			elseif not speech_started or speech_state = {PT_SPEECH_SLOT}.Failed then
				mode_note := {STRING_32} "Recording needs the speech worker (see Speech:)."
			else
				create l_folder.make (new_session_root)
				prompter.start_session (l_folder)
					-- Recording time starts now: events journaled before the camera's stream arrives
					-- read 0, not the listening stream's clock (found in the Step 4a end-to-end run).
				prompter.recording_clock.restart (clock.now_ms)
				prompter.perform ({PT_ACTION}.Record)
				previous_state := {PT_TAKE_STATE}.Idle
				record_pending := True
				recording_live := False
				finish_asked := False
				recording_finished := False
				ask_record (speech_slot, l_folder.raw_path, l_folder.tee_path)
				mode_note := {STRING_32} ""
				take_note := {STRING_32} "Recording to " + l_folder.root
				last_signature := -1
			end
			window.request_render
			on_tick
		end

	follow_take (a_now: REAL_64)
			-- Each tick: after Wrap or Abort, finish the recording; when it is closed, complete the take.
		do
			if record_pending and not finish_asked and prompter.has_session and not prompter.controller.is_recording then
				ask_finish (speech_slot)
				finish_asked := True
			end
			if recording_finished then
				recording_finished := False
				record_pending := False
				recording_live := False
				finish_asked := False
				if prompter.controller.state = {PT_TAKE_STATE}.Analyzing and recorded_seconds > 0 and prompter.has_session then
						-- Wrap: the worker analyzes the take (debate 01) before it is complete.
					ask_analysis (speech_slot, prompter.session.folder.root, recorded_seconds)
					analysis_pending := True
					take_note := {STRING_32} "Analyzing the take (" + clock_text (recorded_seconds) + {STRING_32} ")..."
				else
					complete_take ({STRING_32} "not analyzed")
				end
				last_signature := -1
				window.request_render
			end
			if analysis_finished then
				analysis_finished := False
				analysis_pending := False
				complete_take (analysis_summary)
				last_signature := -1
				window.request_render
			end
			if publish_pending then
				if publish_finished then
					publish_finished := False
					publish_pending := False
					edit_floor.set_publish_status (publish_summary, False)
				elseif speech_state = {PT_SPEECH_SLOT}.Publishing then
					edit_floor.set_publish_status (speech_status, True)
				end
			end
		end

	publish_take
			-- Publish clicked in the Last take panel: the speech worker publishes the take shown
			-- (0.5.0, PT_PUBLISH_JOB), with the publish settings.
		do
			if not publish_pending and then attached edit_floor.take_root as al_root then
				ask_publish (speech_slot, al_root, settings.publish_link, settings.publish_hashtags,
					settings.ollama_url, settings.ollama_model, settings.uses_ollama)
				publish_pending := True
				edit_floor.set_publish_status ((if speech_state = {PT_SPEECH_SLOT}.Ready or speech_state = {PT_SPEECH_SLOT}.Listening
					then {STRING_32} "publishing: starting" else {STRING_32} "publishing: waiting for the speech models" end), True)
			end
		end

	complete_take (a_outcome: READABLE_STRING_32)
			-- The take is done: close the session (Analysis_done first if it was waiting).
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Analyzing then
				prompter.perform ({PT_ACTION}.Analysis_done)
			end
			if prompter.has_session and then not prompter.controller.is_recording then
				take_note := {STRING_32} "Take saved (" + clock_text (recorded_seconds) + {STRING_32} "), " + a_outcome
				edit_floor.show (prompter.session.folder.root, settings.video_delay_ms)
				prompter.end_session
				previous_state := prompter.controller.state
				geometry := new_geometry
			end
		end

	follow_road
			-- Larry's idea I-1: say OFF SCRIPT while he speaks with nothing matching the script, and
			-- clear it the moment the script matches again (the follower already holds still).
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Reading and then prompter.mode = {PT_FOLLOW_MODE}.Tracking
				and then attached {PT_TRACKING_FOLLOWER} prompter.follower as al_t then
				if al_t.is_speaking and al_t.has_alignment and al_t.seconds_since_anchor > Off_road_s then
					off_road := True
				elseif al_t.seconds_since_anchor < 0.5 then
					off_road := False
				end
			else
				off_road := False
			end
		end

	sessions_base: STRING_32
			-- Where session folders go: the setting, else %USERPROFILE%\Videos\simple_prompter.
		do
			if not settings.sessions_root.is_empty then
				Result := settings.sessions_root.twin
			elseif attached (create {EXECUTION_ENVIRONMENT}).item ("USERPROFILE") as al_home then
				Result := al_home + {STRING_32} "\Videos\simple_prompter"
			else
				Result := program_folder + {STRING_32} "\sessions"
			end
		end

	show_latest_take
			-- At start, the Last take panel shows the newest analyzed take (folder names begin with the
			-- date and time, so the greatest name is the newest), to render, preview or measure it again.
		local
			l_dir: DIRECTORY
			l_best, l_root: STRING_32
		do
			create l_best.make_empty
			create l_dir.make (sessions_base)
			if l_dir.exists then
				across l_dir.entries as ic loop
					l_root := sessions_base + {STRING_32} "\" + ic.name
					if not ic.is_current_symbol and not ic.is_parent_symbol and then ic.name > l_best
						and then (create {SIMPLE_FILE}.make (l_root + {STRING_32} "\analysis\analysis.json")).exists
						and then (create {SIMPLE_FILE}.make (l_root + {STRING_32} "\raw.mkv")).exists then
						l_best := ic.name.twin
					end
				end
				if not l_best.is_empty then
					edit_floor.show (sessions_base + {STRING_32} "\" + l_best, settings.video_delay_ms)
				end
			end
		end

	new_session_root: STRING_32
			-- A fresh folder: <sessions root>\<date time> - <script title>.
		local
			l_base, l_title: STRING_32
			l_now: SIMPLE_DATE_TIME
		do
			l_base := sessions_base
			create l_now.make_now
			l_title := prompter.history.current_revision.title.twin
			across <<'\', '/', ':', '*', '?', '"', '<', '>', '|'>> as ic loop
				l_title.replace_substring_all (create {STRING_32}.make_filled (ic, 1), {STRING_32} "-")
			end
			if l_title.count > 60 then
				l_title.keep_head (60)
			end
			Result := l_base + {STRING_32} "\" + l_now.year.out + {STRING_32} "-" + two (l_now.month) + {STRING_32} "-" + two (l_now.day)
				+ {STRING_32} " " + two (l_now.hour) + two (l_now.minute) + two (l_now.second) + {STRING_32} " - " + l_title
		ensure
			no_trailing_separator: Result [Result.count] /= '\'
		end

	folder_leaf (a_root: STRING_32): STRING_32
			-- The last part of `a_root'.
		do
			if attached (create {PATH}.make_from_string (a_root)).entry as al_entry then
				Result := al_entry.name
			else
				Result := a_root
			end
		end

	two (a_n: INTEGER): STRING_32
		do
			Result := a_n.out.to_string_32
			if a_n < 10 then
				Result.prepend_character ('0')
			end
		end

	clock_text (a_seconds: REAL_64): STRING_32
			-- m:ss
		local
			l_s: INTEGER
		do
			l_s := a_seconds.truncated_to_integer.max (0)
			Result := (l_s // 60).out.to_string_32 + {STRING_32} ":" + two (l_s \\ 60)
		end

feature {NONE} -- Speech: separate calls (each locks the slot for one short call)

	launch (a_worker: separate PT_SPEECH_WORKER; a_slot: separate PT_SPEECH_SLOT)
			-- Hand the worker its slot and start it; `run' proceeds on the worker's processor.
		do
			a_worker.attach_slot (a_slot)
			a_worker.run
		end

	take_speech (a_slot: separate PT_SPEECH_SLOT)
			-- Copy what is waiting into `incoming' and the worker's state into this processor.
		do
			incoming.wipe_out
			speech_stream := a_slot.stream
			if a_slot.recording_finished then
				recording_finished := True
				recorded_seconds := a_slot.recorded_seconds
				a_slot.acknowledge_finished
			end
			if a_slot.analysis_finished then
				analysis_finished := True
				create analysis_summary.make_from_separate (a_slot.analysis_summary)
				a_slot.acknowledge_analysis
			end
			if a_slot.publish_finished then
				publish_finished := True
				create publish_summary.make_from_separate (a_slot.publish_summary)
				a_slot.acknowledge_publish
			end
			if not a_slot.records.is_empty then
				incoming.append (create {STRING_8}.make_from_separate (a_slot.records))
				a_slot.clear_records
			end
			speech_state := a_slot.state
			create speech_status.make_from_separate (a_slot.status_text)
			camera_verdict := a_slot.camera_verdict
			camera_dark := a_slot.camera_dark
			if not a_slot.camera_text.is_empty then
				create camera_status.make_from_separate (a_slot.camera_text)
			end
			video_stalled := a_slot.video_stalled
			create video_status.make_from_separate (a_slot.video_text)
			speech_samples := a_slot.samples_heard
			speech_stopped := a_slot.has_stopped
		end

	send_prompt (a_slot: separate PT_SPEECH_SLOT; a_text: STRING_32)
		do
			a_slot.set_prompt (a_text)
		end

	ask_listen (a_slot: separate PT_SPEECH_SLOT)
		do
			a_slot.request_listen
		end

	ask_stop (a_slot: separate PT_SPEECH_SLOT)
		do
			a_slot.request_stop
		end

	ask_record (a_slot: separate PT_SPEECH_SLOT; a_raw, a_tee: STRING_32)
		require
			not_recording: not a_slot.record_requested
		do
			a_slot.request_record (a_raw, a_tee)
		end

	ask_devices (a_slot: separate PT_SPEECH_SLOT; a_camera, a_microphone: STRING_32)
		require
			microphone_present: not a_microphone.is_empty
		do
			a_slot.request_devices (a_camera, a_microphone)
		end

	ask_analysis (a_slot: separate PT_SPEECH_SLOT; a_root: STRING_32; a_duration: REAL_64)
		require
			idle: not a_slot.analysis_requested
			duration_positive: a_duration > 0
		do
			a_slot.request_analysis (a_root, a_duration)
		end

	ask_publish (a_slot: separate PT_SPEECH_SLOT; a_root, a_link, a_hashtags, a_ai_url, a_ai_model: STRING_32; a_uses_ai: BOOLEAN)
		require
			idle: not a_slot.publish_requested
		do
			a_slot.request_publish (a_root, a_link, a_hashtags, a_ai_url, a_ai_model, a_uses_ai)
		end

	ask_finish (a_slot: separate PT_SPEECH_SLOT)
		do
			if a_slot.record_requested then
				a_slot.request_finish
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
				-- The command line, else the script opened last, else the welcome
				-- script installed beside the program, else the read test (developer
				-- machine), else a built-in sample.
			create l_path.make_empty
			across 1 |..| argument_count as ic loop
				if not argument (ic).starts_with ({STRING_32} "--") then
					l_path := argument (ic)
				end
			end
			if l_path.is_empty or else not (create {SIMPLE_FILE}.make (l_path)).exists then
				l_path := first_existing (<<settings.last_script, program_folder + {STRING_32} "\samples\Welcome to simple_prompter.md", Default_script>>)
			end
			if not l_path.is_empty then
				prompter.open_script (l_path)
			end
			if prompter.has_script then
				note_script (l_path)
			else
				prompter.load_script_text ({STRING_32} "Sample", Sample_text)
				script_note := {STRING_32} "Sample text. Open a script with the button below or Ctrl+Alt+O."
			end
		ensure
			loaded: prompter.has_script
		end

	first_existing (a_paths: ARRAY [READABLE_STRING_32]): STRING_32
			-- The first of `a_paths' that names an existing file, else empty.
		do
			create Result.make_empty
			across a_paths as ic until not Result.is_empty loop
				if not ic.is_empty and then (create {SIMPLE_FILE}.make (ic)).exists then
					Result := ic.to_string_32
				end
			end
		end

	program_folder: STRING_32
			-- Folder holding this program.
		do
			Result := (create {PATH}.make_from_string (command_name)).parent.name
		end

	note_script (a_path: READABLE_STRING_32)
			-- Describe the loaded script for the control window.
		require
			loaded: prompter.has_script
		do
			if attached (create {PATH}.make_from_string (a_path)).entry as al_entry then
				script_note := {STRING_32} "Script: " + al_entry.name
			else
				script_note := {STRING_32} "Script: " + a_path
			end
			script_note.append ({STRING_32} " (" + prompter.history.current_revision.word_count.out + {STRING_32} " words)")
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

	Sample_text: STRING_32 = "This is simple prompter. Press Control Alt P to start, and Control Alt Space to hold. Read aloud and the text follows your voice."

end
