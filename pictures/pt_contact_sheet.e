note
	description: "[
		A contact sheet of the speaker's face in each candidate frame (0.7.0): 6 by 4 tiles of
		240x210, each numbered in yellow from 1, for the local AI to pick the best thumbnail
		frame from (PT_OLLAMA_WRITER.pick_frame). The face's box comes from one frame's cutout
		(PT_PICTURE_COMPOSER.face_box); the speaker moves little within a take.
	]"
	author: "Larry Rix"

class
	PT_CONTACT_SHEET

create
	make

feature {NONE} -- Initialization

	make (a_frames: LIST [IMG_IMAGE]; a_face: TUPLE [x, y, width, height: INTEGER])
			-- The sheet of `a_frames' (1920x1080) cropped to `a_face'.
		require
			has_frames: not a_frames.is_empty
			fits: a_frames.count <= Columns * Rows
			face_sized: a_face.width > 0 and a_face.height > 0
		local
			l_canvas: IMG_CANVAS
			l_crop, l_tile: IMG_IMAGE
			l_context: CAIRO_CONTEXT
			l_x, l_y: REAL_64
			i: INTEGER
		do
			create l_canvas.make (Columns * Tile_width, Rows * Tile_height)
			l_canvas.fill (0xFF000000)
			l_context := l_canvas.context
			from i := 1 until i > a_frames.count loop
				l_x := ((i - 1) \\ Columns) * Tile_width
				l_y := ((i - 1) // Columns) * Tile_height
				if a_frames [i].is_usable and then a_frames [i].is_inside (a_face.x, a_face.y, a_face.width, a_face.height) then
					l_crop := a_frames [i].cropped (a_face.x, a_face.y, a_face.width, a_face.height)
					l_tile := l_crop.resized (Tile_width, Tile_height)
					l_canvas.place (l_tile, l_x, l_y)
					l_crop.destroy
					l_tile.destroy
				end
				l_context.select_font ("Arial Black", l_context.Slant_normal, l_context.Weight_normal).set_font_size (30)
					.move_to (l_x + 8, l_y + 36).text_path (i.out).set_color_rgb (0, 0, 0).set_line_width (5)
					.stroke_preserve.set_color_rgb (1, 0.84, 0).fill.do_nothing
				i := i + 1
			end
			image := l_canvas.to_image
			l_canvas.destroy
			count := a_frames.count
		ensure
			sized: image.width = Columns * Tile_width and image.height = Rows * Tile_height
			counted: count = a_frames.count
		end

feature -- Constants

	Columns: INTEGER = 6
	Rows: INTEGER = 4
	Tile_width: INTEGER = 240
	Tile_height: INTEGER = 210

feature -- Access

	image: IMG_IMAGE
			-- The sheet.

	count: INTEGER
			-- Tiles on it.

end
