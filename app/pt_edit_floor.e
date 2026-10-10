note
	description: "[
		The minimal Edit Floor (plan Step 4c; F-01 section 8, the approved minimal editor):
		a "Last take" panel in the control window. It shows the take's numbers, its cuts
		(times and the script words each covers) and its flags (things to check); a
		click previews a cut or a flag in ffplay (F-01 8.3 v1: -ss / -t on the raw file),
		and the buttons render final.mp4 with captions and chapters, play it, or open the
		session folder. The take is read back from its folder (PT_SESSION_LOADER).
	]"
	author: "Larry Rix"

class
	PT_EDIT_FLOOR

create
	make

feature {NONE} -- Initialization

	make (a_ffmpeg: READABLE_STRING_32)
		require
			ffmpeg_present: not a_ffmpeg.is_empty
		do
			create renderer.make (a_ffmpeg)
			ffplay := sibling_tool (a_ffmpeg, {STRING_32} "ffplay.exe")
			create status_note.make_empty
			create preview.make
			create rows.make (16)
		ensure
			empty: not has_take
		end

feature -- Constants

	Max_rows: INTEGER = 10
			-- Cuts and flags listed (each list).

feature -- Access

	take: detachable PT_SESSION_LOADER
			-- The take shown.

	renderer: PT_RENDERER
	ffplay: STRING_32
	status_note: STRING_32
			-- The last thing a click did (or why it could not).

	has_take: BOOLEAN
		do
			Result := attached take as al_take and then al_take.is_loaded and then attached al_take.analysis
		end

feature -- Commands

	show (a_root: READABLE_STRING_32)
			-- Read the take in session folder `a_root' (after its analysis) and show it.
		require
			root_present: not a_root.is_empty
		local
			l_loader: PT_SESSION_LOADER
		do
			create l_loader.make
			l_loader.load (a_root)
			take := l_loader
			if not l_loader.is_loaded then
				status_note := l_loader.last_error.twin
			elseif l_loader.analysis = Void then
				status_note := {STRING_32} "this take has no analysis"
			else
				status_note := {STRING_32} ""
			end
		end

	tick
			-- Each tick: follow a render in progress.
		do
			renderer.poll
		end

	close
			-- Stop a preview or a render (the window is closing).
		local
			l_ok: BOOLEAN
		do
			renderer.cancel
			if preview.is_started and then preview.is_running then
				l_ok := preview.kill
			end
		end

feature -- Display

	paint (p: SW_PAINTER; a_x, a_y, a_w: REAL_64; k: REAL_64)
			-- Draw the panel from (`a_x', `a_y'), `a_w' wide.
		local
			l_y, l_top: REAL_64
			l_flag: PT_FLAG
		do
			rows.wipe_out
			l_y := a_y + 30 * k
			p.font (p.Role_ui, 16, True)
			p.set_color (Ink)
			p.text (a_x, l_y, {STRING_32} "Last take")
			p.font (p.Role_ui, 12, False)
			p.set_color (Muted)
			if attached take as al_take and then attached al_take.folder as al_folder and then attached al_take.analysis as al_analysis
				and then attached al_take.history as al_history then
				l_y := wrapped (p, a_x, l_y + 22 * k, a_w, folder_name (al_folder.root), 20 * k)
				l_y := wrapped (p, a_x, l_y, a_w, {STRING_32} "final " + clock (al_analysis.cuts.output_duration) + {STRING_32} " in "
					+ al_analysis.cuts.count.out + {STRING_32} " cuts  -  " + al_analysis.flags.count.out + {STRING_32} " things to check", 20 * k) + 10 * k
				button (p, a_x, l_y - 18 * k, 92 * k, 26 * k, (if renderer.is_rendering then {STRING_32} "Rendering" else {STRING_32} "Render" end), Action_render, k)
				button (p, a_x + 100 * k, l_y - 18 * k, 92 * k, 26 * k, {STRING_32} "Play final", Action_play_final, k)
				button (p, a_x + 200 * k, l_y - 18 * k, 104 * k, 26 * k, {STRING_32} "Open folder", Action_open_folder, k)
				l_y := l_y + 24 * k
				p.font (p.Role_ui, 12, False)
				p.set_color (Muted)
				if not renderer.status.is_empty then
					l_y := wrapped (p, a_x, l_y, a_w, renderer.status, 20 * k)
				end
				if not status_note.is_empty then
					p.set_color (Danger)
					l_y := wrapped (p, a_x, l_y, a_w, status_note, 20 * k)
					p.set_color (Muted)
				end
				l_y := l_y + 8 * k
				p.font (p.Role_ui, 13, True)
				p.set_color (Ink)
				p.text (a_x, l_y, {STRING_32} "Cuts (click to preview)")
				p.font (p.Role_ui, 12, False)
				p.set_color (Muted)
				across 1 |..| al_analysis.cuts.count.min (Max_rows) as ic loop
					l_y := l_y + 19 * k
					p.text (a_x, l_y, ic.out.to_string_32 + {STRING_32} "  " + clock (al_analysis.cuts.cut (ic).span.t0) + {STRING_32} "-"
						+ clock (al_analysis.cuts.cut (ic).span.t1) + {STRING_32} "  " + short (cut_text (al_analysis.cuts.cut (ic), al_history.current_revision), 48))
					rows.extend ([a_x, l_y - 14 * k, a_w, 19 * k, Action_preview_cut, ic])
				end
				if al_analysis.cuts.count > Max_rows then
					l_y := l_y + 19 * k
					p.text (a_x, l_y, {STRING_32} "... " + (al_analysis.cuts.count - Max_rows).out + {STRING_32} " more")
				end
				l_y := l_y + 28 * k
				p.font (p.Role_ui, 13, True)
				p.set_color (Ink)
				p.text (a_x, l_y, {STRING_32} "Things to check (click to preview)")
				p.font (p.Role_ui, 12, False)
				p.set_color (Muted)
				if al_analysis.flags.is_empty then
					l_y := l_y + 19 * k
					p.text (a_x, l_y, {STRING_32} "none")
				end
				across 1 |..| al_analysis.flags.count.min (Max_rows) as ic loop
					l_flag := al_analysis.flags [ic]
					p.set_color (Flag_ink)
					l_top := l_y + 5 * k
					l_y := wrapped (p, a_x, l_y + 19 * k, a_w, clock (l_flag.span.t0) + {STRING_32} "  " + l_flag.message, 19 * k) - 19 * k
					rows.extend ([a_x, l_top, a_w, l_y - l_top + 5 * k, Action_preview_flag, ic])
				end
			else
				l_y := l_y + 22 * k
				if status_note.is_empty then
					p.text (a_x, l_y, {STRING_32} "Record a take (Ctrl+Alt+R), wrap it (Ctrl+Alt+End):")
					l_y := l_y + 20 * k
					p.text (a_x, l_y, {STRING_32} "its cuts and things to check appear here.")
				else
					p.set_color (Danger)
					l_y := wrapped (p, a_x, l_y, a_w, status_note, 20 * k)
				end
			end
		end

	press (a_x, a_y: REAL_64)
			-- A click at (`a_x', `a_y') (canvas coordinates).
		local
			l_done: BOOLEAN
		do
			across rows as ic until l_done loop
				if a_x >= ic.x and a_x <= ic.x + ic.w and a_y >= ic.y and a_y <= ic.y + ic.h then
					act (ic.action, ic.index)
					l_done := True
				end
			end
		end

