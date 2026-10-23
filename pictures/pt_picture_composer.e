note
	description: "[
		The pictures Publish makes from one frame and the speaker's cutout mask (0.7.0), the
		layout Claude used by hand for Reels 1-4 (youtube_thumb_compose.py, build_reel_kit.py),
		now in Eiffel on simple_image:

		  thumbnail A and B (1280x720): the frame blurred and darkened with a vignette; the icon
		    from the virtual background in a gold frame with a glow, top right; the speaker on the
		    right with a white outline and a soft shadow; Impact lines on the left (A: a struck-out
		    word, then yellow lines; B: white lines, the last yellow).
		  cover (1080x1920): the left of the frame blurred and darkened; the title in big Impact
		    lines and the Bible reference at the top; the speaker large below, head centered.

		The speaker's place and size come from the mask (its bounds, and the head's center from
		the top sixth of it), so the camera's position from session to session does not matter:
		the head's top lands near the top (thumbnail) or under the title (cover), the frame's
		bottom edge on the picture's bottom edge.
		The icon is read from where the virtual background has it (Icon_x, Icon_y).
	]"
	author: "Larry Rix"

class
	PT_PICTURE_COMPOSER

create
	make

feature {NONE} -- Initialization

	make (a_frame: IMG_IMAGE; a_person: IMG_MASK)
			-- Pictures from `a_frame' (any 16:9 size; worked at 1920x1080) and the speaker's mask.
		require
			frame_usable: a_frame.is_usable
			mask_usable: a_person.is_usable
			same_size: a_frame.width = a_person.width and a_frame.height = a_person.height
		local
			l_alpha, l_band: IMG_MASK
			l_band_box: TUPLE [x, y, width, height: INTEGER]
		do
			if a_frame.width = Frame_width and a_frame.height = Frame_height then
				frame := a_frame.twin
				mask := a_person.twin
			else
				frame := a_frame.resized (Frame_width, Frame_height)
				mask := a_person.resized (Frame_width, Frame_height)
			end
			mask.keep_largest_piece (128)
			box := mask.bounds (128)
			if has_person then
				crop_x := (box.x - Pad).max (0)
				crop_y := (box.y - Pad).max (0)
				crop_width := (box.x + box.width + Pad).min (Frame_width) - crop_x
				crop_height := (box.y + box.height + Pad).min (Frame_height) - crop_y
				person := frame.cropped (crop_x, crop_y, crop_width, crop_height)
				l_alpha := mask.cropped (crop_x, crop_y, crop_width, crop_height)
				person.set_alpha (l_alpha)
				l_alpha.destroy
				l_band := mask.cropped (box.x, box.y, box.width, (box.height // 6).max (1))
				l_band_box := l_band.bounds (128)
				l_band.destroy
				head_x := box.x + l_band_box.x + l_band_box.width / 2
			else
				create person.make (1, 1)
				head_x := Frame_width / 2
			end
		end

feature -- Constants

	Frame_width: INTEGER = 1920
	Frame_height: INTEGER = 1080
	Thumb_width: INTEGER = 1280
	Thumb_height: INTEGER = 720
	Cover_width: INTEGER = 1080
	Cover_height: INTEGER = 1920

	Icon_x: INTEGER = 1368
	Icon_y: INTEGER = 112
	Icon_width: INTEGER = 482
	Icon_height: INTEGER = 484
			-- The icon in Larry's virtual background, inside its gold frame.

	Pad: INTEGER = 60
			-- Room around the speaker for the outline and shadow.

	Thumb_head_x: REAL_64 = 950.0
			-- Where the speaker's head is centered on a thumbnail.

	Text_width: REAL_64 = 560.0
			-- The widest a thumbnail line may be.

	Yellow: NATURAL_32 = 0xFFFFD600
	White: NATURAL_32 = 0xFFFFFFFF
	Red: NATURAL_32 = 0xFFE61E28
	Gold: NATURAL_32 = 0xFFD4A850
	Glow: NATURAL_32 = 0xAAFFBE3C
	Shadow: NATURAL_32 = 0xD9000000
	Text_shadow: NATURAL_32 = 0xDC000000

	Impact: STRING = "Impact"
	Arial_black: STRING = "Arial Black"

feature -- Access

	has_person: BOOLEAN
			-- Is there a speaker in the mask big enough to make pictures with?
		do
			Result := box.width >= 100 and box.height >= 100
		end

	face_box: TUPLE [x, y, width, height: INTEGER]
			-- 480x420 around the speaker's head (frame coordinates, inside the frame): the
			-- contact sheet's crop.
		local
			l_x, l_y: INTEGER
		do
			l_x := (head_x.rounded - 240).max (0).min (Frame_width - 480)
			l_y := (box.y - 50).max (0).min (Frame_height - 420)
			Result := [l_x, l_y, 480, 420]
		end

feature -- Pictures

	thumbnail (a_words: PT_PICTURE_WORDS; a_second: BOOLEAN): IMG_IMAGE
			-- Thumbnail A (`a_second' False: struck word, yellow lines) or B (white lines, the last yellow).
		require
			person: has_person
		local
			l_background: IMG_IMAGE
			l_canvas: IMG_CANVAS
			l_scale, l_top, l_size: REAL_64
			l_lines: LIST [STRING_32]
			i: INTEGER
		do
			l_background := frame.resized (Thumb_width, Thumb_height)
			l_background.blur (14)
			l_background.enhance_brightness (0.55)
			l_background.vignette (0.8)
			create l_canvas.make_from (l_background)
			l_background.destroy
			place_icon (l_canvas)
			l_scale := ((Thumb_height - 36) / (Frame_height - box.y)).min (1.25).max (0.5)
			place_person (l_canvas, l_scale, Thumb_head_x - (head_x - crop_x) * l_scale,
				Thumb_height - (Frame_height - crop_y) * l_scale, 8, 4, 22, -14, 6)
			if a_second then
				l_lines := a_words.thumbnail_b_lines
				l_top := 120
			else
				l_lines := a_words.thumbnail_a_lines
				l_top := 150
				if not a_words.struck.is_empty then
					draw_line (l_canvas, a_words.struck, Impact, fitted (a_words.struck, Impact, 100, Text_width, 7), 40, 34, White, 7, True, False)
					strike (l_canvas)
					l_top := last_bottom + 30
				end
			end
			-- One size for every line, the size the widest line fits at (2026-10-11 live run: lines
			-- fitted one by one made "DOES" twice the size of "EVERYTHING THE").
			l_size := line_size (l_lines.count)
			across l_lines as ic loop
				l_size := l_size.min (fitted (ic, Impact, line_size (l_lines.count), Text_width, 12))
			end
			from i := 1 until i > l_lines.count loop
				draw_line (l_canvas, l_lines [i], Impact, l_size,
					34, l_top, line_color (a_second, i, l_lines.count), 12, True, False)
				l_top := last_bottom - 6
				i := i + 1
			end
			Result := l_canvas.to_image
			l_canvas.destroy
		ensure
			sized: Result.width = Thumb_width and Result.height = Thumb_height
			opaque: Result.is_opaque
		end

	cover (a_words: PT_PICTURE_WORDS): IMG_IMAGE
			-- The reel cover: title and reference at the top, the speaker large below.
		require
			person: has_person
		local
			l_background, l_left: IMG_IMAGE
			l_canvas: IMG_CANVAS
			l_top, l_scale: REAL_64
			i: INTEGER
		do
			l_left := frame.cropped (0, 0, 608, Frame_height)
			l_background := l_left.resized (Cover_width, Cover_height)
			l_left.destroy
			l_background.blur (24)
			l_background.enhance_brightness (0.45)
			create l_canvas.make_from (l_background)
			l_background.destroy
			l_top := 120
			from i := 1 until i > a_words.title_lines.count loop
				draw_line (l_canvas, a_words.title_lines [i], Impact, fitted (a_words.title_lines [i], Impact, 250, Cover_width - 80, 12),
					0, l_top, (if i = a_words.title_lines.count then Yellow else White end), 12, False, True)
				l_top := last_bottom + 10
				i := i + 1
			end
			if not a_words.bible_reference.is_empty then
				draw_line (l_canvas, a_words.bible_reference, Arial_black, fitted (a_words.bible_reference, Arial_black, 64, Cover_width - 80, 7),
					0, l_top + 10, White, 7, False, True)
				l_top := last_bottom
			end
			l_scale := ((Cover_height - (l_top + 60)) / (Frame_height - box.y)).min (2.2).max (1.0)
			place_person (l_canvas, l_scale, Cover_width / 2 - (head_x - crop_x) * l_scale,
				Cover_height - (Frame_height - crop_y) * l_scale, 9, 4, 26, -14, 8)
			Result := l_canvas.to_image
			l_canvas.destroy
		ensure
			sized: Result.width = Cover_width and Result.height = Cover_height
			opaque: Result.is_opaque
		end

