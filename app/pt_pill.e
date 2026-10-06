note
	description: "[
		The pill: a capture-excluded SHELL_PANEL just below the webcam, painted
		by PT_PILL_RENDERER. It sits at the top centre of the primary monitor
		until the reader Shift+drags it; where it was dropped is remembered in
		the settings. Hide and click-through are toggles the hotkeys reach.
	]"
	author: "Larry Rix"

class
	PT_PILL

create
	make

feature {NONE} -- Initialization

	make (a_settings: PT_SETTINGS; a_theme: SW_THEME; a_measure: PT_CAIRO_MEASURE)
		do
			settings := a_settings
			scale := a_theme.text_scale
			measure := a_measure
			create panel.make
			create renderer.make (a_theme, a_measure.font_size)
		ensure
			settings_set: settings = a_settings
			closed: not panel.is_open
		end

feature -- Constants

	Design_padding: REAL_64 = 12.0
			-- Inset of the text from the pill's edges, in design pixels.

	Top_gap: INTEGER = 6
			-- Pixels between the monitor's top edge (where the webcam sits) and the pill.

feature -- Access

	settings: PT_SETTINGS
	measure: PT_CAIRO_MEASURE

	scale: REAL_64
			-- Physical pixels per design pixel (the display's DPI scale).

	padding: REAL_64
			-- Inset of the text, in physical pixels.
		do
			Result := Design_padding * scale
		end

	column_width: REAL_64
			-- Text column, in physical pixels.
		do
			Result := settings.column_width * scale
		end
	panel: SHELL_PANEL
	renderer: PT_PILL_RENDERER

	width: INTEGER
			-- Column plus padding.
		do
			Result := (column_width + 2 * padding).ceiling
		end

	height: INTEGER
			-- Visible lines plus padding.
		do
			Result := (settings.lines_visible * measure.line_height + 2 * padding).ceiling
		end

	reading_line: REAL_64
			-- The reading line sits one line down when three or more lines show, so the
			-- reader keeps the line just read in view.
		do
			if settings.lines_visible >= 3 then
				Result := measure.line_height
			end
		end

feature -- Status

	is_shown: BOOLEAN
		do
			Result := panel.is_open and then panel.is_visible
		end

	is_click_through: BOOLEAN
		do
			Result := panel.is_open and then panel.is_click_through
		end

	capture_note: STRING_32
			-- How the pill fares in screen captures, in words.
		do
			if not panel.is_open then
				Result := {STRING_32} "not open"
			elseif panel.capture_affinity = panel.Affinity_excluded_from_captures then
				Result := {STRING_32} "hidden from screen capture"
			elseif panel.capture_affinity = panel.Affinity_black_in_captures then
				Result := {STRING_32} "blacked out in screen capture (older Windows)"
			else
				Result := {STRING_32} "VISIBLE in screen capture"
			end
		end

	is_capturable: BOOLEAN
			-- Let screen captures see the pill (screenshots, demos)?

feature -- Lifecycle

	make_capturable
			-- Do not hide the pill from screen captures (`--capturable').
		require
			not_open: not panel.is_open
		do
			is_capturable := True
		ensure
			set: is_capturable
		end


	open
			-- Create and show the pill under the webcam (or where it was left).
		local
			l_monitors: SHELL_MONITORS
			l_x, l_y, l_primary: INTEGER
		do
			if settings.has_pill_position then
				l_x := settings.pill_x
				l_y := settings.pill_y
			else
				create l_monitors.make
				l_primary := l_monitors.primary_index
				if l_primary > 0 then
					l_x := (l_monitors.left (l_primary) + l_monitors.right (l_primary)) // 2 - width // 2
					l_y := l_monitors.top (l_primary) + Top_gap
				end
			end
			panel.open (l_x, l_y, width, height)
			if panel.is_open then
				if not is_capturable then
					panel.request_capture_exclusion
				end
				panel.set_opacity (settings.opacity.max (40))
				panel.set_draggable (True)
				panel.show (l_x, l_y, width, height)
			end
		end

	close
		do
			if panel.is_open then
				panel.close
			end
		end

feature -- Commands

	toggle_shown
			-- Hide the pill, or bring it back.
		do
			if panel.is_open then
				if panel.is_visible then
					panel.hide
				else
					panel.show (panel.x, panel.y, panel.width, panel.height)
				end
			end
		end

	toggle_click_through
			-- Let clicks reach the desktop under the pill, or the pill again.
		do
			if panel.is_open then
				panel.set_click_through (not panel.is_click_through)
			end
		end

	remember_position (a_x, a_y: INTEGER)
			-- The reader dropped the pill at (`a_x', `a_y').
		do
			if panel.is_open then
				panel.place (a_x, a_y, panel.width, panel.height)
			end
			settings.set_pill_position (a_x, a_y)
		end

	paint (a_prompter: SIMPLE_PROMPTER; a_geometry: PT_PILL_GEOMETRY; a_caret: INTEGER; a_badge: READABLE_STRING_32)
			-- Repaint the pill now.
		require
			loaded: a_prompter.has_script
		local
			l_dc: POINTER
		do
			if is_shown then
				l_dc := panel.dc
				if l_dc /= default_pointer then
					renderer.render (l_dc, panel.width, panel.height, a_prompter, a_geometry, a_caret, a_badge)
					panel.release_dc (l_dc)
				end
			end
		end

end