feature {NONE} -- Actions

	Action_render: INTEGER = 1
	Action_play_final: INTEGER = 2
	Action_open_folder: INTEGER = 3
	Action_preview_cut: INTEGER = 4
	Action_preview_flag: INTEGER = 5

	act (a_action, a_index: INTEGER)
		do
			if attached take as al_take and then attached al_take.folder as al_folder and then attached al_take.analysis as al_analysis
				and then attached al_take.history as al_history and then attached al_take.journal as al_journal then
				inspect a_action
				when Action_render then
					if not renderer.is_rendering then
						renderer.start (al_folder, al_history.current_revision, al_analysis, al_journal)
						status_note := {STRING_32} ""
					end
				when Action_play_final then
					if (create {SIMPLE_FILE}.make (al_folder.out_dir + {STRING_32} "\final.mp4")).exists then
						play (al_folder.out_dir + {STRING_32} "\final.mp4", 0.0, 0.0, {STRING_32} "final")
					else
						status_note := {STRING_32} "render first: there is no final.mp4 yet"
					end
				when Action_open_folder then
					run ({STRING_32} "explorer.exe " + quoted (al_folder.root))
				when Action_preview_cut then
					if a_index >= 1 and a_index <= al_analysis.cuts.count then
						play (al_folder.raw_path, al_analysis.cuts.cut (a_index).span.t0, al_analysis.cuts.cut (a_index).span.duration,
							{STRING_32} "cut " + a_index.out)
					end
				when Action_preview_flag then
					if a_index >= 1 and a_index <= al_analysis.flags.count then
						play (al_folder.raw_path, (al_analysis.flags [a_index].span.t0 - 2.0).max (0.0),
							al_analysis.flags [a_index].span.duration + 4.0, {STRING_32} "check " + a_index.out)
					end
				else
				end
			end
		end

	play (a_file: STRING_32; a_from, a_seconds: REAL_64; a_title: STRING_32)
			-- Preview `a_seconds' of `a_file' from `a_from' in ffplay (0 seconds: to the end).
		local
			l_line: STRING_32
			l_ok: BOOLEAN
		do
			if preview.is_started and then preview.is_running then
				l_ok := preview.kill
			end
			l_line := quoted (ffplay) + {STRING_32} " -hide_banner -loglevel quiet -nostats -autoexit -window_title "
				+ quoted ({STRING_32} "simple_prompter - " + a_title)
			if a_from > 0 then
				l_line.append ({STRING_32} " -ss " + seconds (a_from))
			end
			if a_seconds > 0 then
				l_line.append ({STRING_32} " -t " + seconds (a_seconds))
			end
			l_line.append ({STRING_32} " " + quoted (a_file))
			create preview.make
			preview.set_ends_with_owner (True)
			preview.start (l_line)
			if attached preview.last_error as al_e then
				status_note := {STRING_32} "could not start ffplay: " + al_e
			else
				status_note := {STRING_32} ""
			end
		end

	run (a_line: STRING_32)
		local
			l_process: SIMPLE_ASYNC_PROCESS
		do
			create l_process.make
			l_process.set_show_window (True)
			l_process.start (a_line)
		end

