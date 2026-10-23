note
	description: "[
		Publish one rendered take (0.5.0): everything that used to be done by hand before posting
		to YouTube, Facebook Reels and X, run in the speech worker on the models it has loaded.

		1. The render (final.mp4) is kept as "final (before cleanup).mp4" and read from there,
		   so Publish can run again (after a new thumbnail, say) without losing anything.
		2. Its sound goes to whisper (PT_WHISPER_TRANSCRIBER, Silero speech map and words).
		3. Captions of what was said (PT_SPOKEN_CAPTIONS) go to captions.en_US.SRT, the name
		   Facebook Reels wants; the render's captions are kept as "final (analyzer original)".
		4. Chapters (PT_CHAPTER_PICKER) and, when the local AI is wanted and running, its title,
		   description, hashtags, chapter names, question and X line (PT_OLLAMA_WRITER).
		5. youtube.txt, facebook.txt and x.txt (PT_PUBLISH_COPY).
		6. The finished final.mp4 (PT_FINISH_PLAN): the opening silence trimmed, the thumbnail
		   dissolving into the picture when out\ has one (thumbnail.jpg or .png, else the first
		   thumbnail_A*), a fade to black after the last word, YouTube's loudness.
		7. transcript.txt (0.5.9): the script's spoken paragraphs, for Facebook's text transcript.
		8. reel.mp4 (0.5.9, PT_REEL_PLAN): the vertical Facebook Reel, 1080x1920, the title in the
		   top band and the captions burned in below the picture, opening on cover.jpg when
		   out\ has one.
		Since 0.7.0, between 5 and 6: thumbnails A and B and cover.jpg (PT_PICTURE_COMPOSER) when
		out\ has none: a frame picked by the local AI's vision from a contact sheet of the take
		(else the one about 9 seconds in), the speaker cut out with BiRefNet-portrait (no chair),
		the words from the AI's suggestions or the title. Hand-made pictures in out\ are kept.
	]"
	author: "Larry Rix"

class
	PT_PUBLISH_JOB

create
	make

feature {NONE} -- Initialization

	make (a_transcriber: PT_TRANSCRIBER; a_ffmpeg: READABLE_STRING_32)
		require
			ffmpeg_present: not a_ffmpeg.is_empty
		do
			transcriber := a_transcriber
			ffmpeg := a_ffmpeg.to_string_32.twin
			create summary.make_empty
		ensure
			transcriber_set: transcriber = a_transcriber
		end

feature -- Constants

	Source_name: STRING_32 = "final (before cleanup).mp4"
	Final_name: STRING_32 = "final.mp4"
	Captions_name: STRING_32 = "captions.en_US.SRT"
	Reel_name: STRING_32 = "reel.mp4"
	Cover_name: STRING_32 = "cover.jpg"
			-- The vertical reel and the cover it opens on (0.5.9).
	Rate: INTEGER = 16_000
	Max_run_ms: INTEGER = 1_200_000
			-- Longest an ffmpeg run may take (20 minutes).

