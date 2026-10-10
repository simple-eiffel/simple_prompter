note
	description: "[
		Renders a take's cut list to final.mp4 in the session's out folder (plan Step 4c;
		F-01 section 8.5): one ffmpeg pass from PT_RENDER_PLAN (trim/atrim per cut, 20 ms
		fades at the joints, concat, h264_nvenc + AAC) with the filter graph in a script
		file, and, beside it, final.srt / final.vtt captions from the script's own text
		(PT_CAPTION_BUILDER) and chapters.txt (PT_CHAPTER_WRITER). ffmpeg runs as a child
		process; `poll' (each tick) drains its output pipe, which would otherwise fill and
		stall it, and notices the end.
	]"
	author: "Larry Rix"

class
	PT_RENDERER

create
	make

feature {NONE} -- Initialization

	make (a_ffmpeg: READABLE_STRING_32)
		require
			ffmpeg_present: not a_ffmpeg.is_empty
		do
			create ffmpeg.make_from_string (a_ffmpeg)
			create status.make_empty
			create output_path.make_empty
			create process.make
		ensure
			idle: not is_rendering
		end

feature -- Constants

	Fade_ms: INTEGER = 20
			-- Audio fade at every joint (the spike's click-free value).

feature -- Access

	ffmpeg: STRING_32
	status: STRING_32
			-- What the renderer is doing, or did.
	output_path: STRING_32
			-- final.mp4 of the last render.
	is_rendering: BOOLEAN
	succeeded: BOOLEAN
			-- Did the last render produce final.mp4?

feature -- Commands

	start (a_folder: PT_SESSION_FOLDER; a_revision: PT_SCRIPT_REVISION; a_analysis: PT_ANALYSIS; a_journal: PT_JOURNAL; a_video_delay_ms: INTEGER)
			-- Write the captions and chapters and start ffmpeg on the take's cut list, the picture moved
			-- `a_video_delay_ms' (PT_TAKE_SYNC).
		require
			not_rendering: not is_rendering
			analyzed: a_analysis.is_success
			delay_in_range: a_video_delay_ms >= {PT_TAKE_SYNC}.Min_ms and a_video_delay_ms <= {PT_TAKE_SYNC}.Max_ms
		local
			l_plan: PT_RENDER_PLAN
			l_captions: PT_CAPTION_BUILDER
			l_filter, l_line: STRING_32
			l_ok: BOOLEAN
		do
			succeeded := False
			if a_analysis.cuts.count = 0 then
				status := {STRING_32} "nothing to render: the analysis kept no cuts"
			else
				output_path := a_folder.out_dir + {STRING_32} "\final.mp4"
				l_filter := a_folder.out_dir + {STRING_32} "\final.filter"
					-- A new render replaces what an earlier Publish kept (0.5.0): Publish reads the
					-- render from "final (before cleanup).mp4" when it is there.
				across <<{STRING_32} "\final (before cleanup).mp4", {STRING_32} "\final (analyzer original).srt",
					{STRING_32} "\final (analyzer original).vtt">> as ic loop
					l_ok := (create {SIMPLE_FILE}.make (a_folder.out_dir + ic)).delete
				end
				create l_plan.make (ffmpeg, Fade_ms, False)
				l_plan.set_video_delay (a_video_delay_ms)
				l_ok := (create {SIMPLE_FILE}.make (l_filter)).set_content (l_plan.filter_script (a_analysis.cuts))
				create l_captions.make
				l_captions.build (a_revision, a_analysis.cuts, a_analysis.timeline)
				l_ok := (create {SIMPLE_FILE}.make (a_folder.out_dir + {STRING_32} "\final.srt")).set_content (l_captions.srt_text (l_captions.last_cues))
				l_ok := (create {SIMPLE_FILE}.make (a_folder.out_dir + {STRING_32} "\final.vtt")).set_content (l_captions.vtt_text (l_captions.last_cues))
				l_ok := (create {SIMPLE_FILE}.make (a_folder.out_dir + {STRING_32} "\chapters.txt")).set_content (
					(create {PT_CHAPTER_WRITER}.make).text (a_revision, a_analysis.cuts, a_analysis.timeline, a_journal))
				l_line := quoted (ffmpeg)
				across l_plan.arguments (a_folder.raw_path, l_filter, output_path) as ic loop
					l_line.append_character (' ')
					l_line.append (quoted (ic))
				end
				create process.make
				process.start (l_line)
				if attached process.last_error as al_e then
					status := {STRING_32} "could not start ffmpeg: " + al_e
				else
					is_rendering := True
					started_ms := now_ms
					status := {STRING_32} "rendering " + a_analysis.cuts.count.out + {STRING_32} " cuts..."
				end
			end
		end

	poll
			-- Drain ffmpeg's output; when it has ended, record the outcome.
		local
			l_text: detachable STRING_32
		do
			if is_rendering then
				l_text := process.read_available_output
				process.accumulated_output.wipe_out
				if not process.is_running then
					l_text := process.read_available_output
					is_rendering := False
					succeeded := process.exit_code = 0 and then (create {SIMPLE_FILE}.make (output_path)).exists
					if succeeded then
						status := {STRING_32} "rendered in " + ((now_ms - started_ms) / 1000).truncated_to_integer.out + {STRING_32} " s: final.mp4, final.srt, final.vtt, chapters.txt"
					else
						status := {STRING_32} "render failed (ffmpeg exit " + process.exit_code.out + {STRING_32} ")" + tail_of (l_text)
					end
				else
					status := {STRING_32} "rendering... " + ((now_ms - started_ms) / 1000).truncated_to_integer.out + {STRING_32} " s"
				end
			end
		end

	cancel
			-- Stop a render in progress.
		local
			l_ok: BOOLEAN
			l_exit: INTEGER
		do
			if is_rendering and then process.is_running then
				l_ok := process.kill
				l_exit := process.wait (3000)
			end
			is_rendering := False
		ensure
			stopped: not is_rendering
		end

feature {NONE} -- Implementation

	process: SIMPLE_ASYNC_PROCESS
	started_ms: REAL_64

	quoted (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' as one command-line argument, always a new string.
		do
			if a_text.is_empty or a_text.has (' ') or a_text.has ('(') or a_text.has ('&') or a_text.has ('[') then
				Result := {STRING_32} "%"" + a_text + {STRING_32} "%""
			else
				create Result.make_from_string (a_text)
			end
		end

	tail_of (a_text: detachable READABLE_STRING_32): STRING_32
		do
			create Result.make_empty
			if attached a_text as al_t and then not al_t.is_empty then
				Result.append ({STRING_32} ": ")
				Result.append (al_t.substring ((al_t.count - 160).max (1), al_t.count))
				Result.left_adjust
				Result.right_adjust
			end
		end

	now_ms: REAL_64
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
