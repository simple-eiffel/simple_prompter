note
	description: "[
		Hotkeys and the mouse on the pill, turned into Take Studio actions.
		Registers the keymap's chords (spec 07 section 2.14) as global hotkeys,
		plus the app's own: speed up and down, open a script, follow mode. Each hotkey becomes a PT_CONTROL,
		the resolver picks the action for the current state, and the action is
		performed only when the controller allows it. App-level controls (hide,
		click-through) go to the pill. Plan Step 1 leaves out Edit (its inline
		editor arrives with recording, Step 4) and the recording-only marks.
		The pill's transport bar (0.3.2) reaches the same actions as the keys:
		`on_bar' acts on a click, `refresh_bar' says which buttons would act now.
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
	Record_id: INTEGER = 104
	Vk_r: INTEGER = 0x52
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
			claim (Record_id, hotkeys.Mod_control | hotkeys.Mod_alt, Vk_r, 0, {STRING_32} "record a take (when stopped)")
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

	set_on_record (a_action: PROCEDURE)
			-- What Ctrl+Alt+R does.
		do
			on_record := a_action
		ensure
			set: on_record = a_action
		end

	on_record: detachable PROCEDURE
			-- Called for the record hotkey.

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
			elseif a_id = Record_id then
				if attached on_record as al_record then
					al_record.call (Void)
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

feature -- Transport bar

	on_bar (a_hit, a_word: INTEGER)
			-- A click on the pill's transport bar: button `a_hit', or the progress line
			-- (then `a_word' is the word it points at).
		require
			known: a_hit = {PT_TRANSPORT_BAR}.Progress_hit or (a_hit >= 1 and a_hit <= {PT_TRANSPORT_BAR}.Button_count)
			word_for_jump: a_hit = {PT_TRANSPORT_BAR}.Progress_hit implies
				(a_word >= 1 and a_word <= prompter.history.current_revision.word_count)
		local
			l_idle: BOOLEAN
		do
			l_idle := prompter.controller.state = {PT_TAKE_STATE}.Idle
			inspect a_hit
			when {PT_TRANSPORT_BAR}.Back_button then
				hold_if_reading
				try_action ({PT_ACTION}.Back)
			when {PT_TRANSPORT_BAR}.Forward_button then
				hold_if_reading
				try_action ({PT_ACTION}.Forward)
			when {PT_TRANSPORT_BAR}.Again_button then
				on_control ({PT_CONTROL}.Again)
			when {PT_TRANSPORT_BAR}.Play_button then
				if l_idle then
					on_control ({PT_CONTROL}.Play_stop)
				else
					on_control ({PT_CONTROL}.Hold_toggle)
				end
			when {PT_TRANSPORT_BAR}.Record_button then
				if not l_idle then
					on_control ({PT_CONTROL}.Wrap)
				elseif attached on_record as al_record then
					al_record.call (Void)
				end
			when {PT_TRANSPORT_BAR}.Star_button then
				on_control ({PT_CONTROL}.Star)
			when {PT_TRANSPORT_BAR}.Reject_button then
				on_control ({PT_CONTROL}.Reject)
			when {PT_TRANSPORT_BAR}.Slower_button then
				if is_constant then
					change_speed (-Speed_step)
				end
			when {PT_TRANSPORT_BAR}.Faster_button then
				if is_constant then
					change_speed (Speed_step)
				end
			when {PT_TRANSPORT_BAR}.Progress_hit then
				hold_if_reading
				if prompter.controller.state = {PT_TAKE_STATE}.Held then
					prompter.controller.pick_word (a_word)
				end
			end
		end

	refresh_bar (a_bar: PT_TRANSPORT_BAR)
			-- Which buttons would act now, what the play and record buttons show, how far through.
		local
			l_state: INTEGER
			l_idle, l_reading, l_held, l_steps: BOOLEAN
		do
			l_state := prompter.controller.state
			l_idle := l_state = {PT_TAKE_STATE}.Idle
			l_held := l_state = {PT_TAKE_STATE}.Held
			l_reading := l_state = {PT_TAKE_STATE}.Reading or l_state = {PT_TAKE_STATE}.Count_in
			l_steps := l_held or (l_reading and prompter.controller.is_allowed ({PT_ACTION}.Hold))
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Back_button, l_steps)
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Forward_button, l_steps)
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Again_button, resolves ({PT_CONTROL}.Again))
			if l_idle then
				a_bar.set_enabled ({PT_TRANSPORT_BAR}.Play_button, resolves ({PT_CONTROL}.Play_stop))
				a_bar.set_enabled ({PT_TRANSPORT_BAR}.Record_button,
					on_record /= Void and prompter.controller.is_allowed ({PT_ACTION}.Record))
			else
				a_bar.set_enabled ({PT_TRANSPORT_BAR}.Play_button, resolves ({PT_CONTROL}.Hold_toggle))
				a_bar.set_enabled ({PT_TRANSPORT_BAR}.Record_button, resolves ({PT_CONTROL}.Wrap))
			end
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Star_button, resolves ({PT_CONTROL}.Star))
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Reject_button, resolves ({PT_CONTROL}.Reject))
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Slower_button, is_constant and settings.speed_wpm > settings.Min_wpm)
			a_bar.set_enabled ({PT_TRANSPORT_BAR}.Faster_button, is_constant and settings.speed_wpm < settings.Max_wpm)
			a_bar.set_transport (l_reading, not l_idle, prompter.controller.is_recording)
			a_bar.set_progress (prompter.scroll.position, prompter.history.current_revision.word_count)
		end

feature -- Status

	is_constant: BOOLEAN
			-- Is the pill following at a constant speed (so the speed buttons apply)?
		do
			Result := prompter.mode = {PT_FOLLOW_MODE}.Constant
		end

	Step_one_controls: ARRAY [INTEGER]
			-- Controls live in plan Step 1, in registration (hotkey id) order.
		once
			Result := <<{PT_CONTROL}.Play_stop, {PT_CONTROL}.Hold_toggle, {PT_CONTROL}.Again, {PT_CONTROL}.Go,
				{PT_CONTROL}.Back, {PT_CONTROL}.Forward, {PT_CONTROL}.Hide, {PT_CONTROL}.Click_through,
				{PT_CONTROL}.Wrap, {PT_CONTROL}.Star, {PT_CONTROL}.Reject, {PT_CONTROL}.Marker>>
				-- Step 4a appended the take controls at the end, so earlier hotkey ids stay put.
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

	hold_if_reading
			-- Reading or counting in: hold first, so a step or a jump has a caret to move.
		do
			if prompter.controller.state = {PT_TAKE_STATE}.Reading or prompter.controller.state = {PT_TAKE_STATE}.Count_in then
				try_action ({PT_ACTION}.Hold)
			end
		end

	resolves (a_control: INTEGER): BOOLEAN
			-- Would `a_control' perform an action now?
		do
			Result := resolver.action_for (a_control, prompter.controller.state, prompter.controller.is_recording) /= 0
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
			when {PT_CONTROL}.Wrap then Result := {STRING_32} "wrap the take (recording) / stop (practice)"
			when {PT_CONTROL}.Star then Result := {STRING_32} "star: keep this take (recording)"
			when {PT_CONTROL}.Reject then Result := {STRING_32} "reject this take (recording)"
			when {PT_CONTROL}.Marker then Result := {STRING_32} "marker (recording)"
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
