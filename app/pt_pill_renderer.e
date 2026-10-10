note
	description: "[
		Paints the pill: a dark slab, the script lines around the reading
		line (lines above dimmed, words already read dimmed, the reading line
		bright), a reading marker, the caret word while held, and a small badge
		(HELD, the count-in digits, CLICK-THROUGH). Under the text, the transport
		bar: the progress line and the video-player buttons (icons drawn, not font
		glyphs), and a tooltip over the button the pointer rests on. Draws offscreen,
		then copies to the panel's device context in one step.
	]"
	author: "Larry Rix"

class
	PT_PILL_RENDERER

create
	make

feature {NONE} -- Initialization

	make (a_theme: SW_THEME; a_font_size: REAL_64)
		require
			size_positive: a_font_size > 0
		do
			theme := a_theme
			font_size := a_font_size
			create surface.make (1, 1)
		ensure
			theme_set: theme = a_theme
		end

feature -- Colours

	Slab: NATURAL_32 = 0x0F1115
	Read_ink: NATURAL_32 = 0x5B6170
	Reading_ink: NATURAL_32 = 0xF5F6F8
	Upcoming_ink: NATURAL_32 = 0xC9CDD4
	Accent: NATURAL_32 = 0x3B82F6
	Badge_ink: NATURAL_32 = 0xFBBF24
	Record_red: NATURAL_32 = 0xEF4444
	Reject_ink: NATURAL_32 = 0xF87171
	Tooltip_slab: NATURAL_32 = 0x262A33

feature -- Access

	theme: SW_THEME
	font_size: REAL_64

	shows_grips: BOOLEAN
			-- Draw the resize grips (while Shift is held)?

feature -- Settings

	set_shows_grips (a_on: BOOLEAN)
		do
			shows_grips := a_on
		ensure
			set: shows_grips = a_on
		end

feature -- Rendering

	render (a_dc: POINTER; a_width, a_height: INTEGER; a_prompter: SIMPLE_PROMPTER; a_geometry: PT_PILL_GEOMETRY;
			a_caret: INTEGER; a_badge: READABLE_STRING_32; a_bar: PT_TRANSPORT_BAR)
			-- Draw the pill for `a_prompter' into device context `a_dc'.
		require
			dc_present: a_dc /= default_pointer
			sane_size: a_width > 0 and a_height > 0
			loaded: a_prompter.has_script
		local
			l_context: CAIRO_CONTEXT
			l_painter: SW_PAINTER
		do
			if surface.width /= a_width or surface.height /= a_height then
				surface.destroy
				create surface.make (a_width, a_height)
			end
			create l_context.make (surface)
			create l_painter.make (l_context, theme)
			paint (l_painter, a_width, a_height, a_prompter, a_geometry, a_caret, a_badge, a_bar)
			l_context.destroy
			blit (a_dc)
		end

