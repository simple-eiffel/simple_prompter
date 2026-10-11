note
	description: "[
		The vertical Facebook Reel (0.5.9): Publish's finished final.mp4 (1920x1080) made into
		reel.mp4 (1080x1920). A blurred, darkened copy of the picture fills the frame; the
		picture, cropped to the speaker and the icon, sits in the middle; the title fills
		the top band; the captions are burned in, large, in the bottom band (Reels autoplay
		muted, and an uploaded captions file shows only when a viewer turns captions on).
		When out\ has cover.jpg (a 1080x1920 cover, made outside the program like the
		thumbnails), the reel opens on it, dissolving into the picture while the voice
		starts at once.
		The title and the captions are an ASS subtitle file (`ass_text') that ffmpeg's ass
		filter draws; the filter graph goes in a script file (`filter_script'), with the
		file paths escaped for ffmpeg (`filter_path').
	]"
	author: "Larry Rix"

class
	PT_REEL_PLAN

create
	make

feature {NONE} -- Initialization

	make (a_title: READABLE_STRING_32; a_length: REAL_64)
			-- A reel titled `a_title' (the script's # line) for a finished video `a_length' seconds long.
		require
			length_positive: a_length > 0
		do
			title := a_title.to_string_32.twin
			title.left_adjust
			title.right_adjust
			length := a_length
		ensure
			length_set: length = a_length
		end

feature -- Constants

	Width: INTEGER = 1080
	Height: INTEGER = 1920
			-- The reel's frame.

	Crop_x: INTEGER = 450
	Crop_width: INTEGER = 1450
			-- The part of the 1920x1080 picture kept: the speaker and the icon on his right, clear
			-- of the Greek and Hebrew names on the left (their last letter ends near x 435; a crop
			-- from 400 left a stray final sigma at the edge, Reel 4 as posted 2026-10-11).

	Picture_y: INTEGER = 560
			-- Top of the picture in the reel.

	Cover_hold_s: REAL_64 = 0.25
	Cover_fade_s: REAL_64 = 0.8
			-- The cover shows alone, then dissolves into the picture.

	Title_size: INTEGER = 150
	Caption_size: INTEGER = 64
			-- Font sizes on the 1080x1920 frame.

	Fonts_dir: STRING_32 = "C:\Windows\Fonts"
			-- Where Impact (title) and Arial Black (captions) are.

feature -- Access

	title: STRING_32
	length: REAL_64

	picture_height: INTEGER
			-- Height of the picture in the reel (the crop scaled to the frame's width, even).
		do
			Result := ((Width * 1080 / Crop_width / 2).rounded * 2)
		ensure
			fits: Result > 0 and Picture_y + Result < Height
		end

	title_lines: ARRAYED_LIST [STRING_32]
			-- The title in capitals, on two lines (split at the space nearest its middle) when it
			-- has two or more words, else one.
		local
			l_upper: STRING_32
			l_best, l_i, l_mid: INTEGER
		do
			create Result.make (2)
			l_upper := title.as_upper
			l_mid := l_upper.count // 2
			from l_i := 1 until l_i > l_upper.count loop
				if l_upper [l_i] = ' ' and then (l_best = 0 or else (l_i - l_mid).abs < (l_best - l_mid).abs) then
					l_best := l_i
				end
				l_i := l_i + 1
			end
			if l_best > 1 and l_best < l_upper.count then
				Result.extend (l_upper.substring (1, l_best - 1))
				Result.extend (l_upper.substring (l_best + 1, l_upper.count))
			elseif not l_upper.is_empty then
				Result.extend (l_upper)
			end
		ensure
			at_most_two: Result.count <= 2
		end

feature -- The subtitle file

	ass_text (a_cues: LIST [PT_CAPTION_CUE]): STRING_32
			-- The ASS file: the title in the top band for the whole reel, each caption in the bottom band.
		local
			l_caption_margin, l_line: INTEGER
			l_lines: ARRAYED_LIST [STRING_32]
		do
			l_lines := title_lines
			l_caption_margin := Picture_y + picture_height + 70
			create Result.make (4096)
			Result.append ({STRING_32} "[Script Info]%NScriptType: v4.00+%NPlayResX: 1080%NPlayResY: 1920%NWrapStyle: 0%NScaledBorderAndShadow: yes%N%N")
			Result.append ({STRING_32} "[V4+ Styles]%NFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding%N")
				-- ASS colours are &HAABBGGRR: yellow is FFD200.
			Result.append ({STRING_32} "Style: Title,Impact," + Title_size.out + {STRING_32} ",&H0000D2FF,&H0000D2FF,&H00000000,&H64000000,0,0,0,0,100,100,2,0,1,9,4,8,40,40,150,1%N")
			Result.append ({STRING_32} "Style: Cap,Arial Black," + Caption_size.out + {STRING_32} ",&H00FFFFFF,&H00FFFFFF,&H00000000,&H96000000,0,0,0,0,100,100,0,0,1,7,3,8,70,70," + l_caption_margin.out + {STRING_32} ",1%N%N")
			Result.append ({STRING_32} "[Events]%NFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text%N")
			if not l_lines.is_empty then
				Result.append ({STRING_32} "Dialogue: 0," + ass_time (0) + {STRING_32} "," + ass_time (length) + {STRING_32} ",Title,,0,0,0,,")
				from l_line := 1 until l_line > l_lines.count loop
					if l_line > 1 then
						Result.append ({STRING_32} "\N")
					end
					Result.append (ass_safe (l_lines [l_line]))
					l_line := l_line + 1
				end
				Result.append_character ('%N')
			end
			across a_cues as ic loop
				Result.append ({STRING_32} "Dialogue: 1," + ass_time (ic.t0) + {STRING_32} "," + ass_time (ic.t1) + {STRING_32} ",Cap,,0,0,0,,"
					+ ass_safe (on_screen (ic.text)) + {STRING_32} "%N")
			end
		ensure
			sized_for_the_reel: Result.has_substring ({STRING_32} "PlayResX: 1080") and Result.has_substring ({STRING_32} "PlayResY: 1920")
		end

	on_screen (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' as drawn: the word "quote," Larry says before a quotation becomes an opening
			-- quotation mark (the captions file keeps what was said).
		local
			l_lower: STRING_32
			i: INTEGER
		do
			create Result.make (a_text.count)
			l_lower := a_text.as_lower
			from i := 1 until i > a_text.count loop
				if (i = 1 or else a_text [i - 1] = ' ' or else a_text [i - 1] = '%N') and then i + 5 <= a_text.count
					and then l_lower.substring (i, i + 5).same_string ({STRING_32} "quote,") then
					Result.append_character ('%/8220/')
					i := i + 6
					from until i > a_text.count or else a_text [i] /= ' ' loop
						i := i + 1
					end
					if i <= a_text.count then
							-- The quotation begins here: its first letter in capitals.
						Result.append_character (a_text [i].as_upper)
						i := i + 1
					end
				else
					Result.append_character (a_text [i])
					i := i + 1
				end
			end
		ensure
			no_spoken_quote_word: not Result.as_lower.has_substring ({STRING_32} " quote,")
		end

	ass_time (a_seconds: REAL_64): STRING_32
			-- h:mm:ss.cc
		local
			l_cs, l_s: INTEGER
		do
			l_cs := (a_seconds.max (0) * 100).rounded
			l_s := l_cs // 100
			Result := (l_s // 3600).out.to_string_32 + {STRING_32} ":" + two (l_s // 60 \\ 60) + {STRING_32} ":"
				+ two (l_s \\ 60) + {STRING_32} "." + two (l_cs \\ 100)
		ensure
			shaped: Result.occurrences (':') = 2 and Result.occurrences ('.') = 1
		end

feature -- ffmpeg

	filter_script (a_ass_path: READABLE_STRING_32; a_has_cover: BOOLEAN): STRING_32
			-- The filter graph: backdrop, picture, title and captions, and the cover dissolving away.
		do
			create Result.make (600)
			Result.append ({STRING_32} "[0:v]split[a][b];")
			Result.append ({STRING_32} "[a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=40:2,eq=brightness=-0.32[bg];")
			Result.append ({STRING_32} "[b]crop=" + Crop_width.out + {STRING_32} ":1080:" + Crop_x.out + {STRING_32} ":0,scale=1080:" + picture_height.out + {STRING_32} "[fg];")
			Result.append ({STRING_32} "[bg][fg]overlay=0:" + Picture_y.out + {STRING_32} ",ass=filename=" + filter_path (a_ass_path)
				+ {STRING_32} ":fontsdir=" + filter_path (Fonts_dir))
			if a_has_cover then
				Result.append ({STRING_32} "[base];[1:v]scale=1080:1920,format=rgba,fade=t=out:st=" + seconds (Cover_hold_s)
					+ {STRING_32} ":d=" + seconds (Cover_fade_s) + {STRING_32} ":alpha=1[cover];[base][cover]overlay=0:0:eof_action=pass,format=yuv420p[v]")
			else
				Result.append ({STRING_32} ",format=yuv420p[v]")
			end
		ensure
			labelled: Result.ends_with ({STRING_32} "[v]")
			cover_only_when_given: a_has_cover = Result.has_substring ({STRING_32} "[1:v]")
		end

	arguments (a_source: READABLE_STRING_32; a_cover: detachable READABLE_STRING_32; a_script_path, a_output: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- ffmpeg's arguments: `a_source' (and the cover image, held a little longer than its
			-- dissolve) through the graph in `a_script_path' to `a_output'.
		do
			create Result.make (40)
			add (Result, <<"-hide_banner", "-v", "error", "-y", "-i">>)
			Result.extend (a_source.to_string_32)
			if attached a_cover as al_cover then
				add (Result, <<"-loop", "1", "-framerate", "30", "-t", seconds (Cover_hold_s + Cover_fade_s + 0.2), "-i">>)
				Result.extend (al_cover.to_string_32)
			end
			add (Result, <<"-filter_complex_script">>)
			Result.extend (a_script_path.to_string_32)
			add (Result, <<"-map", "[v]", "-map", "0:a", "-r", "30", "-c:v", "h264_nvenc", "-preset", "p5", "-cq", "21",
				"-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", "-stats">>)
			Result.extend (a_output.to_string_32)
		ensure
			output_last: Result.last.same_string_general (a_output)
			cover_input_when_given: (a_cover /= Void) = across Result as ic some ic.same_string ({STRING_32} "-loop") end
		end

	filter_path (a_path: READABLE_STRING_32): STRING_32
			-- `a_path' as an ffmpeg filter option value, which ffmpeg reads twice (filter graph, then
			-- option): forward slashes, the drive colon escaped for the option level, all in single
			-- quotes for the graph level; an apostrophe (a folder named "Devil's Half Right") is
			-- escaped for the option level and stepped out of the quotes for the graph level.
			-- Checked with a real ffmpeg run, 2026-10-11 (the one-level escape lost the apostrophe).
		local
			i: INTEGER
		do
			create Result.make (a_path.count + 8)
			Result.append_character ('%'')
			from i := 1 until i > a_path.count loop
				inspect a_path [i]
				when '\' then
					Result.append_character ('/')
				when ':' then
					Result.append ({STRING_32} "\:")
				when '%'' then
						-- Two readings: the graph level gets "...\" then an escaped ' then "...",
						-- so the option level reads \' as a plain apostrophe.
					Result.append ({STRING_32} "\'\''")
				else
					Result.append_character (a_path [i])
				end
				i := i + 1
			end
			Result.append_character ('%'')
		ensure
			quoted: Result.starts_with ({STRING_32} "'") and Result.ends_with ({STRING_32} "'")
			no_backslash_separators: not a_path.has ('%'') implies Result.occurrences ('\') = a_path.occurrences (':')
		end

feature {NONE} -- Implementation

	ass_safe (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' with ASS override braces and backslashes neutralized, line breaks as \N.
		local
			i: INTEGER
		do
			create Result.make (a_text.count + 4)
			from i := 1 until i > a_text.count loop
				inspect a_text [i]
				when '{' then
					Result.append_character ('(')
				when '}' then
					Result.append_character (')')
				when '\' then
					Result.append_character ('/')
				when '%N' then
					Result.append ({STRING_32} "\N")
				when '%R' then
				else
					Result.append_character (a_text [i])
				end
				i := i + 1
			end
		end

	two (a_n: INTEGER): STRING_32
		do
			Result := a_n.out.to_string_32
			if Result.count < 2 then
				Result.prepend_character ('0')
			end
		end

	seconds (a_value: REAL_64): STRING_32
			-- Three decimals.
		do
			Result := (create {PT_RENDER_PLAN}.make ({STRING_32} "ffmpeg", 0, False)).seconds (a_value.max (0)).to_string_32
		end

	add (a_list: ARRAYED_LIST [STRING_32]; a_items: ARRAY [STRING_32])
		do
			across a_items as ic loop
				a_list.extend (ic.twin)
			end
		end

invariant
	length_positive: length > 0

end
