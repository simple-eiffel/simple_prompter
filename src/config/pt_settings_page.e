note
	description: "[
		The Settings page of the control window (0.3.5): which camera and which
		microphone a take records, and the picture delay (how far the camera's
		picture runs behind the microphone; the recording moves it that much
		earlier). Pure layout and choice state: the app paints it and applies
		each change; this class decides where everything sits and what a click
		hits. The chosen devices are always listed, even when Windows no longer
		offers them, so a missing device shows as missing instead of being
		silently swapped. While a take records, the page is locked.
	]"
	author: "Larry Rix"

class
	PT_SETTINGS_PAGE

create
	make

feature {NONE} -- Initialization

	make
		do
			create cameras.make (4)
			create microphones.make (4)
			create camera.make_empty
			create microphone.make_from_string ({STRING_32} "Microphone")
			create zones.make (16)
		ensure
			nothing_offered: cameras.is_empty and microphones.is_empty
			not_laid_out: zones.is_empty
		end

feature -- Constants: hit targets

	Nothing_hit: INTEGER = 0
	Done_hit: INTEGER = 1
	Delay_down_hit: INTEGER = 2
	Delay_up_hit: INTEGER = 3
	Camera_base: INTEGER = 100
			-- Camera row `i' is Camera_base + i.
	Microphone_base: INTEGER = 200
			-- Microphone row `i' is Microphone_base + i.