feature {NONE} -- Painting

	paint (p: SW_PAINTER; a_width, a_height: INTEGER; a_prompter: SIMPLE_PROMPTER; a_geometry: PT_PILL_GEOMETRY;
			a_caret: INTEGER; a_badge: READABLE_STRING_32; a_bar: PT_TRANSPORT_BAR)
		local
			l_offset, l_top, l_baseline, l_position, l_reading_top, k, l_text_bottom: REAL_64
			l_line, l_first, l_last, i, l_read: INTEGER
			l_revision: PT_SCRIPT_REVISION
			l_layout: PT_LAYOUT
		do
			l_revision := a_prompter.history.current_revision
			l_layout := a_geometry.layout
			l_position := a_prompter.scroll.position
			l_offset := a_prompter.scroll.y_offset
			l_read := l_position.floor
				-- The script text ends where the transport bar begins.
			l_text_bottom := (a_height - a_bar.height).max (2 * a_geometry.padding + 1)
				-- The slab.
			p.set_color (Slab)
			p.fill_rect (0, 0, a_width, a_height)
				-- The reading marker.
			k := theme.text_scale
			l_reading_top := a_geometry.padding + a_geometry.reading_line
			p.set_color (Accent)
			p.fill_rect (4 * k, l_reading_top + 4 * k, 3 * k, l_layout.line_height - 8 * k)
				-- The lines that show, clipped to the text area so a line beyond the
				-- visible rows never peeks into the padding.
			p.context.save.do_nothing
			p.context.rectangle (a_geometry.padding, a_geometry.padding, a_width - 2 * a_geometry.padding,
				l_text_bottom - 2 * a_geometry.padding).clip.do_nothing
			p.font (p.Role_mono, font_size, False)
			l_first := a_geometry.first_visible_line (l_offset)
			l_last := a_geometry.last_visible_line (l_offset, l_text_bottom)
			if l_first > 0 and l_last >= l_first then
				from l_line := l_first until l_line > l_last loop
					l_top := a_geometry.line_top (l_line, l_offset)
					l_baseline := l_top + (l_layout.line_height + p.font_ascent - p.font_descent) / 2
					from i := l_layout.line (l_line).first_word until i > l_layout.line (l_line).last_word loop
						if i = a_caret then
							p.set_color (Accent)
							p.rrect_fill (a_geometry.word_x (i) - 4 * k, l_top + 3 * k, a_geometry.word_width (i) + 8 * k,
								l_layout.line_height - 6 * k, 6 * k)
							p.set_color (Reading_ink)
						elseif l_revision.word (i).is_cue then
								-- Cues are shown dimmed and never spoken.
							p.set_color (Read_ink)
						elseif i <= l_read then
							p.set_color (Read_ink)
						elseif l_top < l_reading_top - l_layout.line_height / 2 then
							p.set_color (Read_ink)
						elseif (l_top - l_reading_top).abs < l_layout.line_height / 2 then
							p.set_color (Reading_ink)
						else
							p.set_color (Upcoming_ink)
						end
						p.text (a_geometry.word_x (i), l_baseline, l_revision.word (i).text)
						i := i + 1
					end
					l_line := l_line + 1
				end
			end
			p.context.restore.do_nothing
				-- Soft edges: a line scrolling past never shows as cut-off glyph fragments.
			fade (p, 0, a_geometry.padding + l_layout.line_height * 0.35, True, a_width)
			fade (p, l_text_bottom - a_geometry.padding - l_layout.line_height * 0.35, l_text_bottom, False, a_width)
			transport (p, a_bar, k)
				-- The badge.
			if not a_badge.is_empty then
				p.font (p.Role_ui, (font_size * 0.45).max (11.0), True)
				p.set_color (Badge_ink)
				p.text (a_width - p.advance (a_badge) - 14 * k, 18 * k, a_badge)
			end
			if shows_grips then
				grips (p, a_width, a_height, k)
			end
			if a_bar.is_tooltip_shown and a_bar.is_laid_out then
				transport_tooltip (p, a_bar, a_width, k)
			end
		end

	transport (p: SW_PAINTER; b: PT_TRANSPORT_BAR; k: REAL_64)
			-- The progress line and the buttons.
		local
			l_thick, l_x: REAL_64
			i: INTEGER
		do
			if b.is_laid_out then
				if b.hovered = b.Progress_hit then
					l_thick := 6 * k
				else
					l_thick := 4 * k
				end
				p.set_color_alpha (Upcoming_ink, 0.18)
				p.rrect_fill (b.progress_left, b.progress_y - l_thick / 2, b.progress_right - b.progress_left, l_thick, l_thick / 2)
				l_x := b.progress_left + (b.progress_right - b.progress_left) * b.progress
				p.set_color (Accent)
				if l_x - b.progress_left > l_thick then
					p.rrect_fill (b.progress_left, b.progress_y - l_thick / 2, l_x - b.progress_left, l_thick, l_thick / 2)
				end
				p.circle_fill (l_x, b.progress_y, l_thick * 1.3)
				from i := 1 until i > b.Button_count loop
					transport_button (p, b, i, k)
					i := i + 1
				end
			end
		end

	transport_tooltip (p: SW_PAINTER; b: PT_TRANSPORT_BAR; a_width: INTEGER; k: REAL_64)
			-- The hovered target's tooltip, just above the bar, kept inside the pill.
		require
			showing: b.is_tooltip_shown
			laid_out: b.is_laid_out
		local
			l_text: STRING_32
			l_w, l_h, l_x, l_y, l_pad, l_centre: REAL_64
		do
			l_text := b.tooltip
			p.font (p.Role_ui, (font_size * 0.4).max (12.0), False)
			l_pad := 8 * k
			l_w := p.advance (l_text) + 2 * l_pad
			l_h := p.font_ascent + p.font_descent + 2 * l_pad * 0.75
			if b.valid_button (b.hovered) then
				l_centre := b.button_centre_x (b.hovered)
			else
				l_centre := a_width / 2
			end
			l_x := (l_centre - l_w / 2).max (4 * k).min (a_width - l_w - 4 * k)
			l_y := b.top - l_h - 2 * k
			p.set_color (Tooltip_slab)
			p.rrect_fill (l_x, l_y, l_w, l_h, 6 * k)
			p.set_color_alpha (Accent, 0.6)
			p.set_line_width (1 * k)
			p.rrect_stroke (l_x, l_y, l_w, l_h, 6 * k)
			p.set_color (Reading_ink)
			p.text (l_x + l_pad, l_y + l_pad * 0.75 + p.font_ascent, l_text)
		end

	transport_button (p: SW_PAINTER; b: PT_TRANSPORT_BAR; a_button: INTEGER; k: REAL_64)
			-- One button: a highlight under the pointer, then its icon (dimmed when it would do nothing now).
		require
			valid: b.valid_button (a_button)
			laid_out: b.is_laid_out
		local
			x, y, s, cx, cy, h, lw, a: REAL_64
			l_on: BOOLEAN
		do
			x := b.button_left (a_button)
			y := b.button_top
			s := b.button_size
			cx := x + s / 2
			cy := y + s / 2
			h := s * 0.3
			lw := (2 * k).max (1.0)
			l_on := b.is_enabled (a_button)
			if l_on and b.hovered = a_button then
				p.set_color_alpha (Accent, 0.35)
				p.rrect_fill (x, y, s, s, 6 * k)
			end
			ink (p, l_on, Upcoming_ink)
			inspect a_button
			when {PT_TRANSPORT_BAR}.Back_button then
				p.fill_rect (cx - h, cy - h, lw, 2 * h)
				p.triangle_fill (cx + h, cy - h, cx + h, cy + h, cx - h + lw, cy)
			when {PT_TRANSPORT_BAR}.Forward_button then
				p.triangle_fill (cx - h, cy - h, cx - h, cy + h, cx + h - lw, cy)
				p.fill_rect (cx + h - lw, cy - h, lw, 2 * h)
			when {PT_TRANSPORT_BAR}.Again_button then
					-- A circle arrow, clockwise from the upper right, the head at the upper left.
				p.set_line_width (lw)
				p.arc_stroke (cx, cy, h, -0.25 * Pi, 1.25 * Pi)
				a := h * 0.75
				p.triangle_fill (cx - Root_half * h + Root_half * a, cy - Root_half * h - Root_half * a,
					cx - Root_half * h - Root_half * a * 0.7, cy - Root_half * h - Root_half * a * 0.7,
					cx - Root_half * h + Root_half * a * 0.7, cy - Root_half * h + Root_half * a * 0.7)
			when {PT_TRANSPORT_BAR}.Play_button then
				if b.is_playing then
					p.fill_rect (cx - h * 0.8, cy - h, h * 0.55, 2 * h)
					p.fill_rect (cx + h * 0.25, cy - h, h * 0.55, 2 * h)
				else
					p.triangle_fill (cx - h * 0.7, cy - h, cx - h * 0.7, cy + h, cx + h, cy)
				end
			when {PT_TRANSPORT_BAR}.Record_button then
				if b.is_rolling then
					if b.is_recording then
						ink (p, l_on, Record_red)
					end
					p.fill_rect (cx - h * 0.8, cy - h * 0.8, h * 1.6, h * 1.6)
				else
					ink (p, l_on, Record_red)
					p.circle_fill (cx, cy, h * 0.9)
				end
			when {PT_TRANSPORT_BAR}.Star_button then
				ink (p, l_on, Badge_ink)
				p.star_fill (cx, cy, h * 1.15)
			when {PT_TRANSPORT_BAR}.Reject_button then
				ink (p, l_on, Reject_ink)
				p.line (cx - h * 0.8, cy - h * 0.8, cx + h * 0.8, cy + h * 0.8, lw * 1.2)
				p.line (cx - h * 0.8, cy + h * 0.8, cx + h * 0.8, cy - h * 0.8, lw * 1.2)
			when {PT_TRANSPORT_BAR}.Slower_button then
				p.line (cx - h, cy, cx + h, cy, lw * 1.2)
			when {PT_TRANSPORT_BAR}.Faster_button then
				p.line (cx - h, cy, cx + h, cy, lw * 1.2)
				p.line (cx, cy - h, cx, cy + h, lw * 1.2)
			end
		end

	ink (p: SW_PAINTER; a_on: BOOLEAN; a_colour: NATURAL_32)
			-- `a_colour' when the button would act, a faint grey when it would not.
		do
			if a_on then
				p.set_color (a_colour)
			else
				p.set_color_alpha (Read_ink, 0.55)
			end
		end

	Pi: REAL_64 = 3.1415926535897932
	Root_half: REAL_64 = 0.70710678118654752
			-- cos 45 degrees.

	grips (p: SW_PAINTER; a_width, a_height: INTEGER; k: REAL_64)
			-- A frame and short bars at the edge midpoints and corners: drag them (with Shift)
			-- to size the pill, drag anywhere else to move it.
		local
			w, h, l_bar, l_t: REAL_64
		do
			w := a_width
			h := a_height
			l_bar := 18 * k
			l_t := 3 * k
			p.set_color_alpha (Accent, 0.55)
			p.set_line_width (1.5 * k)
			p.rrect_stroke (1 * k, 1 * k, w - 2 * k, h - 2 * k, 10 * k)
			p.set_color (Accent)
			p.line (w / 2 - l_bar, l_t, w / 2 + l_bar, l_t, l_t)
			p.line (w / 2 - l_bar, h - l_t, w / 2 + l_bar, h - l_t, l_t)
			p.line (l_t, h / 2 - l_bar, l_t, h / 2 + l_bar, l_t)
			p.line (w - l_t, h / 2 - l_bar, w - l_t, h / 2 + l_bar, l_t)
			p.line (l_t, l_t, l_t + l_bar, l_t, l_t)
			p.line (l_t, l_t, l_t, l_t + l_bar, l_t)
			p.line (w - l_t, l_t, w - l_t - l_bar, l_t, l_t)
			p.line (w - l_t, l_t, w - l_t, l_t + l_bar, l_t)
			p.line (l_t, h - l_t, l_t + l_bar, h - l_t, l_t)
			p.line (l_t, h - l_t, l_t, h - l_t - l_bar, l_t)
			p.line (w - l_t, h - l_t, w - l_t - l_bar, h - l_t, l_t)
			p.line (w - l_t, h - l_t, w - l_t, h - l_t - l_bar, l_t)
		end

	fade (p: SW_PAINTER; a_top, a_bottom: REAL_64; a_opaque_at_top: BOOLEAN; a_width: INTEGER)
			-- Bands of slab colour from `a_top' to `a_bottom', opaque at the outer edge.
		local
			i: INTEGER
			l_band, l_alpha: REAL_64
		do
			if a_bottom > a_top then
				l_band := (a_bottom - a_top) / Fade_bands
				from i := 0 until i >= Fade_bands loop
					if a_opaque_at_top then
						l_alpha := 1.0 - i / Fade_bands
					else
						l_alpha := (i + 1) / Fade_bands
					end
					p.set_color_alpha (Slab, l_alpha)
					p.fill_rect (0, a_top + i * l_band, a_width, l_band + 0.5)
					i := i + 1
				end
			end
		end

	Fade_bands: INTEGER = 12

	blit (a_dc: POINTER)
			-- Copy the offscreen picture to `a_dc'.
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

feature {NONE} -- Implementation

	surface: CAIRO_SURFACE
			-- Offscreen picture, resized with the pill.

end
