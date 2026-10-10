note
	description: "[
		The minimal Edit Floor (plan Step 4c; F-01 section 8, the approved minimal editor):
		a "Last take" panel in the control window. It shows the take's numbers, its cuts
		(times and the script words each covers) and its flags (things to check); a
		click previews a cut or a flag in ffplay (F-01 8.3 v1: -ss / -t on the raw file),
		and the buttons render final.mp4 with captions and chapters, play it, or open the
		session folder. The take is read back from its folder (PT_SESSION_LOADER).
		Sync (0.3.6): the take's picture-to-sound sync (PT_TAKE_SYNC), nudged in 10 ms
		steps, previewed, or measured from claps (PT_SYNC_MEASURER); previews and the
		render use it, and each change becomes the starting value for the next take.
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
			create measurer.make (a_ffmpeg)
			create sync_note.make_empty
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

	sync: detachable PT_TAKE_SYNC
			-- The shown take's sync.

	measurer: PT_SYNC_MEASURER

	sync_note: STRING_32
			-- What Measure found (empty until it runs on this take).

	sync_preview_from: REAL_64
			-- Where Preview sync starts: just before the first clap measured, else the first cut.

	on_sync_changed: detachable PROCEDURE [INTEGER]
			-- Told each new sync value (the app keeps it as the next take's starting value).

	set_on_sync_changed (a_action: PROCEDURE [INTEGER])
		do
			on_sync_changed := a_action
		ensure
			set: on_sync_changed = a_action
		end

	on_publish: detachable PROCEDURE
			-- Told when Publish is clicked (the app asks the speech worker, 0.5.0).

	set_on_publish (a_action: PROCEDURE)
		do
			on_publish := a_action
		ensure
			set: on_publish = a_action
		end

	publish_status: STRING_32
			-- What Publish is doing, or did.
		attribute
			create Result.make_empty
		end

	is_publishing: BOOLEAN

	set_publish_status (a_text: READABLE_STRING_32; a_busy: BOOLEAN)
		do
			publish_status := a_text.to_string_32.twin
			is_publishing := a_busy
		ensure
			busy_set: is_publishing = a_busy
		end

	take_root: detachable STRING_32
			-- The shown take's session folder.
		do
			if attached take as al_take and then attached al_take.folder as al_folder then
				Result := al_folder.root.twin
			end
		end

	bottom: REAL_64
			-- Where the last `paint' ended (its height, from its top).

	clickables: ARRAYED_LIST [TUPLE [x, y, w, h: REAL_64; action, index: INTEGER]]
			-- What the last `paint' made clickable (for tooltips; `press' acts on them).
		do
			Result := rows
		end

	row_tip (a_action, a_index: INTEGER): STRING_32
			-- What clicking a row or button does.
		do
			inspect a_action
			when Action_render then
				Result := {STRING_32} "Render final.mp4 with captions and chapters, using this take's sync"
			when Action_publish then
				Result := {STRING_32} "Publish: finish final.mp4 (opens on the thumbnail in out, fades to black, YouTube loudness), captions as spoken (captions.en_US.SRT), chapters, youtube.txt, facebook.txt, x.txt"
			when Action_play_final then
				Result := {STRING_32} "Play final.mp4"
			when Action_open_folder then
				Result := {STRING_32} "Open this take's folder"
			when Action_preview_cut then
				Result := {STRING_32} "Preview cut " + a_index.out + {STRING_32} " (with the sync)"
			when Action_preview_flag then
				Result := {STRING_32} "Preview around this, two seconds either side"
			when Action_sync_down then
				Result := {STRING_32} "Picture 10 ms later against the sound"
			when Action_sync_up then
				Result := {STRING_32} "Picture 10 ms earlier against the sound"
			when Action_sync_preview then
				Result := {STRING_32} "Watch a few seconds with this sync (at your clap, once measured)"
			when Action_measure then
				Result := {STRING_32} "Find the sync from claps: clap 2 or 3 times, hands in the picture"
			else
				Result := {STRING_32} ""
			end
		end

	has_take: BOOLEAN
		do
			Result := attached take as al_take and then al_take.is_loaded and then attached al_take.analysis
		end

