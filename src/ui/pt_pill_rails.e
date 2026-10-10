note
	description: "[
		The pill's two rails (0.4.0, pill-only UI). The left rail is one Status button
		showing three lights - microphone, camera, voice following - each off, good,
		check or problem; it opens the Status callout. The right rail holds Quit,
		Script, Settings and Last take; a button whose callout is open is lit. Pure
		layout, hits, tooltips (PT_HOVER) and display state; PT_PILL_RENDERER draws it.
	]"
	author: "Larry Rix"

class
	PT_PILL_RAILS

create
	make

feature {NONE} -- Initialization

	make (a_scale: REAL_64)
		require
			scale_positive: a_scale > 0
		do
			scale := a_scale
			create hover.make
			create zones.make (5)
		ensure
			scale_set: scale = a_scale
			not_laid_out: zones.is_empty
		end

feature -- Targets

	Status_hit: INTEGER = 1
	Quit_hit: INTEGER = 2
	Script_hit: INTEGER = 3
	Settings_hit: INTEGER = 4
	Take_hit: INTEGER = 5
	Left_grip_hit: INTEGER = 6
	Right_grip_hit: INTEGER = 7
			-- The side edges: a plain press there sizes the pill (simple_shell 1.14.0).

feature -- Lights

	Light_off: INTEGER = 0
	Light_good: INTEGER = 1
	Light_check: INTEGER = 2
	Light_problem: INTEGER = 3

