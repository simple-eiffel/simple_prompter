note
	description: "[
		The slide handle (0.4.0): a small tab under the pill, its own panel, that slides
		the pill left and right. A plain press drags it, kept to the horizontal
		(simple_shell 1.14.0: SHELL_PANEL.set_drags_on_press, set_drag_axis); the app
		moves the pill and its callouts along as it reports itself moving (event 49).
		Hidden from screen captures like the pill. Its tooltip is drawn on the pill,
		just above it - the tab is too small to hold one.
	]"
	author: "Larry Rix"

class
	PT_SLIDE_HANDLE

create
	make

feature {NONE} -- Initialization

	make (a_theme: SW_THEME)
		do
			theme := a_theme
			scale := a_theme.text_scale
			create panel.make
			create hover.make
			create surface.make (1, 1)
		ensure
			closed: not is_shown
		end

feature -- Constants

	Design_width: REAL_64 = 110.0
	Design_height: REAL_64 = 18.0

	Tip: STRING_32 = "Drag to slide the pill left or right"

	Slab: NATURAL_32 = 0x1A1D23
	Edge: NATURAL_32 = 0x2A2E37
	Mark: NATURAL_32 = 0x7C8392

feature -- Access

	theme: SW_THEME
	scale: REAL_64
	panel: SHELL_PANEL
	hover: PT_HOVER

	width: INTEGER
		do
			Result := (Design_width * scale).ceiling
		end

	height: INTEGER
		do
			Result := (Design_height * scale).ceiling
		end

	is_shown: BOOLEAN
		do
			Result := panel.is_open and then panel.is_visible
		end

	slot: INTEGER
		do
			Result := panel.slot
		end

	pill_left_for (a_left, a_pill_width: INTEGER): INTEGER
			-- Where the pill goes when the handle is at `a_left' (the handle stays centred under it).
		do
			Result := a_left + width // 2 - a_pill_width // 2
		end

feature -- Showing

	show_under (a_pill_x, a_pill_y, a_pill_w, a_pill_h: INTEGER; a_capturable: BOOLEAN)
			-- Open (once) and show the handle centred under the pill.
		local
			l_x, l_y: INTEGER
		do
			l_x := a_pill_x + a_pill_w // 2 - width // 2
			l_y := a_pill_y + a_pill_h
			if not panel.is_open then
				panel.open (l_x, l_y, width, height)
				if panel.is_open then
					if not a_capturable then
						panel.request_capture_exclusion
					end
					panel.set_drags_on_press (True)
					panel.set_drag_axis (panel.Axis_horizontal)
				end
			end
			if panel.is_open then
				panel.show (l_x, l_y, width, height)
				render
			end
		end

	hide
		do
			if is_shown then
				panel.hide
			end
			hover.set_pointer_in (False)
		end

	close
		do
			if panel.is_open then
				panel.close
			end
		end

	track (a_now_ms: REAL_64)
			-- The pointer moved on the handle.
		do
			hover.set_pointer_in (True)
			hover.set_hovered (1, Tip, a_now_ms)
		end

	refresh_hover (a_now_ms: REAL_64)
		do
			if hover.is_pointer_in and then not (is_shown and then panel.is_cursor_over) then
				hover.set_pointer_in (False)
			end
			hover.update (a_now_ms)
		end

	render
			-- A tab with rounded lower corners, grip dots and an arrow each way.
		local
			l_context: CAIRO_CONTEXT
			p: SW_PAINTER
			k, cx, cy, w, h: REAL_64
			l_dc: POINTER
			l_target: CAIRO_SURFACE
			l_copy: CAIRO_CONTEXT
		do
			if is_shown then
				k := scale
				w := width
				h := height
				if surface.width /= width or surface.height /= height then
					surface.destroy
					create surface.make (width, height)
				end
				create l_context.make (surface)
				create p.make (l_context, theme)
				p.set_color (Slab)
				p.fill_rect (0, 0, w, h)
				p.set_color (Slab)
				p.rrect_fill (0, -10 * k, w, h + 10 * k, 9 * k)
				p.set_color (Edge)
				p.set_line_width (1 * k)
				p.rrect_stroke (0.5, -10 * k, w - 1, h + 10 * k - 0.5, 9 * k)
				cx := w / 2
				cy := h / 2
				p.set_color (Mark)
				p.circle_fill (cx - 6 * k, cy, 1.6 * k)
				p.circle_fill (cx, cy, 1.6 * k)
				p.circle_fill (cx + 6 * k, cy, 1.6 * k)
				p.triangle_fill (cx - 22 * k, cy, cx - 16 * k, cy - 4 * k, cx - 16 * k, cy + 4 * k)
				p.triangle_fill (cx + 22 * k, cy, cx + 16 * k, cy - 4 * k, cx + 16 * k, cy + 4 * k)
				l_context.destroy
				l_dc := panel.dc
				if l_dc /= default_pointer then
					create l_target.make_for_dc (l_dc)
					if l_target.is_valid then
						create l_copy.make (l_target)
						l_copy.set_source_surface (surface, 0.0, 0.0).paint.do_nothing
						l_copy.destroy
					end
					l_target.destroy
					panel.release_dc (l_dc)
				end
			end
		end

feature {NONE} -- Implementation

	surface: CAIRO_SURFACE

end