feature -- Constants: design pixels (scaled by `lay_out')

	Delay_step_ms: INTEGER = 10
	Design_title: REAL_64 = 36.0
	Design_heading: REAL_64 = 30.0
	Design_row: REAL_64 = 26.0
	Design_section_gap: REAL_64 = 16.0
	Design_step_button: REAL_64 = 30.0
	Design_value_width: REAL_64 = 90.0
	Design_done_width: REAL_64 = 110.0
	Design_done_height: REAL_64 = 28.0

feature -- Access

	cameras, microphones: ARRAYED_LIST [STRING_32]
			-- What the page lists (Windows' devices, plus the chosen one when Windows lacks it).

	camera, microphone: STRING_32
			-- The chosen devices.

	video_delay_ms: INTEGER
			-- The chosen picture delay.

	found_cameras, found_microphones: INTEGER
			-- How many of the listed devices Windows offers (they come first; a row after them is a
			-- chosen device Windows no longer offers).

	is_camera_found: BOOLEAN
			-- Does Windows offer the chosen camera?
		do
			Result := across 1 |..| found_cameras as ic some cameras [ic].same_string (camera) end
		end

	is_microphone_found: BOOLEAN
			-- Does Windows offer the chosen microphone?
		do
			Result := across 1 |..| found_microphones as ic some microphones [ic].same_string (microphone) end
		end

	is_locked: BOOLEAN
			-- Is a take recording (nothing but Done may change)?

	camera_heading_y, microphone_heading_y, delay_heading_y, hint_y, bottom: REAL_64
			-- Baselines of the section headings and the delay hint; the page's lowest pixel.

	title_y: REAL_64
			-- Baseline of the page title.

	scale: REAL_64
			-- The scale of the last `lay_out'.

	zones: ARRAYED_LIST [TUPLE [code: INTEGER; x, y, w, h: REAL_64]]
			-- Every click target from the last `lay_out', top to bottom.

	zone (a_code: INTEGER): detachable TUPLE [code: INTEGER; x, y, w, h: REAL_64]
			-- The target for `a_code', if laid out.
		do
			across zones as ic until attached Result loop
				if ic.code = a_code then
					Result := ic
				end
			end
		end

feature -- Element change

	offer (a_devices: PT_DEVICE_LIST; a_camera, a_microphone: READABLE_STRING_32; a_delay_ms: INTEGER)
			-- List `a_devices' with `a_camera' and `a_microphone' chosen and `a_delay_ms' set.
		require
			microphone_present: not a_microphone.is_empty
			delay_in_range: a_delay_ms >= 0 and a_delay_ms <= {PT_CAPTURE_PLAN}.Max_video_delay_ms
		do
			camera := a_camera.to_string_32
			microphone := a_microphone.to_string_32
			video_delay_ms := a_delay_ms
			cameras.wipe_out
			across a_devices.cameras as ic loop
				cameras.extend (ic.twin)
			end
			microphones.wipe_out
			across a_devices.microphones as ic loop
				microphones.extend (ic.twin)
			end
			found_cameras := cameras.count
			found_microphones := microphones.count
			if not a_devices.has_camera (camera) and not camera.is_empty then
				cameras.extend (camera.twin)
			end
			if not a_devices.has_microphone (microphone) then
				microphones.extend (microphone.twin)
			end
			zones.wipe_out
		ensure
			chosen: camera.same_string (a_camera) and microphone.same_string (a_microphone)
			delay_set: video_delay_ms = a_delay_ms
			chosen_listed: across microphones as ic some ic.same_string (a_microphone) end
			camera_listed: not a_camera.is_empty implies across cameras as ic some ic.same_string (a_camera) end
		end

	set_locked (a_locked: BOOLEAN)
		do
			is_locked := a_locked
		ensure
			set: is_locked = a_locked
		end

	choose_camera (a_index: INTEGER)
			-- Choose the `a_index'-th listed camera.
		require
			unlocked: not is_locked
			listed: cameras.valid_index (a_index)
		do
			camera := cameras [a_index].twin
		ensure
			chosen: camera.same_string (cameras [a_index])
		end

	choose_microphone (a_index: INTEGER)
			-- Choose the `a_index'-th listed microphone.
		require
			unlocked: not is_locked
			listed: microphones.valid_index (a_index)
		do
			microphone := microphones [a_index].twin
		ensure
			chosen: microphone.same_string (microphones [a_index])
		end

	step_delay (a_steps: INTEGER)
			-- Change the delay by `a_steps' x `Delay_step_ms', kept within 0 .. the maximum.
		require
			unlocked: not is_locked
		do
			video_delay_ms := (video_delay_ms + a_steps * Delay_step_ms).max (0).min ({PT_CAPTURE_PLAN}.Max_video_delay_ms)
		ensure
			in_range: video_delay_ms >= 0 and video_delay_ms <= {PT_CAPTURE_PLAN}.Max_video_delay_ms
		end

feature -- Layout

	lay_out (a_left, a_top, a_width, a_scale: REAL_64)
			-- Place every target from (`a_left', `a_top'), `a_width' wide, at `a_scale'.
		require
			scale_positive: a_scale > 0
			width_positive: a_width > 0
		local
			l_y: REAL_64
			i: INTEGER
		do
			scale := a_scale
			zones.wipe_out
			l_y := a_top + 24 * a_scale
			title_y := l_y
			l_y := l_y + Design_title * a_scale
			camera_heading_y := l_y
			l_y := l_y + 8 * a_scale
			from i := 1 until i > cameras.count loop
				zones.extend ([Camera_base + i, a_left, l_y, a_width, Design_row * a_scale])
				l_y := l_y + Design_row * a_scale
				i := i + 1
			end
			l_y := l_y + (Design_section_gap + Design_heading - 8) * a_scale
			microphone_heading_y := l_y
			l_y := l_y + 8 * a_scale
			from i := 1 until i > microphones.count loop
				zones.extend ([Microphone_base + i, a_left, l_y, a_width, Design_row * a_scale])
				l_y := l_y + Design_row * a_scale
				i := i + 1
			end
			l_y := l_y + (Design_section_gap + Design_heading - 8) * a_scale
			delay_heading_y := l_y
			l_y := l_y + 8 * a_scale
			zones.extend ([Delay_down_hit, a_left, l_y, Design_step_button * a_scale, Design_row * a_scale])
			zones.extend ([Delay_up_hit, a_left + (Design_step_button + Design_value_width) * a_scale, l_y,
				Design_step_button * a_scale, Design_row * a_scale])
			l_y := l_y + (Design_row + 22) * a_scale
			hint_y := l_y
			l_y := l_y + 34 * a_scale
			zones.extend ([Done_hit, a_left, l_y, Design_done_width * a_scale, Design_done_height * a_scale])
			bottom := l_y + Design_done_height * a_scale
		ensure
			every_row_placed: zones.count = cameras.count + microphones.count + 3
			done_last: zones.last.code = Done_hit
			below_top: bottom > a_top
		end

	hit (a_x, a_y: REAL_64): INTEGER
			-- The target under (`a_x', `a_y'), or `Nothing_hit'.
		do
			across zones as ic until Result /= Nothing_hit loop
				if a_x >= ic.x and a_x <= ic.x + ic.w and a_y >= ic.y and a_y < ic.y + ic.h then
					Result := ic.code
				end
			end
		ensure
			known: Result = Nothing_hit or else attached zone (Result)
		end

	is_camera_row (a_code: INTEGER): BOOLEAN
		do
			Result := a_code > Camera_base and a_code <= Camera_base + cameras.count
		end

	is_microphone_row (a_code: INTEGER): BOOLEAN
		do
			Result := a_code > Microphone_base and a_code <= Microphone_base + microphones.count
		end

feature -- Display

	delay_text: STRING_32
			-- "110 ms".
		do
			Result := video_delay_ms.out.to_string_32 + {STRING_32} " ms"
		end

	device_text (a_name: READABLE_STRING_32; a_found: BOOLEAN): STRING_32
			-- `a_name', marked when Windows does not offer it.
		do
			Result := a_name.to_string_32
			if not a_found then
				Result.append ({STRING_32} "  (not found)")
			end
		end

invariant
	microphone_present: not microphone.is_empty
	found_first: found_cameras <= cameras.count and found_microphones <= microphones.count
	delay_in_range: video_delay_ms >= 0 and video_delay_ms <= {PT_CAPTURE_PLAN}.Max_video_delay_ms

end