feature -- Design pixels (times `scale')

	Design_rail: REAL_64 = 54.0
			-- Wide enough that a button never reaches into a side grip.
	Design_button: REAL_64 = 32.0
	Design_quit: REAL_64 = 24.0
	Design_gap: REAL_64 = 6.0
	Design_top: REAL_64 = 8.0
	Design_light_slot: REAL_64 = 30.0
			-- One light (icon and dot) in the Status button.
	Design_side_grip: REAL_64 = 10.0
			-- How near a side edge a press sizes the pill (PT_PILL.Design_grip).

feature -- Access

	scale: REAL_64

	rail_width: REAL_64
			-- Each rail's width, physical pixels.
		do
			Result := Design_rail * scale
		end

	min_text_height: REAL_64
			-- The least height above the transport bar that holds the right rail.
		do
			Result := (2 * Design_top + Design_quit + 4 * Design_gap + 3 * Design_button) * scale
		end

	zones: ARRAYED_LIST [TUPLE [code: INTEGER; x, y, w, h: REAL_64]]
			-- The buttons from the last `lay_out'.

	zone (a_code: INTEGER): detachable TUPLE [code: INTEGER; x, y, w, h: REAL_64]
		do
			across zones as ic until attached Result loop
				if ic.code = a_code then
					Result := ic
				end
			end
		end

	hover: PT_HOVER

	microphone_light, camera_light, follow_light: INTEGER
			-- Each a `Light_*'.

	is_status_open, is_script_open, is_settings_open, is_take_open: BOOLEAN
			-- Which callouts are open (their buttons are lit).

	is_laid_out: BOOLEAN
		do
			Result := not zones.is_empty
		end

feature -- Layout

	lay_out (a_width, a_text_height: REAL_64)
			-- Place the buttons on a pill `a_width' wide whose text area is `a_text_height' high.
		require
			wide_enough: a_width > 2 * rail_width
		local
			l_x, l_y, b: REAL_64
		do
			zones.wipe_out
			b := Design_button * scale
			zones.extend ([Status_hit, (rail_width - b) / 2, Design_top * scale, b,
				(3 * Design_light_slot * scale).min ((a_text_height - 2 * Design_top * scale).max (b))])
			l_x := a_width - rail_width
			zones.extend ([Quit_hit, l_x + (rail_width - Design_quit * scale) / 2, Design_top * scale, Design_quit * scale, Design_quit * scale])
			l_y := (Design_top + Design_quit + 2 * Design_gap) * scale
			zones.extend ([Script_hit, l_x + (rail_width - b) / 2, l_y, b, b])
			l_y := l_y + b + Design_gap * scale
			zones.extend ([Settings_hit, l_x + (rail_width - b) / 2, l_y, b, b])
			l_y := l_y + b + Design_gap * scale
			zones.extend ([Take_hit, l_x + (rail_width - b) / 2, l_y, b, b])
			zones.extend ([Left_grip_hit, 0.0, 0.0, Design_side_grip * scale, a_text_height])
			zones.extend ([Right_grip_hit, a_width - Design_side_grip * scale, 0.0, Design_side_grip * scale, a_text_height])
		ensure
			five_buttons_two_grips: zones.count = 7
		end

	hit (a_x, a_y: REAL_64): INTEGER
			-- The button at (`a_x', `a_y'), or 0.
		do
			across zones as ic until Result /= 0 loop
				if a_x >= ic.x and a_x <= ic.x + ic.w and a_y >= ic.y and a_y <= ic.y + ic.h then
					Result := ic.code
				end
			end
		ensure
			known: Result = 0 or else attached zone (Result)
		end

	is_in_rail (a_x: REAL_64; a_width: REAL_64): BOOLEAN
			-- Is `a_x' on either rail of a pill `a_width' wide?
		do
			Result := a_x < rail_width or a_x > a_width - rail_width
		end

feature -- Tooltips

	tooltip_text (a_code: INTEGER): STRING_32
			-- What button `a_code' does.
		require
			known: a_code >= Status_hit and a_code <= Right_grip_hit
		do
			inspect a_code
			when Status_hit then
				Result := {STRING_32} "Status - microphone " + light_word (microphone_light) + {STRING_32} ", camera "
					+ light_word (camera_light) + {STRING_32} ", following " + light_word (follow_light) + {STRING_32} ". Click for details."
			when Quit_hit then
				Result := {STRING_32} "Quit simple_prompter"
			when Script_hit then
				Result := {STRING_32} "Script: open one, or pick a recent one  (Ctrl+Alt+O)"
			when Settings_hit then
				Result := {STRING_32} "Settings: camera, microphone, sync start, tooltips"
			when Take_hit then
				Result := {STRING_32} "Last take: render it, set its sync, preview cuts and things to check"
			when Left_grip_hit, Right_grip_hit then
				Result := {STRING_32} "Drag this edge to make the pill wider or narrower (Shift+drag the bottom for more lines)"
			end
		end

	light_word (a_light: INTEGER): STRING_32
		do
			inspect a_light
			when Light_good then
				Result := {STRING_32} "OK"
			when Light_check then
				Result := {STRING_32} "needs a look"
			when Light_problem then
				Result := {STRING_32} "has a problem"
			else
				Result := {STRING_32} "not started"
			end
		end

	track (a_x, a_y, a_now_ms: REAL_64)
			-- The pointer is at (`a_x', `a_y') on the pill at `a_now_ms'.
		local
			l_hit: INTEGER
		do
			hover.set_pointer_in (True)
			l_hit := hit (a_x, a_y)
			hover.set_hovered (l_hit, (if l_hit = 0 then {STRING_32} "" else tooltip_text (l_hit) end), a_now_ms)
		end

feature -- Display state

	set_lights (a_microphone, a_camera, a_follow: INTEGER)
		require
			known: a_microphone >= Light_off and a_microphone <= Light_problem
				and a_camera >= Light_off and a_camera <= Light_problem
				and a_follow >= Light_off and a_follow <= Light_problem
		do
			microphone_light := a_microphone
			camera_light := a_camera
			follow_light := a_follow
		ensure
			set: microphone_light = a_microphone and camera_light = a_camera and follow_light = a_follow
		end

	set_open (a_status, a_script, a_settings, a_take: BOOLEAN)
		require
			one_on_the_right: not (a_script and a_settings)
		do
			is_status_open := a_status
			is_script_open := a_script
			is_settings_open := a_settings
			is_take_open := a_take
		end

	signature: INTEGER
			-- Changes whenever anything the rails draw changes.
		do
			Result := microphone_light + 4 * camera_light + 16 * follow_light
				+ (if is_status_open then 64 else 0 end) + (if is_script_open then 128 else 0 end)
				+ (if is_settings_open then 256 else 0 end) + (if is_take_open then 512 else 0 end)
				+ 1024 * hover.signature
		end

invariant
	scale_positive: scale > 0
	lights_known: microphone_light >= Light_off and microphone_light <= Light_problem
		and camera_light >= Light_off and camera_light <= Light_problem
		and follow_light >= Light_off and follow_light <= Light_problem
	one_on_the_right: not (is_script_open and is_settings_open)

end
