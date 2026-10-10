note
	description: "[
		simple_prompter, plan Steps 1-3: the pill follows your voice. A small
		control window (state, follow mode, speech, keys) owns the event pump; the
		pill is a capture-excluded panel under the webcam. Speech runs on its own
		processor (PT_SPEECH_WORKER: Silero + whisper on the GPU, ffmpeg on the
		microphone); the 16 ms tick takes what it heard from the slot, feeds the
		facade while reading, keeps the recording clock and the already-read
		prompt current, finishes the count-in, advances the follower and the
		smoothed scroll, and repaints the pill when anything it shows has changed.

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
			geometry := new_geometry
			create status_canvas.make (Window_height * theme.text_scale)
			l_title := {STRING_32} "simple_prompter"
			create window.make (l_title, 80, 160, (Window_width * theme.text_scale).ceiling,
				(Window_height * theme.text_scale).ceiling, theme)
				-- Every attribute is set: only now may agents on Current be made (VEVI).
			status_canvas.set_on_paint (agent paint_status)
			status_canvas.set_on_press (agent on_status_press)
			status_canvas.set_on_files (agent on_files)
			router.set_on_open (agent choose_script)
			router.set_on_mode (agent switch_mode)
			router.set_on_record (agent start_take)
			start_speech
			window.set_root (status_canvas)
			window.set_on_shell_event (agent on_shell_event)
			window.set_on_tick (agent on_heartbeat)
			window.run
				-- The window closed: give everything back.
			edit_floor.close
			stop_speech
			router.release_all
			pill.close
		end

feature -- Constants

	Version: STRING_32 = "0.3.2"
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
				if pill.bar.is_laid_out and then pill.bar.is_in_bar (a_b) then
					on_bar_press (a_a, a_b)
				else
					router.on_press (geometry.word_at (a_a, a_b, prompter.scroll.y_offset))
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
			when {SHELL_PANEL}.Event_moved then
				pill.remember_position (a_a, a_b)
			when {SHELL_PANEL}.Event_resized then
				on_pill_resized (a_a, a_b)
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
			-- Files dropped on the control window: open the first script among them.
		local
			l_done: BOOLEAN
		do
			across a_paths as ic until l_done loop
				if ic.as_lower.ends_with ({STRING_32} ".md") or ic.as_lower.ends_with ({STRING_32} ".txt") then
					open_script_file (ic)
					l_done := True
				end
			end
		end

	on_status_press (a_x, a_y: REAL_64)
			-- A click on the control window: the Open button opens a script.
		do
			if a_x >= open_button_x and a_x <= open_button_x + open_button_width
				and a_y >= open_button_y and a_y <= open_button_y + open_button_height then
				choose_script
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
			-- Where the Open button was last drawn (canvas coordinates).

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
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			p.text (a_x + open_button_x + open_button_width + 14 * k, a_y + open_button_y + 19 * k, {STRING_32} "or drop a .md / .txt file here")
			l_y := l_y + open_button_height + 26 * k
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
				-- The Edit Floor, in the right-hand column (rows are hit-tested in canvas coordinates).
			p.set_color (theme.outline)
			p.fill_rect (a_x + 520 * k, a_y + 16 * k, 1, Window_height * k - 32 * k)
			edit_floor.paint (p, 540 * k, 0, 480 * k, k)
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
		end

	complete_take (a_outcome: READABLE_STRING_32)
			-- The take is done: close the session (Analysis_done first if it was waiting).
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Analyzing then
				prompter.perform ({PT_ACTION}.Analysis_done)
			end
			if prompter.has_session and then not prompter.controller.is_recording then
				take_note := {STRING_32} "Take saved (" + clock_text (recorded_seconds) + {STRING_32} "), " + a_outcome
				edit_floor.show (prompter.session.folder.root)
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

	new_session_root: STRING_32
			-- A fresh folder: <sessions root>\<date time> - <script title>.
		local
			l_base, l_title: STRING_32
			l_now: SIMPLE_DATE_TIME
		do
			if not settings.sessions_root.is_empty then
				l_base := settings.sessions_root.twin
			elseif attached (create {EXECUTION_ENVIRONMENT}).item ("USERPROFILE") as al_home then
				l_base := al_home + {STRING_32} "\Videos\simple_prompter"
			else
				l_base := program_folder + {STRING_32} "\sessions"
			end
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

	ask_analysis (a_slot: separate PT_SPEECH_SLOT; a_root: STRING_32; a_duration: REAL_64)
		require
			idle: not a_slot.analysis_requested
			duration_positive: a_duration > 0
		do
			a_slot.request_analysis (a_root, a_duration)
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
