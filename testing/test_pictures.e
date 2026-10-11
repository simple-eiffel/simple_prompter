note
	description: "[
		0.7.0 Publish pictures, the parts that need no model: the words (from the AI or the title),
		the frame plan, the contact sheet, and the composer on a drawn frame whose "speaker" is a
		head and shoulders with a known mask. Writes testing/out/pictures_*.png to look at.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_PICTURES

inherit
	PT_TEST_SET

feature -- Words

	test_words_from_the_title
			-- With no AI, every picture uses the title, in balanced upper-case lines.
		local
			w: PT_PICTURE_WORDS
		do
			create w.make ({STRING_32} "Jesus Was Helpless?", create {PT_PUBLISH_SUGGESTIONS}.make_empty)
			assert_integers_equal ("two title lines", 2, w.title_lines.count)
			assert_true ("first line", w.title_lines [1].same_string ({STRING_32} "JESUS WAS"))
			assert_true ("second line", w.title_lines [2].same_string ({STRING_32} "HELPLESS?"))
			assert_integers_equal ("A falls back to the title", 2, w.thumbnail_a_lines.count)
			assert_true ("nothing struck", w.struck.is_empty)
			assert_false ("not from the AI", w.from_ai)
		end

	test_words_from_the_ai
			-- The AI's struck word, thumbnail lines and reference are used, upper case.
		local
			w: PT_PICTURE_WORDS
		do
			create w.make ({STRING_32} "Jesus Was Helpless?", create {PT_PUBLISH_SUGGESTIONS}.make_from_json (
				{STRING_32} "{%"title%": %"t%", %"thumbnail_struck%": %"Helpless%", %"thumbnail_a%": %"Read the next line%", %
				%%"thumbnail_b%": %"Nothing... or everything?%", %"reference%": %"John 5:19%"}"))
			assert_true ("struck", w.struck.same_string ({STRING_32} "HELPLESS"))
			assert_integers_equal ("A in two lines", 2, w.thumbnail_a_lines.count)
			assert_true ("A first line", w.thumbnail_a_lines [1].same_string ({STRING_32} "READ THE"))
			assert_true ("A second line", w.thumbnail_a_lines [2].same_string ({STRING_32} "NEXT LINE"))
			assert_true ("B ends on the question", w.thumbnail_b_lines.last.ends_with ({STRING_32} "EVERYTHING?"))
			assert_true ("bible_reference", w.bible_reference.same_string ({STRING_32} "JOHN 5:19"))
			assert_true ("from the AI", w.from_ai)
		end

	test_balanced_lines
			-- Short text stays on one line; long text never exceeds the line limit.
		local
			w: PT_PICTURE_WORDS
		do
			create w.make ({STRING_32} "Dumb Jesus?", create {PT_PUBLISH_SUGGESTIONS}.make_empty)
			assert_integers_equal ("one line", 1, w.title_lines.count)
			assert_integers_equal ("three at most",  3, w.balanced ({STRING_32} "THE SON CAN DO NOTHING THAT STARTS IN HIMSELF", 3).count)
			-- 2026-10-11 live run: "FROM / HIMSELF, NOT BY" was badly balanced.
			assert_true ("best split, first line", w.balanced ({STRING_32} "FROM HIMSELF, NOT BY", 3).first.same_string ({STRING_32} "FROM HIMSELF,"))
			assert_true ("best split, second line", w.balanced ({STRING_32} "FROM HIMSELF, NOT BY", 3).last.same_string ({STRING_32} "NOT BY"))
		end

feature -- Frames

	test_frame_plan
			-- 24 candidates inside the speech, the fallback near 9 seconds in, and a one-frame ffmpeg call.
		local
			p: PT_FRAME_PLAN
			l_args: LIST [STRING_32]
		do
			create p.make (2.0, 160.0)
			assert_integers_equal ("24 candidates", 24, p.times.count)
			assert_true ("first 3 seconds in", (p.times.first - 5.0).abs < 0.001)
			assert_true ("last 3 seconds before the end", (p.times.last - 157.0).abs < 0.001)
			assert_true ("fallback near 11 s: " + p.times [p.fallback_index].out, (p.times [p.fallback_index] - 11.0).abs < 4.0)
			l_args := p.frame_arguments ({STRING_32} "src.mp4", 12.3456, {STRING_32} "f.png")
			l_args.compare_objects
			assert_true ("seeks before the input", l_args.index_of ({STRING_32} "-ss", 1) < l_args.index_of ({STRING_32} "-i", 1))
			assert_true ("one frame", l_args.has ({STRING_32} "-frames:v"))
			assert_true ("millisecond time", l_args.has ({STRING_32} "12.346"))
		end

	test_contact_sheet
			-- 24 frames make a 6 by 4 sheet of 240x210 tiles.
		local
			l_frames: ARRAYED_LIST [IMG_IMAGE]
			s: PT_CONTACT_SHEET
			i: INTEGER
		do
			create l_frames.make (24)
			from i := 1 until i > 24 loop
				l_frames.extend (create {IMG_IMAGE}.make_filled (1920, 1080, {NATURAL_32} 0xFF000000 + (i * 10).to_natural_32))
				i := i + 1
			end
			create s.make (l_frames, [700, 300, 480, 420])
			assert_integers_equal ("width", 1440, s.image.width)
			assert_integers_equal ("height", 840, s.image.height)
			assert_integers_equal ("count", 24, s.count)
			assert_true ("a tile's color", s.image.pixel (120, 150) = 0xFF00000A)
			assert_true ("written", s.image.save_png (out_path ("pictures_contact_sheet.png")))
		end

feature -- Composer

	test_composer_thumbnails_and_cover
			-- From a drawn frame: thumbnails of 1280x720 and a cover of 1080x1920, opaque, with the
			-- speaker where the layout puts them and the yellow words drawn.
		local
			c: PT_PICTURE_COMPOSER
			w: PT_PICTURE_WORDS
			l_a, l_b, l_cover: IMG_IMAGE
		do
			c := drawn_composer
			assert_true ("found the speaker", c.has_person)
			create w.make ({STRING_32} "Jesus Was Helpless?", create {PT_PUBLISH_SUGGESTIONS}.make_from_json (
				{STRING_32} "{%"thumbnail_struck%": %"Helpless%", %"thumbnail_a%": %"Read the next line%", %"thumbnail_b%": %"Nothing... or everything?%", %"reference%": %"John 5:19%"}"))
			l_a := c.thumbnail (w, False)
			l_b := c.thumbnail (w, True)
			l_cover := c.cover (w)
			assert_true ("A written", l_a.save_png (out_path ("pictures_thumbnail_A.png")))
			assert_true ("B written", l_b.save_png (out_path ("pictures_thumbnail_B.png")))
			assert_true ("cover written", l_cover.save_png (out_path ("pictures_cover.png")))
			assert_true ("the head is where thumbnails put it (skin): " + l_a.pixel (950, 200).to_hex_string, near (l_a.pixel (950, 200), Skin, 40))
			assert_true ("A has yellow words: " + count_near (l_a, 0, 0, 640, 720, 0xFFFFD600, 8).out, count_near (l_a, 0, 0, 640, 720, 0xFFFFD600, 8) > 3000)
			assert_true ("B has white words", count_near (l_b, 0, 0, 640, 360, 0xFFFFFFFF, 8) > 3000)
			assert_true ("cover's title is at the top", count_near (l_cover, 0, 0, 1080, 800, 0xFFFFD600, 8) > 5000)
			assert_true ("cover's head is centered: " + l_cover.pixel (540, 1100).to_hex_string, near (l_cover.pixel (540, 1100), Skin, 40))
			c.destroy
		end

feature {NONE} -- Fixtures

	Skin: NATURAL_32 = 0xFFE0A890
	Shirt: NATURAL_32 = 0xFF6A4C9C

	drawn_composer: PT_PICTURE_COMPOSER
			-- A frame with a "speaker" (a round head on a shirt, left of center as Larry sits) on a
			-- dark backdrop, and the mask of exactly that speaker.
		local
			l_frame_canvas, l_mask_canvas: IMG_CANVAS
			l_frame: IMG_IMAGE
			l_mask: IMG_MASK
		do
			create l_frame_canvas.make (1920, 1080)
			l_frame_canvas.fill (0xFF20242C)
			draw_speaker (l_frame_canvas.context, True)
			l_frame := l_frame_canvas.to_image
			l_frame_canvas.destroy
			create l_mask_canvas.make_mask (1920, 1080)
			draw_speaker (l_mask_canvas.context, False)
			l_mask := l_mask_canvas.to_mask
			l_mask_canvas.destroy
			create Result.make (l_frame, l_mask)
		end

	draw_speaker (a_context: CAIRO_CONTEXT; a_colored: BOOLEAN)
			-- Shoulders from (500, 700) to the bottom, joined to a head of radius 150 at (850, 600).
		do
			if a_colored then
				a_context.set_color_rgb (0x6A / 255, 0x4C / 255, 0x9C / 255).do_nothing
			end
			a_context.rectangle (500, 700, 700, 380).fill.do_nothing
			if a_colored then
				a_context.set_color_rgb (0xE0 / 255, 0xA8 / 255, 0x90 / 255).do_nothing
			end
			a_context.arc (850, 600, 150, 0, 6.2832).fill.do_nothing
		end

	near (a_color, a_expected: NATURAL_32; a_tolerance: INTEGER): BOOLEAN
			-- Is each of R, G, B within `a_tolerance' of `a_expected''s?
		local
			s: INTEGER
		do
			Result := True
			from s := 0 until s > 16 loop
				Result := Result and (((a_color |>> s) & 0xFF).to_integer_32 - ((a_expected |>> s) & 0xFF).to_integer_32).abs <= a_tolerance
				s := s + 8
			end
		end

	count_near (a_image: IMG_IMAGE; a_x, a_y, a_width, a_height: INTEGER; a_color: NATURAL_32; a_tolerance: INTEGER): INTEGER
			-- Pixels in the rectangle near `a_color'.
		local
			x, y: INTEGER
		do
			from y := a_y until y >= a_y + a_height loop
				from x := a_x until x >= a_x + a_width loop
					if near (a_image.pixel (x, y), a_color, a_tolerance) then
						Result := Result + 1
					end
					x := x + 2
				end
				y := y + 2
			end
			Result := Result * 4
		end

	out_path (a_name: STRING): STRING
			-- testing/out/`a_name' (run from the project folder).
		do
			Result := "testing/out/" + a_name
		end

end
