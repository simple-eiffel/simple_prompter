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
			create mode_note.make_empty
			create speech_slot.make
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
			start_speech
			window.set_root (status_canvas)
			window.set_on_shell_event (agent on_shell_event)
			window.set_on_tick (agent on_heartbeat)
			window.run
				-- The window closed: give everything back.
			stop_speech
			router.release_all
			pill.close
		end

feature -- Constants

	Version: STRING_32 = "0.2.0"
			-- Shown in the control window; keep in step with installer/simple_prompter.iss.

	Tick_ms: INTEGER = 16
	Window_width: INTEGER = 520
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
				poll_speech (l_now)
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
			else
				create Result.make_empty
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
				+ prompter.mode.out + speech_status + mode_note
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
			p.text (a_x + 18 * k, l_y, {STRING_32} "simple_prompter " + Version)
			l_y := l_y + 28 * k
			p.font (p.Role_ui, 13, False)
			p.set_color (theme.ink_muted)
			p.text (a_x + 18 * k, l_y, script_note)
			l_y := l_y + 12 * k
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
			p.text (a_x + 18 * k, l_y, {STRING_32} "State: " + state_name + {STRING_32} "    Follows: " + mode_name)
			l_y := l_y + 22 * k
			if speech_state = {PT_SPEECH_SLOT}.Failed then
				p.set_color (theme.danger)
			end
			p.text (a_x + 18 * k, l_y, {STRING_32} "Speech: " + speech_status)
			p.set_color (theme.ink_muted)
			l_y := l_y + 22 * k
			if not mode_note.is_empty then
				p.set_color (theme.danger)
				p.text (a_x + 18 * k, l_y, mode_note)
				p.set_color (theme.ink_muted)
				l_y := l_y + 22 * k
			end
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
			l_model, l_vad, l_ffmpeg: STRING_32
			l_worker: separate PT_SPEECH_WORKER
		do
			l_model := first_existing (<<program_folder + {STRING_32} "\models\" + Model_name, Developer_models + Model_name>>)
			l_vad := first_existing (<<program_folder + {STRING_32} "\models\" + Vad_name, Developer_models + Vad_name>>)
			l_ffmpeg := first_existing (<<program_folder + {STRING_32} "\ffmpeg.exe", Chocolatey_ffmpeg>>)
			if l_ffmpeg.is_empty then
				l_ffmpeg := {STRING_32} "ffmpeg.exe"
			end
			if l_model.is_empty or l_vad.is_empty then
				speech_state := {PT_SPEECH_SLOT}.Failed
				speech_status := {STRING_32} "the speech models were not found (" + Model_name + {STRING_32} ", " + Vad_name + {STRING_32} ")"
			else
				create l_worker.make (l_ffmpeg, settings.microphone_name, tee_path, l_model, l_vad)
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
				if speech_samples * 4 > prompter.recording_clock.byte_count and a_now >= prompter.recording_clock.observed_at_ms then
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

	tee_path: STRING_32
			-- Where ffmpeg writes the microphone for the worker (removed when it stops).
		do
			if attached (create {EXECUTION_ENVIRONMENT}).temporary_directory_path as al_temp then
				Result := al_temp.extended ("simple_prompter_live.f32").name
			else
				Result := program_folder + {STRING_32} "\simple_prompter_live.f32"
			end
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
			if not a_slot.records.is_empty then
				incoming.append (create {STRING_8}.make_from_separate (a_slot.records))
				a_slot.clear_records
			end
			speech_state := a_slot.state
			create speech_status.make_from_separate (a_slot.status_text)
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