feature {NONE} -- Implementation

	preview: SIMPLE_ASYNC_PROCESS
	rows: ARRAYED_LIST [TUPLE [x, y, w, h: REAL_64; action, index: INTEGER]]
			-- Clickable rows and buttons from the last `paint'.

	Ink: NATURAL_32 = 0xE6E8EC
	Muted: NATURAL_32 = 0xA9AFBA
	Danger: NATURAL_32 = 0xF87171
	Flag_ink: NATURAL_32 = 0xFBBF24
	Button_fill: NATURAL_32 = 0x3B82F6

	wrapped (p: SW_PAINTER; a_x, a_y, a_w: REAL_64; a_text: READABLE_STRING_32; a_step: REAL_64): REAL_64
			-- Draw `a_text' from (`a_x', `a_y') wrapped to `a_w'; answer the y below it.
		local
			l_y: REAL_64
		do
			l_y := a_y
			across (create {PT_WRAP}).lines (p, a_text, a_w) as ic loop
				p.text (a_x, l_y, ic)
				l_y := l_y + a_step
			end
			Result := l_y
		ensure
			moved_down: Result > a_y
		end

	button (p: SW_PAINTER; a_x, a_y, a_w, a_h: REAL_64; a_label: STRING_32; a_action: INTEGER; k: REAL_64)
		do
			p.set_color (Button_fill)
			p.rrect_fill (a_x, a_y, a_w, a_h, 6 * k)
			p.font (p.Role_ui, 12, True)
			p.set_color (0x0F1115)
			p.text (a_x + 10 * k, a_y + 18 * k, a_label)
			rows.extend ([a_x, a_y, a_w, a_h, a_action, 0])
		end

	cut_text (a_cut: PT_CUT; a_revision: PT_SCRIPT_REVISION): STRING_32
			-- The script words `a_cut' covers.
		local
			l_first, l_last: INTEGER
		do
			l_first := a_revision.index_of (a_cut.first_word)
			l_last := a_revision.index_of (a_cut.last_word)
			if l_first >= 1 and l_last >= l_first then
				Result := a_revision.text_of_range (l_first, l_last)
			else
				create Result.make_empty
			end
		end

	folder_name (a_root: STRING_32): STRING_32
		do
			if attached (create {PATH}.make_from_string (a_root)).entry as al_entry then
				Result := al_entry.name
			else
				Result := a_root
			end
		end

	short (a_text: READABLE_STRING_32; a_max: INTEGER): STRING_32
		do
			if a_text.count <= a_max then
				Result := a_text.to_string_32.twin
			else
				Result := a_text.substring (1, a_max - 3).to_string_32 + {STRING_32} "..."
			end
		end

	clock (a_seconds: REAL_64): STRING_32
			-- m:ss.s
		local
			l_tenths: INTEGER
		do
			l_tenths := (a_seconds * 10).rounded.max (0)
			Result := (l_tenths // 600).out.to_string_32 + {STRING_32} ":"
			if (l_tenths // 10) \\ 60 < 10 then
				Result.append_character ('0')
			end
			Result.append (((l_tenths // 10) \\ 60).out.to_string_32 + {STRING_32} "." + (l_tenths \\ 10).out.to_string_32)
		end

	seconds (a_value: REAL_64): STRING_32
		do
			Result := (create {PT_RENDER_PLAN}.make ({STRING_32} "ffmpeg", 0, False)).seconds (a_value.max (0.0)).to_string_32
		end

	quoted (a_text: READABLE_STRING_32): STRING_32
		do
			Result := {STRING_32} "%"" + a_text + {STRING_32} "%""
		end

	sibling_tool (a_tool, a_name: READABLE_STRING_32): STRING_32
			-- `a_name' in the folder of `a_tool' (ffplay beside ffmpeg), else `a_name' on PATH.
		do
			if attached (create {PATH}.make_from_string (a_tool)).parent as al_dir and then not al_dir.name.is_empty
				and then (create {SIMPLE_FILE}.make (al_dir.extended (a_name).name)).exists then
				Result := al_dir.extended (a_name).name
			else
				Result := a_name.to_string_32
			end
		end

end
