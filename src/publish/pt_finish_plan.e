note
	description: "[
		The ffmpeg run that finishes a rendered take for posting (0.5.0, the Publish step), in
		one pass from the render (final.mp4, kept as "final (before cleanup).mp4"):
		- the silence before the first word cut to `Lead_s' (the caller's `start');
		- when there is a thumbnail, the video opens on it and dissolves into the picture over
		  `Dissolve_s' while the voice starts at once;
		- the last frame held `Hold_s' and faded to black, the sound faded with it, starting
		  `Fade_after_s' after the last word;
		- the sound brought to YouTube's loudness (-14 LUFS, true peak -1.5 dB);
		- H.264 (crf 17) and AAC at 60 frames a second, ready to stream (+faststart).
		Also the audio extract the transcription reads (16 kHz mono float).
	]"
	author: "Larry Rix"

class
	PT_FINISH_PLAN

create
	make

feature {NONE} -- Initialization

	make (a_start, a_speech_end, a_source_end: REAL_64)
			-- A finish from `a_start' to `a_source_end' of the render, the last word ending at `a_speech_end'.
		require
			start_non_negative: a_start >= 0
			speech_after_start: a_speech_end > a_start
			speech_within: a_speech_end <= a_source_end
		do
			start := a_start
			speech_end := a_speech_end
			source_end := a_source_end
		ensure
			set: start = a_start and speech_end = a_speech_end and source_end = a_source_end
		end

feature -- Constants

	Lead_s: REAL_64 = 0.25
			-- Silence kept before the first word.
	Hold_s: REAL_64 = 0.8
			-- The last frame held this long, so the fade does not start on the last word.
	Fade_after_s: REAL_64 = 0.15
	Min_fade_s: REAL_64 = 0.6
	Dissolve_s: REAL_64 = 0.8
	Thumbnail_s: REAL_64 = 0.15
			-- The thumbnail alone, before it starts to dissolve.
	Loudness: STRING_32 = "loudnorm=I=-14:TP=-1.5:LRA=11"

feature -- Access

	start, speech_end, source_end: REAL_64

	length: REAL_64
			-- The finished video's length.
		do
			Result := source_end - start + Hold_s
		ensure
			held: Result >= Hold_s
		end

	fade_start: REAL_64
			-- When the fade to black begins (output time).
		do
			Result := (speech_end - start + Fade_after_s).min (length - Min_fade_s).max (0)
		ensure
			after_last_word_or_room: Result >= 0 and Result <= length - Min_fade_s
		end

	filter (a_with_thumbnail: BOOLEAN): STRING_32
			-- The filter graph; input 0 the render, input 1 the thumbnail when `a_with_thumbnail'.
		local
			l_fade, l_cut: STRING_32
		do
			l_cut := seconds (start) + {STRING_32} ":" + seconds (source_end)
			l_fade := {STRING_32} "st=" + seconds (fade_start) + {STRING_32} ":d=" + seconds (length - fade_start)
			Result := {STRING_32} "[0:v]trim=" + l_cut + {STRING_32} ",setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration="
				+ seconds (Hold_s) + {STRING_32} ",fade=t=out:" + l_fade
			if a_with_thumbnail then
				Result.append ({STRING_32} "[vp];[1:v]scale=1920:1080,format=rgba,fade=t=out:st=" + seconds (Thumbnail_s)
					+ {STRING_32} ":d=" + seconds (Dissolve_s) + {STRING_32} ":alpha=1[th];[vp][th]overlay=0:0:eof_action=pass:format=auto[vo];")
			else
				Result.append ({STRING_32} "[vo];")
			end
			Result.append ({STRING_32} "[0:a]atrim=" + l_cut + {STRING_32} ",asetpts=PTS-STARTPTS,apad=pad_dur=" + seconds (Hold_s)
				+ {STRING_32} ",afade=t=out:" + l_fade + {STRING_32} "," + Loudness + {STRING_32} ",aresample=48000[ao]")
		ensure
			ends_with_audio: Result.ends_with ({STRING_32} "[ao]")
			thumbnail_when_given: a_with_thumbnail = Result.has_substring ({STRING_32} "[1:v]")
		end

	arguments (a_source, a_output: READABLE_STRING_32; a_thumbnail: detachable READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- ffmpeg's arguments to finish `a_source' into `a_output', opening on `a_thumbnail' when given.
		require
			source_present: not a_source.is_empty
			output_present: not a_output.is_empty
			not_in_place: not a_source.same_string (a_output)
		do
			create Result.make (40)
			add (Result, <<"-hide_banner", "-v", "error", "-y", "-i">>)
			Result.extend (a_source.to_string_32.twin)
			if attached a_thumbnail as al_thumbnail then
				add (Result, <<"-loop", "1", "-framerate", "60", "-t">>)
				Result.extend (seconds (Thumbnail_s + Dissolve_s + 0.25))
				Result.extend ({STRING_32} "-i")
				Result.extend (al_thumbnail.to_string_32.twin)
			end
			Result.extend ({STRING_32} "-filter_complex")
			Result.extend (filter (a_thumbnail /= Void))
			add (Result, <<"-map", "[vo]", "-map", "[ao]", "-c:v", "libx264", "-preset", "medium", "-crf", "17",
				"-pix_fmt", "yuv420p", "-r", "60", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest">>)
			Result.extend (a_output.to_string_32.twin)
		ensure
			output_last: Result.last.same_string (a_output)
			source_first_input: Result [6].same_string (a_source)
		end

	extract_arguments (a_source, a_samples: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- ffmpeg's arguments to write `a_source's sound to `a_samples' as 16 kHz mono float (the
			-- transcriber's input).
		require
			source_present: not a_source.is_empty
			samples_present: not a_samples.is_empty
		do
			create Result.make (16)
			add (Result, <<"-hide_banner", "-v", "error", "-y", "-i">>)
			Result.extend (a_source.to_string_32.twin)
			add (Result, <<"-vn", "-ac", "1", "-ar", "16000", "-f", "f32le">>)
			Result.extend (a_samples.to_string_32.twin)
		ensure
			samples_last: Result.last.same_string (a_samples)
		end

feature -- Formatting

	seconds (a_value: REAL_64): STRING_32
			-- `a_value' with three decimals ("1.250"), as ffmpeg reads seconds.
		require
			non_negative: a_value >= 0
		local
			l_ms: INTEGER_64
			l_frac: STRING_32
		do
			l_ms := (a_value * 1000).rounded_real_64.truncated_to_integer_64
			l_frac := (l_ms \\ 1000).out.to_string_32
			from until l_frac.count >= 3 loop
				l_frac.prepend_character ('0')
			end
			Result := (l_ms // 1000).out.to_string_32 + {STRING_32} "." + l_frac
		ensure
			three_decimals: Result.count >= 5 and then Result [Result.count - 3] = '.'
		end

feature {NONE} -- Implementation

	add (a_list: ARRAYED_LIST [STRING_32]; a_items: ARRAY [STRING_32])
		do
			across a_items as ic loop
				a_list.extend (ic.twin)
			end
		end

invariant
	ordered: start < speech_end and speech_end <= source_end

end