feature -- Removal

	destroy
			-- Free the copies held.
		do
			frame.destroy
			mask.destroy
			person.destroy
		end

feature {NONE} -- Layers

	place_icon (a_canvas: IMG_CANVAS)
			-- The virtual background's icon, top right, in a gold frame with a soft glow.
		local
			l_crop, l_icon: IMG_IMAGE
			l_glow_canvas: IMG_CANVAS
			l_glow: IMG_MASK
			l_width, l_height, l_x, l_y: INTEGER
		do
			l_height := 380
			l_width := (Icon_width * l_height / Icon_height).rounded
			l_x := Thumb_width - l_width - 26
			l_y := 26
			l_crop := frame.cropped (Icon_x, Icon_y, Icon_width, Icon_height)
			l_icon := l_crop.resized (l_width, l_height)
			l_crop.destroy
			l_icon.enhance_contrast (1.12)
			create l_glow_canvas.make_mask (Thumb_width, Thumb_height)
			l_glow_canvas.context.rectangle (l_x - 18, l_y - 18, l_width + 36, l_height + 36).fill.do_nothing
			l_glow := l_glow_canvas.to_mask
			l_glow_canvas.destroy
			l_glow.blur (28)
			a_canvas.fill_through (l_glow, Glow, 0, 0)
			l_glow.destroy
			set_color (a_canvas.context.save, Gold)
			a_canvas.context.rectangle (l_x - 4, l_y - 4, l_width + 8, l_height + 8).fill.restore.do_nothing
			a_canvas.place (l_icon, l_x, l_y)
			l_icon.destroy
		end

	place_person (a_canvas: IMG_CANVAS; a_scale, a_x, a_y: REAL_64; a_outline, a_shadow_grow, a_shadow_blur: INTEGER; a_shadow_dx, a_shadow_dy: REAL_64)
			-- The speaker scaled by `a_scale' with the crop's top left at (`a_x', `a_y'): a soft shadow
			-- offset by (`a_shadow_dx', `a_shadow_dy'), a white outline `a_outline' pixels wide, then the
			-- speaker a little brighter and crisper.
		require
			scale_positive: a_scale > 0
		local
			l_person: IMG_IMAGE
			l_alpha, l_shadow, l_outline: IMG_MASK
		do
			l_person := person.resized ((crop_width * a_scale).rounded.max (1), (crop_height * a_scale).rounded.max (1))
			l_alpha := l_person.alpha
			l_shadow := l_alpha.twin
			l_shadow.grow (a_shadow_grow)
			l_shadow.blur (a_shadow_blur)
			a_canvas.fill_through (l_shadow, Shadow, a_x + a_shadow_dx, a_y + a_shadow_dy)
			l_outline := l_alpha.twin
			l_outline.grow (a_outline)
			l_outline.blur (1)
			a_canvas.fill_through (l_outline, White, a_x, a_y)
			l_person.enhance_brightness (1.08)
			l_person.enhance_contrast (1.1)
			a_canvas.place (l_person, a_x, a_y)
			l_person.destroy
			l_alpha.destroy
			l_shadow.destroy
			l_outline.destroy
		end

feature {NONE} -- Text

	draw_line (a_canvas: IMG_CANVAS; a_text: READABLE_STRING_32; a_family: STRING; a_size, a_x, a_top: REAL_64;
			a_fill: NATURAL_32; a_stroke: REAL_64; a_shadow, a_centered: BOOLEAN)
			-- Draw `a_text' with its ink's top at `a_top' (left at `a_x', or centered), filled `a_fill' with a
			-- black outline `a_stroke' wide and (`a_shadow') a soft drop shadow; sets `last_left',
			-- `last_right' and `last_bottom' to the ink box with its outline.
		require
			size_positive: a_size > 0
		local
			l_context: CAIRO_CONTEXT
			l_extents: CAIRO_TEXT_EXTENTS
			l_base, l_x: REAL_64
			l_shadow_canvas: IMG_CANVAS
			l_shadow: IMG_MASK
		do
			l_context := a_canvas.context
			l_context.select_font (a_family, l_context.Slant_normal, l_context.Weight_normal).set_font_size (a_size).do_nothing
			l_extents := l_context.text_extents (a_text)
			l_base := a_top + a_stroke - l_extents.y_bearing
			if a_centered then
				l_x := (a_canvas.width - l_extents.width) / 2 - l_extents.x_bearing
			else
				l_x := a_x + a_stroke - l_extents.x_bearing
			end
			if a_shadow then
				create l_shadow_canvas.make_mask (a_canvas.width, a_canvas.height)
				l_shadow_canvas.context.select_font (a_family, l_context.Slant_normal, l_context.Weight_normal).set_font_size (a_size)
					.move_to (l_x + 8, l_base + 10).text_path (a_text).set_line_width (2 * a_stroke)
					.set_line_join (l_context.Join_round).stroke_preserve.fill.do_nothing
				l_shadow := l_shadow_canvas.to_mask
				l_shadow_canvas.destroy
				l_shadow.blur (8)
				a_canvas.fill_through (l_shadow, Text_shadow, 0, 0)
				l_shadow.destroy
			end
			l_context.save.move_to (l_x, l_base).text_path (a_text).set_color_rgb (0, 0, 0).set_line_width (2 * a_stroke)
				.set_line_join (l_context.Join_round).stroke_preserve.do_nothing
			set_color (l_context, a_fill)
			l_context.fill.restore.do_nothing
			last_left := l_x + l_extents.x_bearing - a_stroke
			last_right := l_x + l_extents.x_bearing + l_extents.width + a_stroke
			last_bottom := l_base + l_extents.y_bearing + l_extents.height + a_stroke
		end

	strike (a_canvas: IMG_CANVAS)
			-- A red line with a black edge across the line just drawn, rising left to right.
		local
			l_middle, l_k: REAL_64
			l_context: CAIRO_CONTEXT
		do
			l_k := (last_bottom - 34) / 110
			l_middle := (34 + last_bottom) / 2
			l_context := a_canvas.context
			l_context.save.set_line_cap (l_context.Cap_round).move_to (last_left - 8, l_middle + 12 * l_k)
				.line_to (last_right + 8, l_middle - 12 * l_k).set_color_rgb (0, 0, 0).set_line_width (13 * l_k).stroke_preserve.do_nothing
			set_color (l_context, Red)
			l_context.set_line_width (8 * l_k).stroke.restore.do_nothing
		end

	fitted (a_text: READABLE_STRING_32; a_family: STRING; a_start, a_width, a_stroke: REAL_64): REAL_64
			-- The largest size up to `a_start' at which `a_text' with its outline is at most `a_width' wide.
		local
			l_canvas: IMG_CANVAS
			l_context: CAIRO_CONTEXT
		do
			create l_canvas.make_mask (4, 4)
			l_context := l_canvas.context
			from
				Result := a_start
			until
				Result <= 40 or else l_context.select_font (a_family, l_context.Slant_normal, l_context.Weight_normal)
					.set_font_size (Result).text_extents (a_text).width + 2 * a_stroke <= a_width
			loop
				Result := Result - 4
			end
			l_canvas.destroy
		ensure
			not_bigger: Result <= a_start
		end

	line_size (a_count: INTEGER): REAL_64
			-- The starting size for a thumbnail with `a_count' lines.
		do
			inspect a_count
			when 1 then Result := 150
			when 2 then Result := 128
			else Result := 108
			end
		end

	line_color (a_second: BOOLEAN; a_index, a_count: INTEGER): NATURAL_32
			-- Thumbnail A: all yellow; B: white, the last yellow.
		do
			if a_second and a_index < a_count then
				Result := White
			else
				Result := Yellow
			end
		end

	set_color (a_context: CAIRO_CONTEXT; a_color: NATURAL_32)
			-- Make `a_color' (0xAARRGGBB) the context's source.
		do
			a_context.set_color_rgba (((a_color |>> 16) & 0xFF).to_real_64 / 255, ((a_color |>> 8) & 0xFF).to_real_64 / 255,
				(a_color & 0xFF).to_real_64 / 255, ((a_color |>> 24) & 0xFF).to_real_64 / 255).do_nothing
		end

feature {NONE} -- Implementation

	frame: IMG_IMAGE
			-- The frame at 1920x1080.

	mask: IMG_MASK
			-- The speaker's mask at 1920x1080, largest piece only.

	box: TUPLE [x, y, width, height: INTEGER]
			-- Where the speaker is in the frame.

	person: IMG_IMAGE
			-- The speaker cut out of the frame (the padded crop), alpha from the mask.

	crop_x, crop_y, crop_width, crop_height: INTEGER
			-- The padded crop `person' was cut from.

	head_x: REAL_64
			-- The head's center across the frame.

	last_left, last_right, last_bottom: REAL_64
			-- The ink box of the last `draw_line'.

end
