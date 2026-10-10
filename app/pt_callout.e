note
	description: "[
		A callout beside the pill (0.4.0, pill-only UI): its own SHELL_PANEL - left of
		the pill, right of it, or below it - hidden from screen captures like the pill,
		painted with the same SW_PAINTER by a content procedure. The content draws
		from the callout's top left, registers each clickable thing with a tooltip
		(`add_zone'), and says how tall it came out (`set_content_height'); the
		callout then sizes itself to fit. Every callout has a close button, and shows
		the tooltip of the zone the pointer rests on (PT_HOVER, unless tooltips are off).
	]"
	author: "Larry Rix"

class
	PT_CALLOUT

create
	make

feature {NONE} -- Initialization

	make (a_side: INTEGER; a_design_width: REAL_64; a_theme: SW_THEME)
		require
			side_known: a_side >= Side_left and a_side <= Side_below
			wide: a_design_width >= 120
		do
			side := a_side
			design_width := a_design_width
			theme := a_theme
			scale := a_theme.text_scale
			create panel.make
			create hover.make
			create zones.make (24)
			create surface.make (1, 1)
		ensure
			closed: not is_shown
		end

feature -- Constants

	Side_left: INTEGER = 1
	Side_right: INTEGER = 2
	Side_below: INTEGER = 3

	Close_zone: INTEGER = 9999
			-- The close button every callout has.

	Design_padding: REAL_64 = 16.0
	Design_gap: REAL_64 = 12.0
			-- Between the pill and the callout.
	Max_design_height: REAL_64 = 1000.0

	Slab: NATURAL_32 = 0x14171C
	Edge: NATURAL_32 = 0x343944
	Ink: NATURAL_32 = 0xE6E8EC
	Muted: NATURAL_32 = 0xA9AFBA
	Accent: NATURAL_32 = 0x3B82F6
	Tooltip_slab: NATURAL_32 = 0x262A33

