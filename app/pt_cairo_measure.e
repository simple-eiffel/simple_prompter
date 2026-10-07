note
	description: "[
		Text measurement with the pill's real font: cairo text extents through
		SW_PAINTER on a private 8x8 surface, so layout wraps exactly where the
		renderer will draw. Widths are cached per text: a cairo measurement costs
		milliseconds, and laying out an 8,740-word sermon measured every word, which
		held the app's start (and the microphone) for about 30 s (2026-10-07).
	]"
	author: "Larry Rix"

class
	PT_CAIRO_MEASURE

inherit
	PT_TEXT_MEASURE

create
	make

feature {NONE} -- Initialization

	make (a_theme: SW_THEME; a_font_size: REAL_64)
			-- Measure in the theme's mono family at `a_font_size' design pixels
			-- (times the theme's `text_scale' on screen).
		require
			size_positive: a_font_size > 0
		do
			font_size := a_font_size
			create widths.make (4096)
			create surface.make (8, 8)
			create context.make (surface)
			create painter.make (context, a_theme)
			painter.font (painter.Role_mono, a_font_size, False)
			space_advance := painter.advance (" ").max (1.0)
				-- SW_PAINTER.font scales the size by `text_scale'; the line pitch must too.
			line_height := (a_font_size * a_theme.text_scale * Line_spacing).max (1.0)
		ensure
			size_set: font_size = a_font_size
		end

feature -- Constants

	Line_spacing: REAL_64 = 1.35
			-- Line pitch as a multiple of the font size.

feature -- Access

	font_size: REAL_64

feature -- Measurement

	advance (a_text: READABLE_STRING_32): REAL_64
			-- Advance of `a_text' in the pill font.
		do
			if not a_text.is_empty then
				widths.search (a_text.to_string_32)
				if widths.found then
					Result := widths.found_item
				else
					Result := painter.advance (a_text).max (0.0)
					widths.force (Result, a_text.to_string_32.twin)
				end
			end
		end

	space_advance: REAL_64
			-- Advance of one space.

	line_height: REAL_64
			-- Distance between baselines.

feature {NONE} -- Implementation

	widths: HASH_TABLE [REAL_64, STRING_32]
			-- Measured advances by text (memo: the font never changes after `make').

	surface: CAIRO_SURFACE
	context: CAIRO_CONTEXT
	painter: SW_PAINTER

invariant
	space_positive: space_advance > 0
	line_positive: line_height > 0

end
