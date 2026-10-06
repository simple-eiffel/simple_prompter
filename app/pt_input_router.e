note
	description: "[
		Hotkeys and the mouse on the pill, turned into Take Studio actions.
		Registers the keymap's chords (spec 07 section 2.14) as global hotkeys,
		plus the app's own: speed up and down, open a script, follow mode. Each hotkey becomes a PT_CONTROL,
		the resolver picks the action for the current state, and the action is
		performed only when the controller allows it. App-level controls (hide,
		click-through) go to the pill. Plan Step 1 leaves out Edit (its inline
		editor arrives with recording, Step 4) and the recording-only marks.
	]"
	author: "Larry Rix"

class
	PT_INPUT_ROUTER

create
	make

feature {NONE} -- Initialization

	make (a_prompter: SIMPLE_PROMPTER; a_pill: PT_PILL; a_settings: PT_SETTINGS)
		require
			loaded: a_prompter.has_script
		do
			prompter := a_prompter
			pill := a_pill
			settings := a_settings
			create hotkeys.make
			create resolver.make
			create controls.make (16)
			create key_names.make (16)
			create refused.make (0)
		ensure
			prompter_set: prompter = a_prompter
		end

feature -- Constants

	Speed_up_id: INTEGER = 100
	Speed_down_id: INTEGER = 101
	Open_id: INTEGER = 102
	Vk_o: INTEGER = 0x4F
	Mode_id: INTEGER = 103
	Vk_m: INTEGER = 0x4D
	Speed_step: INTEGER = 10
			-- Words per minute per press.

	Vk_up: INTEGER = 0x26
	Vk_down: INTEGER = 0x28

feature -- Access

	prompter: SIMPLE_PROMPTER
	pill: PT_PILL
	settings: PT_SETTINGS
	hotkeys: SHELL_HOTKEYS
	resolver: PT_CONTROL_RESOLVER

	key_names: ARRAYED_LIST [STRING_32]
			-- "Ctrl+Alt+Space  hold / go" lines for the control window.

	refused: ARRAYED_LIST [STRING_32]
			-- Chords another application already holds.

feature -- Commands

	register_all
			-- Register the keymap's chords and the speed keys.
		local
			l_id: INTEGER
			l_bindings: ARRAYED_LIST [PT_KEY_BINDING]
		do
				-- A fixed order, so hotkey ids are stable: 1 play / stop, 2 hold / go, ...
			l_bindings := (create {PT_KEYMAP}.make_default).all_bindings
			l_id := 1
			across Step_one_controls as ic_control loop
				across l_bindings as ic loop
					if ic.control = ic_control and not ic.is_bare then
						claim (l_id, ic.modifiers.to_integer_32, ic.vkey, ic.control, control_name (ic.control))
						l_id := l_id + 1
					end
				end
			end
			claim (Speed_up_id, hotkeys.Mod_control | hotkeys.Mod_alt, Vk_up, 0, {STRING_32} "faster")
			claim (Speed_down_id, hotkeys.Mod_control | hotkeys.Mod_alt, Vk_down, 0, {STRING_32} "slower")
			claim (Open_id, hotkeys.Mod_control | hotkeys.Mod_alt, Vk_o, 0, {STRING_32} "open a script")
			claim (Mode_id, hotkeys.Mod_control | hotkeys.Mod_alt, Vk_m, 0, {STRING_32} "follow mode: voice / constant speed (when stopped)")
		end

	set_on_open (a_action: PROCEDURE)
			-- What Ctrl+Alt+O does.
		do
			on_open := a_action
		ensure
			set: on_open = a_action
		end

	on_open: detachable PROCEDURE
			-- Called for the open-a-script hotkey.

	set_on_mode (a_action: PROCEDURE)
			-- What Ctrl+Alt+M does.
		do
			on_mode := a_action
		ensure
			set: on_mode = a_action
		end

	on_mode: detachable PROCEDURE
			-- Called for the follow-mode hotkey.

	release_all
		do
			hotkeys.unregister_all
		end

	on_hotkey (a_id: INTEGER)
			-- Hotkey `a_id' was pressed.
		do
			if a_id = Speed_up_id then
				change_speed (Speed_step)
			elseif a_id = Speed_down_id then
				change_speed (-Speed_step)
			elseif a_id = Open_id then
				if attached on_open as al_open then
					al_open.call (Void)
				end
			elseif a_id = Mode_id then
				if attached on_mode as al_mode then
					al_mode.call (Void)
				end
			elseif controls.has (a_id) then
				on_control (controls [a_id])
			end
		end

	on_control (a_control: INTEGER)
			-- A control was used (hotkey, clicker or mouse).
		require
			known: a_control >= {PT_CONTROL}.Hold_toggle and a_control <= {PT_CONTROL}.Click_through
		do
			if a_control = {PT_CONTROL}.Hide then
				pill.toggle_shown
			elseif a_control = {PT_CONTROL}.Click_through then
				pill.toggle_click_through
			else
				try_action (resolver.action_for (a_control, prompter.controller.state, prompter.controller.is_recording))
			end
		end

	on_press (a_word: INTEGER)
			-- Left click on the pill, on word `a_word' (0 = between words).
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Held then
				if a_word >= 1 and a_word <= prompter.history.current_revision.word_count then
					prompter.controller.pick_word (a_word)
				end
			else
				try_action ({PT_ACTION}.Hold)
			end
		end

	on_right_press
			-- Right click on the pill: go when held.
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Held then
				try_action ({PT_ACTION}.Go)
			end
		end

	on_wheel (a_delta: INTEGER)
			-- Wheel on the pill: step back (up) or forward (down) while held.
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Held then
				if a_delta > 0 then
					try_action ({PT_ACTION}.Back)
				elseif a_delta < 0 then
					try_action ({PT_ACTION}.Forward)
				end
			end
		end