feature -- Access

	side: INTEGER
	design_width: REAL_64
	theme: SW_THEME
	scale: REAL_64
	panel: SHELL_PANEL
	hover: PT_HOVER

	width: INTEGER
		do
			Result := (design_width * scale).ceiling
		end

	padding: REAL_64
		do
			Result := Design_padding * scale
		end

	content_height: REAL_64
			-- How tall the content came out at the last `render' (physical pixels).

	zones: ARRAYED_LIST [TUPLE [code: INTEGER; x, y, w, h: REAL_64; tip: STRING_32]]
			-- What the content made clickable at the last `render'.

	zone_at (a_x, a_y: REAL_64): INTEGER
			-- The zone at (`a_x', `a_y'), or 0.
		do
			across zones as ic until Result /= 0 loop
				if a_x >= ic.x and a_x <= ic.x + ic.w and a_y >= ic.y and a_y <= ic.y + ic.h then
					Result := ic.code
				end
			end
		end

	is_shown: BOOLEAN
		do
			Result := panel.is_open and then panel.is_visible
		end

	slot: INTEGER
			-- The panel's slot while open (events carry it), else -1.
		do
			Result := panel.slot
		end

feature -- Content building (called by the content procedure while rendering)

	add_zone (a_code: INTEGER; a_x, a_y, a_w, a_h: REAL_64; a_tip: READABLE_STRING_32)
			-- Make (`a_x', `a_y', `a_w', `a_h') clickable as `a_code', with tooltip `a_tip'.
		require
			code_positive: a_code > 0
		do
			zones.extend ([a_code, a_x, a_y, a_w, a_h, a_tip.to_string_32])
		end

	set_content_height (a_height: REAL_64)
		do
			content_height := a_height
		end

feature -- Showing

	show_beside (a_pill_x, a_pill_y, a_pill_w, a_pill_h: INTEGER; a_capturable: BOOLEAN)
			-- Open (once) and show the callout beside a pill at (`a_pill_x', `a_pill_y') sized
			-- `a_pill_w' x `a_pill_h'.
		local
			l_x, l_y, l_h, l_gap: INTEGER
		do
			l_gap := (Design_gap * scale).rounded
			l_h := (content_height.max (60 * scale)).ceiling
			inspect side
			when Side_left then
				l_x := a_pill_x - l_gap - width
				l_y := a_pill_y
			when Side_right then
				l_x := a_pill_x + a_pill_w + l_gap
				l_y := a_pill_y
			else
				l_x := a_pill_x + a_pill_w - width
				l_y := a_pill_y + a_pill_h + l_gap
			end
			if not panel.is_open then
				panel.open (l_x, l_y, width, l_h)
				if panel.is_open and not a_capturable then
					panel.request_capture_exclusion
				end
			end
			if panel.is_open then
				panel.show (l_x, l_y, width, l_h)
			end
		end

	follow (a_pill_x, a_pill_y, a_pill_w, a_pill_h: INTEGER)
			-- Move along with a pill that is moving (no repaint: the picture moves with the window).
		do
			if is_shown then
				show_beside (a_pill_x, a_pill_y, a_pill_w, a_pill_h, True)
			end
		end

	hide
		do
			if panel.is_open and then panel.is_visible then
				panel.hide
			end
			hover.set_pointer_in (False)
		ensure
			hidden: not is_shown
		end

	close
		do
			if panel.is_open then
				panel.close
			end
		end

feature -- Painting

	render (a_content: PROCEDURE [SW_PAINTER, PT_CALLOUT])
			-- Paint the callout with `a_content'; grow or shrink the panel to the content.
		local
			l_context: CAIRO_CONTEXT
			l_painter: SW_PAINTER
			l_h, k: REAL_64
			l_dc: POINTER
		do
			if is_shown then
				k := scale
				if surface.width /= width or surface.height /= (Max_design_height * k).ceiling then
					surface.destroy
					create surface.make (width, (Max_design_height * k).ceiling)
				end
				create l_context.make (surface)
				create l_painter.make (l_context, theme)
				zones.wipe_out
				l_painter.set_color (Slab)
				l_painter.fill_rect (0, 0, width, Max_design_height * k)
				content_height := 0
				a_content.call ([l_painter, Current])
				l_h := (content_height + padding).ceiling.max ((60 * k).ceiling).min ((Max_design_height * k).ceiling)
					-- The frame and the close button.
				l_painter.set_color (Edge)
				l_painter.set_line_width (1 * k)
				l_painter.rrect_stroke (0.5, 0.5, width - 1, l_h - 1, 10 * k)
				close_button (l_painter, k)
				if hover.is_tooltip_shown then
					tooltip (l_painter, l_h, k)
				end
				l_context.destroy
				if (l_h - panel.height).abs > 1 then
					panel.place (panel.x, panel.y, width, l_h.ceiling)
				end
				l_dc := panel.dc
				if l_dc /= default_pointer then
					blit (l_dc)
					panel.release_dc (l_dc)
				end
			end
		end

	track (a_x, a_y, a_now_ms: REAL_64)
			-- The pointer moved to (`a_x', `a_y') on the callout.
		local
			l_code: INTEGER
		do
			hover.set_pointer_in (True)
			l_code := zone_at (a_x, a_y)
			hover.set_hovered (l_code, (if l_code = 0 then {STRING_32} "" else tip_of (l_code) end), a_now_ms)
		end

	refresh_hover (a_now_ms: REAL_64)
			-- Forget the hover once the pointer leaves (no event says so); show a rested-on tooltip.
		do
			if hover.is_pointer_in and then not (is_shown and then panel.is_cursor_over) then
				hover.set_pointer_in (False)
			end
			hover.update (a_now_ms)
		end

	tip_of (a_code: INTEGER): STRING_32
		do
			create Result.make_empty
			across zones as ic until not Result.is_empty loop
				if ic.code = a_code then
					Result := ic.tip
				end
			end
		end

feature {NONE} -- Implementation

	surface: CAIRO_SURFACE

	close_button (p: SW_PAINTER; k: REAL_64)
			-- The x at the top right.
		local
			x, y, s: REAL_64
		do
			s := 24 * k
			x := width - s - 10 * k
			y := 10 * k
			if hover.hovered = Close_zone then
				p.set_color_alpha (Accent, 0.3)
				p.rrect_fill (x, y, s, s, 6 * k)
			end
			p.set_color (Muted)
			p.line (x + 7 * k, y + 7 * k, x + s - 7 * k, y + s - 7 * k, 1.8 * k)
			p.line (x + s - 7 * k, y + 7 * k, x + 7 * k, y + s - 7 * k, 1.8 * k)
			add_zone (Close_zone, x, y, s, s, {STRING_32} "Close")
		end

	tooltip (p: SW_PAINTER; a_height, k: REAL_64)
			-- The rested-on zone's tooltip, under it (above it near the bottom), inside the callout.
		local
			l_w, l_h, l_x, l_y, l_pad: REAL_64
		do
			across zones as ic loop
				if ic.code = hover.hovered then
					p.font (p.Role_ui, 12, False)
					l_pad := 7 * k
					l_w := (p.advance (hover.tooltip) + 2 * l_pad).min (width - 8 * k)
					l_h := p.font_ascent + p.font_descent + 2 * l_pad * 0.75
					l_x := (ic.x).max (4 * k).min (width - l_w - 4 * k)
					l_y := ic.y + ic.h + 4 * k
					if l_y + l_h > a_height - 4 * k then
						l_y := (ic.y - l_h - 4 * k).max (4 * k)
					end
					p.set_color (Tooltip_slab)
					p.rrect_fill (l_x, l_y, l_w, l_h, 6 * k)
					p.set_color_alpha (Accent, 0.6)
					p.set_line_width (1 * k)
					p.rrect_stroke (l_x, l_y, l_w, l_h, 6 * k)
					p.set_color (Ink)
					p.text (l_x + l_pad, l_y + l_pad * 0.75 + p.font_ascent, hover.tooltip)
				end
			end
		end

	blit (a_dc: POINTER)
			-- Copy the offscreen picture to `a_dc' (the panel clips it to its size).
		local
			l_target: CAIRO_SURFACE
			l_copy: CAIRO_CONTEXT
		do
			create l_target.make_for_dc (a_dc)
			if l_target.is_valid then
				create l_copy.make (l_target)
				l_copy.set_source_surface (surface, 0.0, 0.0).paint.do_nothing
				l_copy.destroy
			end
			l_target.destroy
		end

invariant
	side_known: side >= Side_left and side <= Side_below

end