feature -- Access

	transcriber: PT_TRANSCRIBER
	ffmpeg: STRING_32
	succeeded: BOOLEAN
	summary: STRING_32
			-- One line: what was written, or why not.

	on_stage: detachable PROCEDURE [STRING_32]
			-- Told what the job is doing as it goes.

	set_on_stage (a_action: PROCEDURE [STRING_32])
		do
			on_stage := a_action
		end

	on_progress: detachable PROCEDURE [REAL_64]
			-- Told how far the job has got (0..1; 0.6.0, the Publish button's progress bar):
			-- the sound 0-5%, whisper 5-30%, the words 30-40%, final.mp4 40-80% and reel.mp4
			-- 80-100%, the two encodes by ffmpeg's time readings.

	set_on_progress (a_action: PROCEDURE [REAL_64])
		do
			on_progress := a_action
		ensure
			set: on_progress = a_action
		end

feature -- Basic operations

	run (a_root, a_link, a_hashtags, a_ollama_url, a_ollama_model: READABLE_STRING_32; a_use_ollama: BOOLEAN)
			-- Publish the take in session folder `a_root'.
		require
			root_present: not a_root.is_empty
		local
			l_out, l_source, l_final, l_samples, l_working: STRING_32
			l_duration: REAL_64
			l_ok: BOOLEAN
		do
			succeeded := False
			l_out := a_root.to_string_32 + {STRING_32} "\out"
			l_final := l_out + {STRING_32} "\" + Final_name
			l_source := l_out + {STRING_32} "\" + Source_name
			if not file (l_source).exists and file (l_final).exists then
				l_ok := file (l_final).move_to (l_source)
			end
			if not file (l_source).exists then
				summary := {STRING_32} "render first: there is no final.mp4"
			else
				l_samples := l_out + {STRING_32} "\publish.f32"
				tell ({STRING_32} "publishing: reading the video's sound")
				tell_progress (0.0)
				if run_ffmpeg ((create {PT_FINISH_PLAN}.make (0, 1, 2)).extract_arguments (l_source, l_samples), 0, 0, 0.05) then
					l_duration := file (l_samples).size / 4 / Rate
					tell ({STRING_32} "publishing: listening to the video (whisper)")
					tell_progress (0.05)
					transcriber.transcribe (l_samples, l_duration)
					tell_progress (0.30)
					if transcriber.is_success and then attached transcriber.last_map as al_map and then attached transcriber.last_heard as al_heard then
						if al_map.span_count = 0 then
							summary := {STRING_32} "publish stopped: no speech heard in final.mp4"
						else
							l_working := l_out + {STRING_32} "\final.publishing.mp4"
							publish (a_root.to_string_32, l_out, l_source, l_working, l_final, al_map, al_heard, l_duration,
								a_link, a_hashtags, a_ollama_url, a_ollama_model, a_use_ollama)
						end
					elseif attached transcriber.last_error as al_e then
						summary := {STRING_32} "publish stopped: " + al_e
					else
						summary := {STRING_32} "publish stopped: the video could not be transcribed"
					end
				else
					summary := {STRING_32} "publish stopped: ffmpeg could not read final.mp4" + last_output
				end
				l_ok := file (l_samples).delete
			end
		ensure
			explained: not summary.is_empty
		end

feature {NONE} -- Steps

	publish (a_root, a_out, a_source, a_working, a_final: STRING_32; a_map: PT_SPEECH_MAP; a_heard: PT_HEARD_WORDS; a_duration: REAL_64;
			a_link, a_hashtags, a_ollama_url, a_ollama_model: READABLE_STRING_32; a_use_ollama: BOOLEAN)
			-- Steps 3 to 6, the sound heard.
		local
			l_start, l_end: REAL_64
			l_plan: PT_FINISH_PLAN
			l_script: PT_SCRIPT_TEXT
			l_captions: PT_SPOKEN_CAPTIONS
			l_chapters: PT_CHAPTER_PICKER
			l_suggestions: PT_PUBLISH_SUGGESTIONS
			l_writer: PT_OLLAMA_WRITER
			l_copy: PT_PUBLISH_COPY
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_thumbnail: detachable STRING_32
			l_ai, l_utf_text, l_pictures: STRING_32
			l_ok: BOOLEAN
			i: INTEGER
		do
			l_start := (a_map.span (1).t0 - {PT_FINISH_PLAN}.Lead_s).max (0)
			l_end := a_map.span (a_map.span_count).t1.min (a_duration)
			if l_end <= l_start then
				summary := {STRING_32} "publish stopped: the speech is too short"
			else
				create l_plan.make (l_start, l_end, a_duration)
				create l_script.make (script_text (a_root))
				create l_words.make (a_heard.count)
				from i := 1 until i > a_heard.count loop
					l_words.extend (a_heard.word (i))
					i := i + 1
				end
				create l_captions.make
				l_captions.build (l_words, a_map, l_script, l_start, l_plan.length)
				keep_original (a_out, {STRING_32} "final.srt", {STRING_32} "final (analyzer original).srt")
				keep_original (a_out, {STRING_32} "final.vtt", {STRING_32} "final (analyzer original).vtt")
				l_utf_text := utf32 ((create {PT_CAPTION_BUILDER}.make).srt_text (l_captions.last_cues))
				l_ok := file (a_out + {STRING_32} "\" + Captions_name).set_content (l_utf_text)
				create l_chapters.make
				l_chapters.pick (l_script, l_captions.last_cues, l_plan.length)
				create l_suggestions.make_empty
				l_ai := {STRING_32} "local AI off"
				if a_use_ollama and not a_ollama_url.is_empty then
					tell ({STRING_32} "publishing: asking the local AI for titles and chapter names")
					create l_writer.make (a_ollama_url, a_ollama_model)
					l_suggestions := l_writer.suggest (l_script, l_chapters.openings (l_script))
					if l_suggestions.has_any then
						l_ai := {STRING_32} "words by " + l_writer.last_model
						if l_suggestions.chapter_labels.count = l_chapters.chapters.count
							and then across l_suggestions.chapter_labels as ic all not ic.is_empty end then
							l_chapters.set_labels (l_suggestions.chapter_labels)
						end
					else
						l_ai := {STRING_32} "local AI: " + l_writer.last_error
					end
				end
				create l_copy.make (l_script, l_chapters, l_suggestions, a_link, a_hashtags)
				l_ok := file (a_out + {STRING_32} "\youtube.txt").set_content (l_copy.youtube_text)
				l_ok := file (a_out + {STRING_32} "\facebook.txt").set_content (l_copy.facebook_text)
				l_ok := file (a_out + {STRING_32} "\x.txt").set_content (l_copy.x_text)
				l_ok := file (a_out + {STRING_32} "\transcript.txt").set_content (l_script.transcript)
				tell_progress (0.40)
				l_pictures := make_pictures (a_out, a_source, l_start, l_end, l_script.title, l_suggestions,
					a_ollama_url, a_ollama_model, a_use_ollama)
				tell_progress (0.48)
				l_thumbnail := thumbnail_in (a_out)
				tell ({STRING_32} "publishing: finishing the video")
				l_ok := file (a_working).delete
				if run_ffmpeg (l_plan.arguments (a_source, a_working, l_thumbnail), l_plan.length, 0.48, 0.82) and then file (a_working).exists then
					l_ok := file (a_final).delete
					l_ok := file (a_working).move_to (a_final)
					succeeded := file (a_final).exists
				end
				if succeeded then
					tell ({STRING_32} "publishing: making the vertical reel")
					summary := {STRING_32} "published: final.mp4 (" + clock (l_plan.length)
						+ (if l_thumbnail /= Void then {STRING_32} ", opens on the thumbnail" else {STRING_32} ", no thumbnail yet" end)
						+ {STRING_32} "), " + reel_note (make_reel (a_out, a_final, l_script.title, l_plan.length, l_captions.last_cues), a_out)
						+ {STRING_32} ", " + Captions_name + {STRING_32} " (" + l_captions.last_cues.count.out + {STRING_32} " captions), "
						+ l_chapters.chapters.count.out + {STRING_32} " chapters, youtube.txt, facebook.txt, x.txt, transcript.txt; " + l_ai
						+ {STRING_32} "; " + l_pictures
				else
					summary := {STRING_32} "publish: the words are written, but the video did not finish" + last_output
				end
			end
		end

	make_reel (a_out, a_final, a_title: STRING_32; a_length: REAL_64; a_cues: LIST [PT_CAPTION_CUE]): BOOLEAN
			-- Make out\reel.mp4 from the finished `a_final' (PT_REEL_PLAN); did it succeed?
		require
			length_positive: a_length > 0
		local
			l_plan: PT_REEL_PLAN
			l_ass, l_filter, l_reel, l_working, l_cover_path: STRING_32
			l_cover: detachable STRING_32
			l_ok: BOOLEAN
		do
			create l_plan.make (a_title, a_length)
			l_ass := a_out + {STRING_32} "\reel.ass"
			l_filter := a_out + {STRING_32} "\reel.filter"
			l_reel := a_out + {STRING_32} "\" + Reel_name
			l_working := a_out + {STRING_32} "\reel.publishing.mp4"
			l_cover_path := a_out + {STRING_32} "\" + Cover_name
			if file (l_cover_path).exists then
				l_cover := l_cover_path
			end
			if file (l_working).exists then
				l_ok := file (l_working).delete
			end
			l_ok := file (l_ass).set_content (l_plan.ass_text (a_cues))
				and then file (l_filter).set_content (l_plan.filter_script (l_ass, l_cover /= Void))
			if l_ok and then run_ffmpeg (l_plan.arguments (a_final, l_cover, l_filter, l_working), a_length, 0.82, 1.0) and then file (l_working).exists then
				l_ok := file (l_reel).delete
				Result := file (l_working).move_to (l_reel) and file (l_reel).exists
			end
			if Result then
				l_ok := file (l_ass).delete and file (l_filter).delete
			end
		end

	reel_note (a_made: BOOLEAN; a_out: STRING_32): STRING_32
			-- What the summary says of the reel.
		do
			if not a_made then
				Result := {STRING_32} "the vertical reel did not finish" + last_output
			elseif file (a_out + {STRING_32} "\" + Cover_name).exists then
				Result := Reel_name + {STRING_32} " (vertical, opens on " + Cover_name + {STRING_32} ")"
			else
				Result := Reel_name + {STRING_32} " (vertical, no " + Cover_name + {STRING_32} " yet)"
			end
		end

	script_text (a_root: STRING_32): STRING_32
			-- The take's script as last revised (script\rN.md with the highest N), or empty.
		local
			l_best, l_n: INTEGER
			l_name: STRING_32
			l_dir: SIMPLE_FILE
		do
			create Result.make_empty
			create l_dir.make (a_root + {STRING_32} "\script")
			if l_dir.is_directory then
				across l_dir.files as ic loop
					l_name := file_name (ic)
					if l_name.count > 4 and then l_name [1] = 'r' and then l_name.ends_with ({STRING_32} ".md")
						and then l_name.substring (2, l_name.count - 3).is_integer then
						l_n := l_name.substring (2, l_name.count - 3).to_integer
						if l_n > l_best then
							l_best := l_n
						end
					end
				end
				if l_best > 0 then
					Result := file (a_root + {STRING_32} "\script\r" + l_best.out + {STRING_32} ".md").read_text_utf_8
				end
			end
		end

	thumbnail_in (a_out: STRING_32): detachable STRING_32
			-- thumbnail.jpg or thumbnail.png in `a_out', else the first thumbnail_A* image.
		local
			l_name, l_lower: STRING_32
			l_dir: SIMPLE_FILE
		do
			if file (a_out + {STRING_32} "\thumbnail.jpg").exists then
				Result := a_out + {STRING_32} "\thumbnail.jpg"
			elseif file (a_out + {STRING_32} "\thumbnail.png").exists then
				Result := a_out + {STRING_32} "\thumbnail.png"
			else
				create l_dir.make (a_out)
				across l_dir.files as ic until attached Result loop
					l_name := file_name (ic)
					l_lower := l_name.as_lower
					if l_lower.starts_with ({STRING_32} "thumbnail_a") and (l_lower.ends_with ({STRING_32} ".jpg") or l_lower.ends_with ({STRING_32} ".png")) then
						Result := a_out + {STRING_32} "\" + l_name
					end
				end
			end
		end

	keep_original (a_out, a_name, a_kept: STRING_32)
			-- Rename `a_name' in `a_out' to `a_kept', unless `a_kept' is already there (then drop it).
		local
			l_ok: BOOLEAN
		do
			if file (a_out + {STRING_32} "\" + a_name).exists then
				if file (a_out + {STRING_32} "\" + a_kept).exists then
					l_ok := file (a_out + {STRING_32} "\" + a_name).delete
				else
					l_ok := file (a_out + {STRING_32} "\" + a_name).move_to (a_out + {STRING_32} "\" + a_kept)
				end
			end
		end

feature {NONE} -- Pictures (0.7.0)

	make_pictures (a_out, a_source: STRING_32; a_start, a_end: REAL_64; a_title: STRING_32; a_suggestions: PT_PUBLISH_SUGGESTIONS;
			a_ollama_url, a_ollama_model: READABLE_STRING_32; a_use_ollama: BOOLEAN): STRING_32
			-- Thumbnails A and B and cover.jpg in `a_out' when it has none (hand-made ones are kept),
			-- from the speech between `a_start' and `a_end' of `a_source'; what was done, for the summary.
		local
			l_need_thumbnails, l_need_cover, l_ok: BOOLEAN
			l_ai: SIMPLE_IMAGE_AI
			l_images: SIMPLE_IMAGE
			l_model, l_work, l_png, l_how, l_name: STRING_32
			l_plan: PT_FRAME_PLAN
			l_frames: ARRAYED_LIST [IMG_IMAGE]
			l_cutout: IMG_CUTOUT
			l_composer: detachable PT_PICTURE_COMPOSER
			l_sheet: PT_CONTACT_SHEET
			l_writer: PT_OLLAMA_WRITER
			l_words: PT_PICTURE_WORDS
			l_picture: IMG_IMAGE
			l_pick, i: INTEGER
		do
			l_need_thumbnails := thumbnail_in (a_out) = Void
			l_need_cover := not file (a_out + {STRING_32} "\" + Cover_name).exists
			create l_ai.make
			l_model := l_ai.portrait_model_path
			if not l_need_thumbnails and not l_need_cover then
				Result := {STRING_32} "your thumbnails and cover kept"
			elseif not file (l_model).exists then
				Result := {STRING_32} "no pictures made: the cutout model is not at " + l_model
			else
				tell ({STRING_32} "publishing: picking a frame for the thumbnails")
				l_work := a_out + {STRING_32} "\publish pictures"
				remove_folder (l_work)
				(create {DIRECTORY}.make_with_name (l_work)).create_dir
				create l_plan.make (a_start, a_end)
				create l_images.make
				create l_frames.make (l_plan.times.count)
				from i := 1 until i > l_plan.times.count loop
					l_png := l_work + {STRING_32} "\frame " + i.out + {STRING_32} ".png"
					if run_ffmpeg (l_plan.frame_arguments (a_source, l_plan.times [i], l_png), 0, 0.40, 0.40)
						and then attached l_images.load (l_png) as al_frame then
						l_frames.extend (al_frame)
					else
						l_frames.extend (create {IMG_IMAGE}.make (1, 1))
					end
					i := i + 1
				end
				tell ({STRING_32} "publishing: cutting the speaker out (about 10 seconds)")
				l_cutout := l_ai.new_portrait_cutout (l_model)
				l_pick := l_plan.fallback_index
				l_how := {STRING_32} "the frame about 9 seconds in"
				if not l_cutout.is_ready then
					Result := {STRING_32} "no pictures made: " + l_cutout.last_error.to_string_32
				elseif l_frames [l_pick].width < 2 then
					Result := {STRING_32} "no pictures made: ffmpeg could not read the frames" + last_output
				else
					l_composer := composer_for (l_cutout, l_frames [l_pick])
					if attached l_composer as al_first and then a_use_ollama and then not a_ollama_url.is_empty then
						tell ({STRING_32} "publishing: asking the local AI to pick the thumbnail frame")
						create l_sheet.make (l_frames, al_first.face_box)
						l_png := l_work + {STRING_32} "\contact sheet.png"
						if l_sheet.image.save_png (l_png) then
							create l_writer.make (a_ollama_url, a_ollama_model)
							i := l_writer.pick_frame (l_png, l_sheet.count)
							if i > 0 and then l_frames [i].width > 1 then
								l_how := {STRING_32} "frame " + i.out + {STRING_32} " of " + l_sheet.count.out
									+ {STRING_32} ", picked by " + l_writer.last_model
								if i /= l_pick then
									l_pick := i
									al_first.destroy
									l_composer := composer_for (l_cutout, l_frames [l_pick])
								end
							else
								l_how := l_how + {STRING_32} " (" + l_writer.last_error + {STRING_32} ")"
							end
						end
						l_sheet.image.destroy
					end
					if attached l_composer as al_composer and then al_composer.has_person then
						tell ({STRING_32} "publishing: making the thumbnails and the cover")
						create l_words.make (a_title, a_suggestions)
						l_name := file_safe (a_title)
						create Result.make_empty
						if l_need_thumbnails then
							l_picture := al_composer.thumbnail (l_words, False)
							l_ok := l_picture.save_jpg (a_out + {STRING_32} "\thumbnail_A - " + l_name + {STRING_32} " (yellow).jpg", 92)
							l_picture.destroy
							l_picture := al_composer.thumbnail (l_words, True)
							l_ok := l_picture.save_jpg (a_out + {STRING_32} "\thumbnail_B - " + l_name + {STRING_32} " (white and yellow).jpg", 92) and l_ok
							l_picture.destroy
							Result.append ((if l_ok then {STRING_32} "thumbnails A and B made" else {STRING_32} "the thumbnails could not be saved" end))
						end
						if l_need_cover then
							l_picture := al_composer.cover (l_words)
							l_ok := l_picture.save_jpg (a_out + {STRING_32} "\" + Cover_name, 92)
							l_picture.destroy
							if not Result.is_empty then
								Result.append ({STRING_32} " and ")
							end
							Result.append ((if l_ok then Cover_name + {STRING_32} " made" else Cover_name + {STRING_32} " could not be saved" end))
						end
						Result.append ({STRING_32} " (" + l_how + (if l_words.from_ai then {STRING_32} ", words by the local AI" else {STRING_32} ", words from the title" end) + {STRING_32} ")")
						al_composer.destroy
					else
						Result := {STRING_32} "no pictures made: no one was found in the frame"
					end
				end
				l_cutout.close
				across l_frames as ic loop
					ic.destroy
				end
				remove_folder (l_work)
			end
		ensure
			explained: not Result.is_empty
		end

	composer_for (a_cutout: IMG_CUTOUT; a_frame: IMG_IMAGE): detachable PT_PICTURE_COMPOSER
			-- A composer for `a_frame' with the speaker cut out by `a_cutout', or Void when the cut fails.
		require
			ready: a_cutout.is_ready
			frame_usable: a_frame.is_usable
		do
			if attached a_cutout.mask_for (a_frame) as al_mask then
				create Result.make (a_frame, al_mask)
				al_mask.destroy
			end
		end

	file_safe (a_title: STRING_32): STRING_32
			-- `a_title' without the characters Windows forbids in a file name.
		do
			create Result.make (a_title.count)
			across a_title as ic loop
				if ic.code > 127 or else not ("<>:%"/\|?*").has (ic.to_character_8) then
					Result.append_character (ic)
				end
			end
			Result.left_adjust
			Result.right_adjust
			if Result.is_empty then
				Result := {STRING_32} "video"
			end
		end

	remove_folder (a_path: STRING_32)
			-- Delete the folder `a_path' and what is in it, if it is there.
		local
			l_dir: DIRECTORY
		do
			create l_dir.make_with_name (a_path)
			if l_dir.exists then
				l_dir.recursive_delete
			end
		end

feature {NONE} -- ffmpeg

	last_output: STRING_32
			-- The end of ffmpeg's last output, for a failure message.
		attribute
			create Result.make_empty
		end

	run_ffmpeg (a_arguments: LIST [STRING_32]; a_length, a_from, a_to: REAL_64): BOOLEAN
			-- Run ffmpeg with `a_arguments' to the end; did it succeed? While it runs, progress goes
			-- from `a_from' to `a_to' by its time readings against `a_length' seconds (0: no readings).
		require
			ordered: 0 <= a_from and a_from <= a_to and a_to <= 1
		local
			l_fraction: REAL_64
			l_process: SIMPLE_ASYNC_PROCESS
			l_line, l_all: STRING_32
			l_waited: INTEGER
			l_ok: BOOLEAN
			l_env: EXECUTION_ENVIRONMENT
		do
			create l_env
			l_line := quoted (ffmpeg)
			across a_arguments as ic loop
				l_line.append_character (' ')
				l_line.append (quoted (ic))
			end
			create l_all.make_empty
			create l_process.make
			l_process.set_ends_with_owner (True)
			l_process.start (l_line)
			if attached l_process.last_error as al_e then
				last_output := {STRING_32} ": " + al_e
			else
				from until not l_process.is_running or l_waited > Max_run_ms loop
					if attached l_process.read_available_output as al_t then
						l_all.append (al_t)
						if a_length > 0 then
							l_fraction := (create {PT_FFMPEG_PROGRESS}.make).fraction (al_t, a_length)
							if l_fraction >= 0 then
								tell_progress (a_from + (a_to - a_from) * l_fraction)
							end
						end
						if l_all.count > 20_000 then
							l_all.remove_head (l_all.count - 4_000)
						end
					end
					l_process.accumulated_output.wipe_out
					l_env.sleep (100_000_000)
					l_waited := l_waited + 100
				end
				if l_process.is_running then
					l_ok := l_process.kill
				end
				if attached l_process.read_available_output as al_t then
					l_all.append (al_t)
				end
				Result := not l_process.is_running and then l_process.exit_code = 0
				if Result then
					tell_progress (a_to)
				end
				last_output := {STRING_32} ""
				if not Result and not l_all.is_empty then
					last_output := {STRING_32} ": " + l_all.substring ((l_all.count - 200).max (1), l_all.count)
				end
			end
		end

	quoted (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' as one command-line argument, always a new string.
		do
			if a_text.is_empty or a_text.has (' ') or a_text.has ('(') or a_text.has ('&') or a_text.has ('[') or a_text.has (';') then
				Result := {STRING_32} "%"" + a_text + {STRING_32} "%""
			else
				create Result.make_from_string (a_text)
			end
		ensure
			fresh: Result /= a_text
		end

feature {NONE} -- Implementation

	file (a_path: READABLE_STRING_32): SIMPLE_FILE
		do
			create Result.make (a_path)
		end

	file_name (a_entry: STRING_32): STRING_32
			-- The name part of `a_entry' (a name or a path).
		do
			if a_entry.has ('\') then
				Result := a_entry.substring (a_entry.last_index_of ('\', a_entry.count) + 1, a_entry.count)
			else
				Result := a_entry.twin
			end
		end

	utf32 (a_utf8: STRING_8): STRING_32
		local
			l_utf: UTF_CONVERTER
		do
			Result := l_utf.utf_8_string_8_to_string_32 (a_utf8)
		end

	clock (a_seconds: REAL_64): STRING_32
		do
			Result := (create {PT_CHAPTER_PICKER}.make).clock (a_seconds)
		end

	tell (a_stage: STRING_32)
		do
			if attached on_stage as al_action then
				al_action.call ([a_stage])
			end
		end

	tell_progress (a_fraction: REAL_64)
		do
			if attached on_progress as al_action then
				al_action.call ([a_fraction.max (0).min (1)])
			end
		end

end