feature -- Status

	Step_one_controls: ARRAY [INTEGER]
			-- Controls live in plan Step 1, in registration (hotkey id) order.
		once
			Result := <<{PT_CONTROL}.Play_stop, {PT_CONTROL}.Hold_toggle, {PT_CONTROL}.Again, {PT_CONTROL}.Go,
				{PT_CONTROL}.Back, {PT_CONTROL}.Forward, {PT_CONTROL}.Hide, {PT_CONTROL}.Click_through>>
		end

	is_step_one_control (a_control: INTEGER): BOOLEAN
			-- Is `a_control' live in plan Step 1 (no recording, no inline editor)?
		do
			Result := a_control = {PT_CONTROL}.Hold_toggle or a_control = {PT_CONTROL}.Again
				or a_control = {PT_CONTROL}.Go or a_control = {PT_CONTROL}.Back or a_control = {PT_CONTROL}.Forward
				or a_control = {PT_CONTROL}.Play_stop or a_control = {PT_CONTROL}.Hide
				or a_control = {PT_CONTROL}.Click_through
		end

feature {NONE} -- Implementation

	controls: HASH_TABLE [INTEGER, INTEGER]
			-- Hotkey id -> control.

	claim (a_id, a_modifiers, a_vk, a_control: INTEGER; a_what: READABLE_STRING_32)
			-- Register one chord and record its name (or that it was refused).
		require
			has_modifier: a_modifiers /= 0
		local
			l_line: STRING_32
		do
			hotkeys.register (a_id, a_modifiers, a_vk)
			l_line := chord_name (a_modifiers, a_vk)
			if hotkeys.last_succeeded then
				if a_control /= 0 then
					controls.force (a_control, a_id)
				end
				key_names.extend (l_line + {STRING_32} "  " + a_what)
			else
				refused.extend (l_line + {STRING_32} " (" + a_what + {STRING_32} ") is held by another program")
			end
		end

	try_action (a_action: INTEGER)
			-- Perform `a_action' when it takes no argument and the controller allows it.
		do
			if a_action /= 0 and then not prompter.controller.needs_argument (a_action)
				and then prompter.controller.is_allowed (a_action) then
				prompter.perform (a_action)
			end
		end

	change_speed (a_step: INTEGER)
			-- Constant mode: faster or slower, remembered.
		local
			l_wpm: INTEGER
		do
			l_wpm := (settings.speed_wpm + a_step).max (settings.Min_wpm).min (settings.Max_wpm)
			settings.set_speed_wpm (l_wpm)
			if attached {PT_CONSTANT_FOLLOWER} prompter.follower as al_constant then
				al_constant.set_wpm (l_wpm)
			end
		end

	control_name (a_control: INTEGER): STRING_32
		do
			inspect a_control
			when {PT_CONTROL}.Hold_toggle then Result := {STRING_32} "hold / go"
			when {PT_CONTROL}.Again then Result := {STRING_32} "again (restart the sentence)"
			when {PT_CONTROL}.Go then Result := {STRING_32} "go"
			when {PT_CONTROL}.Back then Result := {STRING_32} "back a sentence (held)"
			when {PT_CONTROL}.Forward then Result := {STRING_32} "forward a sentence (held)"
			when {PT_CONTROL}.Play_stop then Result := {STRING_32} "play / stop"
			when {PT_CONTROL}.Hide then Result := {STRING_32} "hide / show the pill"
			when {PT_CONTROL}.Click_through then Result := {STRING_32} "click-through on / off"
			else
				Result := {STRING_32} "control " + a_control.out
			end
		end

	chord_name (a_modifiers, a_vk: INTEGER): STRING_32
			-- "Ctrl+Alt+Space".
		do
			create Result.make (24)
			if (a_modifiers & hotkeys.Mod_control) /= 0 then Result.append ({STRING_32} "Ctrl+") end
			if (a_modifiers & hotkeys.Mod_alt) /= 0 then Result.append ({STRING_32} "Alt+") end
			if (a_modifiers & hotkeys.Mod_shift) /= 0 then Result.append ({STRING_32} "Shift+") end
			if (a_modifiers & hotkeys.Mod_win) /= 0 then Result.append ({STRING_32} "Win+") end
			inspect a_vk
			when 0x08 then Result.append ({STRING_32} "Backspace")
			when 0x0D then Result.append ({STRING_32} "Enter")
			when 0x20 then Result.append ({STRING_32} "Space")
			when 0x23 then Result.append ({STRING_32} "End")
			when 0x25 then Result.append ({STRING_32} "Left")
			when 0x26 then Result.append ({STRING_32} "Up")
			when 0x27 then Result.append ({STRING_32} "Right")
			when 0x28 then Result.append ({STRING_32} "Down")
			when 0x41 .. 0x5A then Result.append_character (a_vk.to_character_32)
			else
				Result.append ({STRING_32} "key " + a_vk.out)
			end
		end

end
