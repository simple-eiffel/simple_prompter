note
	description: "[
		Paints the pill: a dark slab, the script lines around the reading
		line (lines above dimmed, words already read dimmed, the reading line
		bright), a reading marker, the caret word while held, and a small badge
		(HELD, the count-in digits, CLICK-THROUGH). Draws offscreen, then copies
		to the panel's device context in one step.
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

feature -- Access

	theme: SW_THEME
	font_size: REAL_64

feature -- Rendering

	render (a_dc: POINTER; a_width, a_height: INTEGER; a_prompter: SIMPLE_PROMPTER; a_geometry: PT_PILL_GEOMETRY;
			a_caret: INTEGER; a_badge: READABLE_STRING_32)
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
			paint (l_painter, a_width, a_height, a_prompter, a_geometry, a_caret, a_badge)
			l_context.destroy
			blit (a_dc)
		end

feature {NONE} -- Painting

	paint (p: SW_PAINTER; a_width, a_height: INTEGER; a_prompter: SIMPLE_PROMPTER; a_geometry: PT_PILL_GEOMETRY;
			a_caret: INTEGER; a_badge: READABLE_STRING_32)
		local
			l_offset, l_top, l_baseline, l_position, l_reading_top, k: REAL_64
			l_line, l_first, l_last, i, l_read: INTEGER
			l_revision: PT_SCRIPT_REVISION
			l_layout: PT_LAYOUT
		do
			l_revision := a_prompter.history.current_revision
			l_layout := a_geometry.layout
			l_position := a_prompter.scroll.position
			l_offset := a_prompter.scroll.y_offset
			l_read := l_position.floor
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
				a_height - 2 * a_geometry.padding).clip.do_nothing
			p.font (p.Role_mono, font_size, False)
			l_first := a_geometry.first_visible_line (l_offset)
			l_last := a_geometry.last_visible_line (l_offset, a_height)
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
			fade (p, a_height - a_geometry.padding - l_layout.line_height * 0.35, a_height, False, a_width)
				-- The badge.
			if not a_badge.is_empty then
				p.font (p.Role_ui, (font_size * 0.45).max (11.0), True)
				p.set_color (Badge_ink)
				p.text (a_width - p.advance (a_badge) - 14 * k, 18 * k, a_badge)
			end
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
