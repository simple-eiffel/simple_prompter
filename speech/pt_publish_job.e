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
		Thumbnails themselves are made outside the program (by Claude, on request).
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
				if run_ffmpeg ((create {PT_FINISH_PLAN}.make (0, 1, 2)).extract_arguments (l_source, l_samples)) then
					l_duration := file (l_samples).size / 4 / Rate
					tell ({STRING_32} "publishing: listening to the video (whisper)")
					transcriber.transcribe (l_samples, l_duration)
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
			l_ai, l_utf_text: STRING_32
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
				l_thumbnail := thumbnail_in (a_out)
				tell ({STRING_32} "publishing: finishing the video")
				l_ok := file (a_working).delete
				if run_ffmpeg (l_plan.arguments (a_source, a_working, l_thumbnail)) and then file (a_working).exists then
					l_ok := file (a_final).delete
					l_ok := file (a_working).move_to (a_final)
					succeeded := file (a_final).exists
				end
				if succeeded then
					summary := {STRING_32} "published: final.mp4 (" + clock (l_plan.length)
						+ (if l_thumbnail /= Void then {STRING_32} ", opens on the thumbnail" else {STRING_32} ", no thumbnail yet" end)
						+ {STRING_32} "), " + Captions_name + {STRING_32} " (" + l_captions.last_cues.count.out + {STRING_32} " captions), "
						+ l_chapters.chapters.count.out + {STRING_32} " chapters, youtube.txt, facebook.txt, x.txt; " + l_ai
				else
					summary := {STRING_32} "publish: the words are written, but the video did not finish" + last_output
				end
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

feature {NONE} -- ffmpeg

	last_output: STRING_32
			-- The end of ffmpeg's last output, for a failure message.
		attribute
			create Result.make_empty
		end

	run_ffmpeg (a_arguments: LIST [STRING_32]): BOOLEAN
			-- Run ffmpeg with `a_arguments' to the end; did it succeed?
		local
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

end