feature -- Commands

	show (a_root: READABLE_STRING_32; a_start_sync_ms: INTEGER)
			-- Read the take in session folder `a_root' (after its analysis) and show it; its sync
			-- starts at `a_start_sync_ms' unless the take already has its own.
		require
			root_present: not a_root.is_empty
			sync_in_range: a_start_sync_ms >= {PT_TAKE_SYNC}.Min_ms and a_start_sync_ms <= {PT_TAKE_SYNC}.Max_ms
		local
			l_loader: PT_SESSION_LOADER
		do
			create l_loader.make
			l_loader.load (a_root)
			take := l_loader
			sync := Void
			sync_note := {STRING_32} ""
			sync_preview_from := -1.0
			if l_loader.is_loaded and then attached l_loader.folder as al_folder then
				sync := create {PT_TAKE_SYNC}.make (al_folder.root + {STRING_32} "\sync.toml", a_start_sync_ms)
			end
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
				button (p, a_x + 312 * k, l_y - 18 * k, 96 * k, 26 * k, (if is_publishing then {STRING_32} "Publishing" else {STRING_32} "Publish" end), Action_publish, k)
				l_y := l_y + 24 * k
				if attached sync as al_sync then
					p.font (p.Role_ui, 12, True)
					p.set_color (Ink)
					p.text (a_x, l_y + 8 * k, {STRING_32} "Sync")
					button (p, a_x + 42 * k, l_y - 10 * k, 26 * k, 26 * k, {STRING_32} "-", Action_sync_down, k)
					p.font (p.Role_ui, 12, True)
					p.set_color (Ink)
					p.text (a_x + 76 * k, l_y + 8 * k, al_sync.text)
					button (p, a_x + 140 * k, l_y - 10 * k, 26 * k, 26 * k, {STRING_32} "+", Action_sync_up, k)
					button (p, a_x + 176 * k, l_y - 10 * k, 108 * k, 26 * k, {STRING_32} "Preview sync", Action_sync_preview, k)
					button (p, a_x + 292 * k, l_y - 10 * k, 80 * k, 26 * k, {STRING_32} "Measure", Action_measure, k)
					l_y := l_y + 38 * k
					p.font (p.Role_ui, 12, False)
					p.set_color (Muted)
					l_y := wrapped (p, a_x, l_y, a_w, sync_text (al_sync), 20 * k)
				end
				p.font (p.Role_ui, 12, False)
				p.set_color (Muted)
				if not renderer.status.is_empty then
					l_y := wrapped (p, a_x, l_y, a_w, renderer.status, 20 * k)
				end
				if not publish_status.is_empty then
					l_y := wrapped (p, a_x, l_y, a_w, publish_status, 20 * k)
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
			bottom := l_y + 12 * k
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
	Action_sync_down: INTEGER = 6
	Action_sync_up: INTEGER = 7
	Action_sync_preview: INTEGER = 8
	Action_measure: INTEGER = 9
	Action_publish: INTEGER = 10

	act (a_action, a_index: INTEGER)
		do
			if attached take as al_take and then attached al_take.folder as al_folder and then attached al_take.analysis as al_analysis
				and then attached al_take.history as al_history and then attached al_take.journal as al_journal then
				inspect a_action
				when Action_render then
					if not renderer.is_rendering then
						renderer.start (al_folder, al_history.current_revision, al_analysis, al_journal, sync_ms)
						status_note := {STRING_32} ""
					end
				when Action_publish then
					if is_publishing or renderer.is_rendering then
						status_note := {STRING_32} "wait: " + (if is_publishing then {STRING_32} "publishing" else {STRING_32} "rendering" end)
					elseif (create {SIMPLE_FILE}.make (al_folder.out_dir + {STRING_32} "\final.mp4")).exists
						or (create {SIMPLE_FILE}.make (al_folder.out_dir + {STRING_32} "\final (before cleanup).mp4")).exists then
						status_note := {STRING_32} ""
						if attached on_publish as al_action then
							al_action.call (Void)
						end
					else
						status_note := {STRING_32} "render first: there is no final.mp4 yet"
					end
				when Action_play_final then
					if (create {SIMPLE_FILE}.make (al_folder.out_dir + {STRING_32} "\final.mp4")).exists then
						play (al_folder.out_dir + {STRING_32} "\final.mp4", 0.0, 0.0, {STRING_32} "final", 0)
					else
						status_note := {STRING_32} "render first: there is no final.mp4 yet"
					end
				when Action_open_folder then
					run ({STRING_32} "explorer.exe " + quoted (al_folder.root))
				when Action_preview_cut then
					if a_index >= 1 and a_index <= al_analysis.cuts.count then
						play (al_folder.raw_path, al_analysis.cuts.cut (a_index).span.t0, al_analysis.cuts.cut (a_index).span.duration,
							{STRING_32} "cut " + a_index.out, sync_ms)
					end
				when Action_preview_flag then
					if a_index >= 1 and a_index <= al_analysis.flags.count then
						play (al_folder.raw_path, (al_analysis.flags [a_index].span.t0 - 2.0).max (0.0),
							al_analysis.flags [a_index].span.duration + 4.0, {STRING_32} "check " + a_index.out, sync_ms)
					end
				when Action_sync_down, Action_sync_up then
					if attached sync as al_sync then
						al_sync.step (if a_action = Action_sync_down then -1 else 1 end)
						sync_note := {STRING_32} ""
						tell_sync (al_sync.delay_ms)
					end
				when Action_sync_preview then
					if sync_preview_from >= 0 then
						play (al_folder.raw_path, sync_preview_from, 5.0, {STRING_32} "sync " + sync_ms.out + {STRING_32} " ms", sync_ms)
					elseif al_analysis.cuts.count >= 1 then
						play (al_folder.raw_path, al_analysis.cuts.cut (1).span.t0, 8.0, {STRING_32} "sync " + sync_ms.out + {STRING_32} " ms", sync_ms)
					end
				when Action_measure then
					measurer.run (al_folder.raw_path, al_folder.tee_path, al_folder.out_dir)
					sync_note := measurer.summary.twin
					if measurer.measure.is_found and attached sync as al_sync then
						al_sync.set_measured (measurer.measure.delay_ms.max ({PT_TAKE_SYNC}.Min_ms).min ({PT_TAKE_SYNC}.Max_ms))
						if not measurer.measure.claps.is_empty then
							sync_preview_from := (measurer.measure.claps.first - 1.0).max (0.0)
						end
						tell_sync (al_sync.delay_ms)
					end
				else
				end
			end
		end

	play (a_file: STRING_32; a_from, a_seconds: REAL_64; a_title: STRING_32; a_sync_ms: INTEGER)
			-- Preview `a_seconds' of `a_file' from `a_from' in ffplay (0 seconds: to the end), the
			-- picture moved `a_sync_ms' earlier (ffplay keeps the picture on the sound's clock).
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
			if a_sync_ms /= 0 then
				l_line.append ({STRING_32} " -vf " + quoted ({STRING_32} "setpts=PTS-("
					+ (create {PT_RENDER_PLAN}.make ({STRING_32} "ffmpeg", 0, False)).signed_seconds (a_sync_ms).to_string_32 + {STRING_32} ")/TB"))
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

feature {NONE} -- Sync

	sync_ms: INTEGER
			-- The shown take's sync (0 without a take).
		do
			if attached sync as al_sync then
				Result := al_sync.delay_ms
			end
		end

	sync_text (a_sync: PT_TAKE_SYNC): STRING_32
			-- What the sync does, or what Measure found.
		do
			if not sync_note.is_empty then
				Result := sync_note.twin
			elseif a_sync.delay_ms > 0 then
				Result := {STRING_32} "previews and the render move the picture " + a_sync.text + {STRING_32} " earlier"
			elseif a_sync.delay_ms < 0 then
				Result := {STRING_32} "previews and the render move the picture " + a_sync.delay_ms.abs.out + {STRING_32} " ms later"
			else
				Result := {STRING_32} "picture and sound as recorded"
			end
			if a_sync.is_measured and sync_note.is_empty then
				Result.append ({STRING_32} " (measured)")
			end
		end

	tell_sync (a_ms: INTEGER)
			-- Hand `a_ms' to `on_sync_changed'.
		do
			if attached on_sync_changed as al_action then
				al_action.call ([a_ms])
			end
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
