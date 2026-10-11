note
	description: "[
		Headless entry point to simple_prompter: script, following, Take Studio
		and assembly. The GUI app (with its speech worker) is the client; tests drive it
		with a fake clock and a fixed-width measure (simple_speed_reader's
		headless-facade pattern).
	]"
	author: "Larry Rix"

class
	SIMPLE_PROMPTER

create
	make_with_settings

feature {NONE} -- Initialization

	make_with_settings (a_settings: PT_SETTINGS)
			-- Prompter using `a_settings'; no script yet.
		do
			settings := a_settings
			create ids.make
			create parser.make
			create clock_holder.make
			clock := clock_holder
			measure := create {PT_FIXED_MEASURE}.make (10.0, 20.0)
			column_width := a_settings.column_width
			mode := a_settings.default_mode (False)
			speed_wpm := a_settings.speed_wpm
			create matcher
			create layout.make
			create policy
			create recording_clock.make
			create follow_trace.make
			create sound_guard.make
		ensure
			settings_set: settings = a_settings
			no_script: not has_script
			mode_from_settings: mode = a_settings.default_mode (False)
		end

feature -- Configuration (fluent)

	with_mode (a_mode: INTEGER): like Current
			-- Follow mode for the next script load.
		require
			known: a_mode >= {PT_FOLLOW_MODE}.Constant and a_mode <= {PT_FOLLOW_MODE}.Tracking
			no_script_yet: not has_script
		do
			mode := a_mode
			Result := Current
		ensure
			set: mode = a_mode
			chained: Result = Current
		end

	with_speed_wpm (a_wpm: INTEGER): like Current
		require
			range: a_wpm >= 40 and a_wpm <= 400
			no_script_yet: not has_script
		do
			speed_wpm := a_wpm
			Result := Current
		ensure
			set: speed_wpm = a_wpm
			chained: Result = Current
		end

	with_clock (a_clock: PT_CLOCK): like Current
		require
			no_script_yet: not has_script
		do
			clock := a_clock
			Result := Current
		ensure
			set: clock = a_clock
			chained: Result = Current
		end

	with_measure (a_measure: PT_TEXT_MEASURE; a_width: REAL_64): like Current
		require
			width_positive: a_width > 0
			no_script_yet: not has_script
		do
			measure := a_measure
			column_width := a_width.ceiling
			Result := Current
		ensure
			set: measure = a_measure
			chained: Result = Current
		end

feature -- Access

	settings: PT_SETTINGS
	mode: INTEGER
	speed_wpm: INTEGER
	clock: PT_CLOCK
	measure: PT_TEXT_MEASURE
	column_width: INTEGER
	layout: PT_LAYOUT
	recording_clock: PT_RECORDING_CLOCK

	history: PT_SCRIPT_HISTORY
		require
			loaded: has_script
		do
			check attached history_cell as al_h then
				Result := al_h
			end
		end

	follower: PT_FOLLOWER
		require
			loaded: has_script
		do
			check attached follower_cell as al_f then
				Result := al_f
			end
		end

	scroll: PT_SCROLL_MODEL
		require
			loaded: has_script
		do
			check attached scroll_cell as al_s then
				Result := al_s
			end
		end

	controller: PT_TAKE_CONTROLLER
		require
			loaded: has_script
		do
			check attached controller_cell as al_c then
				Result := al_c
			end
		end

	aligner: PT_ALIGNER
		require
			loaded: has_script
		do
			check attached aligner_cell as al_a then
				Result := al_a
			end
		end

	last_error: detachable STRING_32

	Prompt_words: INTEGER = 40
			-- Already-read words given to the decoder.

	prompt_text: STRING_32
			-- The last `Prompt_words' words already read (never upcoming text: spike gotcha 2).
		require
			loaded: has_script
		local
			l_end: INTEGER
		do
			l_end := (controller.reader_position - 1).max (0)
			if l_end >= 1 then
				Result := history.current_revision.text_of_range ((l_end - Prompt_words + 1).max (1), l_end)
			else
				create Result.make_empty
			end
		ensure
			already_read_only: history.current_revision.text_of_range (1, (controller.reader_position - 1).max (0)).ends_with (Result)
		end

feature -- Status

	has_script: BOOLEAN
		do
			Result := attached history_cell
		end

feature -- Script

	open_script (a_path: READABLE_STRING_32)
			-- Load a .txt or .md script.
		require
			path_present: not a_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_bytes: ARRAY [NATURAL_8]
			l_raw: STRING_8
			l_text: STRING_32
			l_encoding: SIMPLE_ENCODING
		do
			create l_file.make (a_path)
			if has_script and then controller.is_recording then
				last_error := {STRING_32} "cannot open a script while recording"
			elseif not l_file.exists then
				last_error := {STRING_32} "script not found: " + a_path
			else
					-- Bytes + SIMPLE_ENCODING: SIMPLE_FILE.content mis-decodes UTF-8 (verified 2026-10-05; Track B fix).
				l_bytes := l_file.binary_content
				create l_raw.make (l_bytes.count)
				across l_bytes as ic loop
					l_raw.append_character (ic.to_character_8)
				end
				create l_encoding.make
				l_text := l_encoding.utf_8_to_utf_32 (l_raw)
				if not l_text.is_empty and then l_text [1].natural_32_code = 0xFEFF then
					l_text.remove_head (1)
				end
				load_script_text (file_title (a_path), l_text)
			end
		ensure
			loaded_or_error: has_script or attached last_error
		end

	load_script_text (a_title, a_text: READABLE_STRING_32)
			-- Load script text as revision 1 and wire follower, layout, scroll, aligner and controller.
		require
			not_recording: not has_script or else not controller.is_recording
		local
			l_history: PT_SCRIPT_HISTORY
			l_follower: PT_FOLLOWER
		do
			parser.parse (a_title, a_text, 1, ids)
			create l_history.make (ids, parser)
			l_history.start (parser.last_revision)
			history_cell := l_history
			l_follower := new_follower (l_history.current_revision.word_count)
			follower_cell := l_follower
			layout.build (l_history.current_revision, measure, column_width)
			create scroll_cell.make (l_follower, layout, create {PT_SPRING}.make (12.0))
			create aligner_cell.make (l_history.current_revision, matcher)
			create controller_cell.make (l_history, create {PT_JOURNAL}.make_in_memory, recording_clock, clock, l_follower, policy)
			last_error := Void
		ensure
			loaded: has_script
			first_revision: history.revision_count = 1
			follower_sized: follower.word_count = history.current_revision.word_count
			idle: controller.state = {PT_TAKE_STATE}.Idle
		end

	set_mode (a_mode: INTEGER)
			-- Follow in `a_mode' from now on. With a script loaded (idle), its current text is
			-- reloaded so a follower of the new mode takes over from the start.
		require
			known: a_mode >= {PT_FOLLOW_MODE}.Constant and a_mode <= {PT_FOLLOW_MODE}.Tracking
			idle: not has_script or else controller.state = {PT_TAKE_STATE}.Idle
		local
			l_title, l_text: STRING_32
		do
			mode := a_mode
			if has_script then
				l_title := history.current_revision.title.twin
				l_text := history.current_revision.source_text.twin
				load_script_text (l_title, l_text)
			end
		ensure
			set: mode = a_mode
			still_loaded: old has_script implies has_script
		end

feature -- Take Studio sessions

	has_session: BOOLEAN
			-- Is a Take Studio session open (so a Record is journaled to disk)?
		do
			Result := attached session_cell
		end

	session: PT_SESSION
			-- The open session.
		require
			open: has_session
		do
			check attached session_cell as al_session then
				Result := al_session
			end
		end

	start_session (a_folder: PT_SESSION_FOLDER)
			-- Open a Take Studio session in `a_folder' (created if absent): the current revision is
			-- saved as its script\r1.md, and the take journal is written to its journal.jsonl. The
			-- controller starts again, idle, on that journal; the count-in is kept.
		require
			loaded: has_script
			idle: controller.state = {PT_TAKE_STATE}.Idle
			no_session: not has_session
		local
			l_journal: PT_JOURNAL
			l_count_in: REAL_64
			l_saved: BOOLEAN
		do
			a_folder.create_directories
			l_saved := (create {SIMPLE_FILE}.make (a_folder.revision_path (1))).set_content (history.current_revision.source_text)
			l_saved := (create {SIMPLE_FILE}.make (a_folder.session_settings_path)).set_content (session_settings_text)
			create l_journal.make_on_file (a_folder.journal_path)
			l_count_in := controller.count_in_seconds
			create controller_cell.make (history, l_journal, recording_clock, clock, follower, policy)
			controller.set_count_in (l_count_in)
			create session_cell.make (a_folder, history, l_journal)
		ensure
			open: has_session
			folder_set: session.folder = a_folder
			journaled: controller.journal = session.journal and controller.journal.is_persistent
			idle: controller.state = {PT_TAKE_STATE}.Idle
			count_in_kept: controller.count_in_seconds = old controller.count_in_seconds
		end

	session_id_base: INTEGER_64
			-- The id just before the current revision's first word: a reader re-parsing the saved
			-- script issues ids after it, and gets the ids the journal refers to.
		require
			loaded: has_script
		do
			if history.current_revision.word_count > 0 then
				Result := history.current_revision.word (1).id.value - 1
			end
		ensure
			non_negative: Result >= 0
		end

	session_settings_text: STRING_32
			-- session.toml: the title and `session_id_base' (PT_SESSION_LOADER reads them).
		require
			loaded: has_script
		local
			l_table, l_root: TOML_TABLE
		do
			create l_table.make
			l_table := l_table.with_string ("title", history.current_revision.title).with_integer ("id_base", session_id_base)
			create l_root.make
			l_root := l_root.with_table ("session", l_table)
			Result := (create {SIMPLE_TOML}).serialize (l_root)
		end

	end_session
			-- Close the session (after Wrap, or before recording): later takes are practice again,
			-- on a fresh in-memory journal; the controller starts again, idle; the count-in is kept.
		require
			open: has_session
			not_recording: not controller.is_recording
		local
			l_count_in: REAL_64
		do
			controller.journal.flush_trace
			l_count_in := controller.count_in_seconds
			session_cell := Void
			create controller_cell.make (history, create {PT_JOURNAL}.make_in_memory, recording_clock, clock, follower, policy)
			controller.set_count_in (l_count_in)
		ensure
			closed: not has_session
			practice: not controller.journal.is_persistent
			idle: controller.state = {PT_TAKE_STATE}.Idle
			count_in_kept: controller.count_in_seconds = old controller.count_in_seconds
		end

feature -- Layout

	set_column_width (a_width: REAL_64)
			-- Lay the script out again at `a_width' pixels (the reader resized the pill). The
			-- reader's place is kept: the follower counts words, not pixels.
		require
			width_positive: a_width > 0
		do
			column_width := a_width.ceiling
			if has_script then
				layout.build (history.current_revision, measure, column_width)
			end
		ensure
			set: column_width = a_width.ceiling
			laid_out: has_script implies layout.word_count = history.current_revision.word_count
		end

feature -- Following

	feed_voice (a_frame: PT_VOICE_FRAME)
			-- A VAD frame: steer the follower; while recording, let the sound guard hear it and
			-- trace the moment it finds the sound garbled.
		require
			loaded: has_script
		local
			l_was: BOOLEAN
		do
			follower.on_voice (a_frame)
			if controller.is_recording then
				l_was := sound_guard.is_garbled
				sound_guard.observe (a_frame)
				if sound_guard.is_garbled and not l_was then
					controller.journal.trace (follow_trace.alarm_line (controller.current_rt, {STRING_32} "garbled_sound",
						sound_guard.loud_seconds))
				end
			end
		end

	sound_guard: PT_SOUND_GUARD
			-- Watches the microphone's sound while recording (0.5.7).

	feed_heard (a_heard: PT_HEARD_WORDS)
			-- Decode result: align, steer the follower, sample into the controller; while recording,
			-- trace the decision into the journal.
		require
			loaded: has_script
		local
			l_from: INTEGER
		do
			l_from := aligner.position
			if visible_last_word > 0 then
				aligner.set_visible (visible_first_word.min (visible_last_word).max (1), visible_last_word)
			else
				aligner.set_visible (0, 0)
			end
			aligner.update (a_heard)
			follower.on_alignment (aligner.last_alignment)
			controller.sample_alignment (aligner.last_alignment)
			if controller.is_recording then
				controller.journal.trace (follow_trace.heard_line (controller.current_rt, a_heard, l_from, aligner, follower))
			end
		end

	visible_last_word: INTEGER
			-- Last script word fully shown on the pill: on a line that ends above the faded band
			-- at the bottom of the text (Larry, 2026-10-11: "slightly greyed-out or half-visible
			-- do NOT count. They are the next words/lines coming into view"). Lines are placed
			-- as PT_PILL_GEOMETRY.line_top places them (reading row on the second line when three
			-- or more lines show) and the band is PT_PILL_RENDERER's bottom fade (0.35 of a
			-- line). Never before the end of the reading row's line; 0 with no layout.
		local
			l_lh, l_reading, l_usable, l_top: REAL_64
			l_line: INTEGER
		do
			if layout.word_count > 0 and layout.line_count > 0 then
				l_lh := layout.line_height
				if settings.lines_visible >= 3 then
					l_reading := l_lh
				end
				l_usable := settings.lines_visible * l_lh - Fade_lines * l_lh
				from l_line := layout.line_count until Result > 0 or l_line < 1 loop
					l_top := l_reading + l_lh / 2 + layout.line (l_line).y - scroll.y_offset.max (l_lh / 2)
					if l_top + l_lh <= l_usable then
						Result := layout.line (l_line).last_word
					end
					l_line := l_line - 1
				end
				Result := Result.max (layout.line (layout.line_of ((scroll.position.floor + 1).min (layout.word_count).max (1))).last_word)
					.min (history.current_revision.word_count)
			end
		ensure
			in_script: Result >= 0 and Result <= history.current_revision.word_count
		end

	Fade_lines: REAL_64 = 0.35
			-- Height of the pill's bottom fade, in lines (PT_PILL_RENDERER).

	visible_first_word: INTEGER
			-- First script word on a line wholly inside the pill's text area (the line above the
			-- reading row counts: the reader may be there when the text ran ahead); never after
			-- the start of the reading row's line; 0 with no layout.
		local
			l_lh, l_reading, l_top: REAL_64
			l_line: INTEGER
		do
			if layout.word_count > 0 and layout.line_count > 0 then
				l_lh := layout.line_height
				if settings.lines_visible >= 3 then
					l_reading := l_lh
				end
				from l_line := 1 until Result > 0 or l_line > layout.line_count loop
					l_top := l_reading + l_lh / 2 + layout.line (l_line).y - scroll.y_offset.max (l_lh / 2)
					if l_top >= -0.5 then
						Result := layout.line (l_line).first_word
					end
					l_line := l_line + 1
				end
				Result := Result.max (1).min (layout.line (layout.line_of ((scroll.position.floor + 1).min (layout.word_count).max (1))).first_word)
					.min (history.current_revision.word_count)
			end
		ensure
			in_script: Result >= 0 and Result <= history.current_revision.word_count
		end

	Wheel_notch: INTEGER = 120
			-- Windows' wheel delta for one notch.

	wheel_rest: INTEGER
			-- Part of a notch turned but not yet acted on (touchpads send fractions).

	wheel (a_delta: INTEGER)
			-- The mouse wheel turned by `a_delta' over the pill while reading (Larry, 2026-10-11):
			-- a line on for each notch down, a line back for each notch up (touchpad fractions add
			-- up), and a "wheel" trace line for every turn, moving or not.
		require
			loaded: has_script
			reading: controller.state = {PT_TAKE_STATE}.Reading
		local
			l_total, l_lines, l_from, i: INTEGER
		do
			l_from := aligner.position
			l_total := wheel_rest + a_delta
			l_lines := l_total.abs // Wheel_notch
			if l_total < 0 then
				l_lines := -l_lines
			end
			wheel_rest := l_total - l_lines * Wheel_notch
			from i := 1 until i > l_lines.abs loop
				if l_lines < 0 then
					nudge_forward
				else
					nudge_back
				end
				i := i + 1
			end
			if controller.is_recording then
				controller.journal.trace (follow_trace.wheel_line (controller.current_rt, a_delta, -l_lines, wheel_rest,
					{STRING_32} "reading", l_from, aligner.position))
			end
		ensure
			rest_below_a_notch: wheel_rest.abs < Wheel_notch
		end

	note_wheel (a_delta: INTEGER; a_state: READABLE_STRING_32; a_from, a_to: INTEGER)
			-- Trace a wheel turn of `a_delta' that did not nudge (held, idle, ...), the place
			-- going from `a_from' to `a_to'.
		require
			loaded: has_script
		do
			if controller.is_recording then
				controller.journal.trace (follow_trace.wheel_line (controller.current_rt, a_delta, 0, 0, a_state, a_from, a_to))
			end
		end

	nudge_back
			-- The text ran ahead of the reader (Larry, 2026-10-11: "i also need to be able to
			-- scroll up if the software scrolls down too far before I am done reading"): put the
			-- text and the aligner on the line before the reading row, and follow on from there.
		require
			loaded: has_script
			reading: controller.state = {PT_TAKE_STATE}.Reading
		local
			l_from, l_to, l_line: INTEGER
		do
			l_from := aligner.position
			if layout.word_count > 0 then
				l_line := layout.line_of ((follower.target.floor + 1).min (layout.word_count).max (1))
				if l_line > 1 then
					l_to := layout.line (l_line - 1).first_word - 1
				end
			end
			l_to := l_to.max (0).min (history.current_revision.word_count)
			aligner.reanchor (l_to, recording_clock.sample_count)
			follower.set_caret (l_to)
			if controller.is_recording then
				controller.journal.trace (follow_trace.nudge_line (controller.current_rt, l_from, l_to))
			end
		ensure
			follower_placed: follower.target = aligner.position.to_double
		end

	nudge_forward
			-- The reader is ahead of the text (Larry, 2026-10-11: "allow me to force the scroll
			-- forward so I can read the text and force the pointer in the software to where I am
			-- reading"): put the text and the aligner on the line after the reading row, without
			-- stopping, and follow on from there.
		require
			loaded: has_script
			reading: controller.state = {PT_TAKE_STATE}.Reading
		local
			l_from, l_to, l_line: INTEGER
		do
			l_from := aligner.position
			if layout.word_count > 0 then
					-- From where the text is heading, so that quick presses each move a line.
				l_line := layout.line_of ((scroll.position.max (follower.target).floor + 1).min (layout.word_count).max (1))
				if l_line < layout.line_count then
					l_to := layout.line (l_line + 1).first_word - 1
				else
					l_to := layout.word_count
				end
			end
			l_to := l_to.max (l_from).max (follower.target.floor).min (history.current_revision.word_count)
			aligner.reanchor (l_to, recording_clock.sample_count)
			follower.set_caret (l_to)
			if controller.is_recording then
				controller.journal.trace (follow_trace.nudge_line (controller.current_rt, l_from, l_to))
			end
		ensure
			never_backward: aligner.position >= old aligner.position
			follower_placed: follower.target = aligner.position.to_double
		end

	tick (a_now_ms: REAL_64)
		require
			loaded: has_script
			not_backward: scroll.is_started implies a_now_ms >= scroll.last_ms
		do
			scroll.tick (a_now_ms)
			trace_frame
		ensure
			ticked: scroll.last_ms = a_now_ms
		end

feature -- Take Studio

	perform (a_action: INTEGER)
			-- Take Studio action; rewires after a revision (Skip) and reanchors the aligner on resume.
		require
			loaded: has_script
			known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
			no_argument: not controller.needs_argument (a_action)
			allowed: controller.is_allowed (a_action)
		local
			l_revisions: INTEGER
		do
			l_revisions := history.revision_count
			controller.perform (a_action)
			if history.revision_count /= l_revisions then
				rewire
			end
			if a_action = {PT_ACTION}.Record then
				sound_guard.reset
			end
			if a_action = {PT_ACTION}.Count_in_done then
				aligner.reanchor ((controller.caret - 1).max (0), recording_clock.sample_count)
			end
		ensure
			reanchored_on_resume: a_action = {PT_ACTION}.Count_in_done implies
				(aligner.position = (controller.caret - 1).max (0) and aligner.reanchored_at = recording_clock.sample_count)
		end

	commit_edit (a_new_text: READABLE_STRING_32)
			-- Live edit through the facade, so aligner, layout and follower follow the new revision (review H4).
		require
			loaded: has_script
			editing: controller.state = {PT_TAKE_STATE}.Editing
		do
			controller.commit_edit (a_new_text)
			rewire
		ensure
			follows_revision: aligner.revision = history.current_revision
		end

feature {NONE} -- Implementation

	ids: PT_ID_SOURCE
	parser: PT_SCRIPT_PARSER
	matcher: PT_WORD_MATCHER
	policy: PT_RESTART_POLICY
	clock_holder: PT_FAKE_CLOCK
			-- Default clock until `with_clock'.

	history_cell: detachable PT_SCRIPT_HISTORY
	follower_cell: detachable PT_FOLLOWER
	scroll_cell: detachable PT_SCROLL_MODEL
	controller_cell: detachable PT_TAKE_CONTROLLER
	aligner_cell: detachable PT_ALIGNER

	session_cell: detachable PT_SESSION
			-- The open Take Studio session, if any.

	follow_trace: PT_FOLLOW_TRACE
			-- Formats the follow trace written into the journal while recording.

	trace_frame
			-- While recording, trace the display (when due) and write buffered trace lines once a
			-- second; after recording, write what is left.
		require
			loaded: has_script
		local
			l_rt: REAL_64
			l_line, l_target_line: INTEGER
			l_snapped: BOOLEAN
		do
			if controller.is_recording then
				l_rt := controller.current_rt
				if layout.word_count > 0 then
					l_line := layout.line_of ((scroll.position.floor + 1).min (layout.word_count).max (1))
					l_target_line := layout.line_of ((follower.target.floor + 1).min (layout.word_count).max (1))
				end
				if attached {PT_TRACKING_FOLLOWER} follower as al_tracking then
					l_snapped := al_tracking.last_snapped
				end
				if follow_trace.wants_frame (l_rt, l_line, l_snapped) then
					controller.journal.trace (follow_trace.frame_line (l_rt, follower, scroll, l_line, l_target_line))
					follow_trace.note_frame (l_rt, l_line)
				end
				if follow_trace.wants_flush (l_rt) then
					controller.journal.flush_trace
					follow_trace.note_flush (l_rt)
				end
			elseif controller.journal.has_trace_pending then
				controller.journal.flush_trace
			end
		end

	rewire
			-- Follow the current revision: new aligner, rebuilt layout, rescaled follower.
		require
			loaded: has_script
		do
			follower.rescale (history.current_revision.word_count)
			layout.build (history.current_revision, measure, column_width)
			create aligner_cell.make (history.current_revision, matcher)
		ensure
			aligner_current: aligner.revision = history.current_revision
			layout_current: layout.word_count = history.current_revision.word_count
			follower_current: follower.word_count = history.current_revision.word_count
		end

	file_title (a_path: READABLE_STRING_32): STRING_32
			-- File name of `a_path' without directories or extension.
		local
			l_cut: INTEGER
		do
			create Result.make_from_string (a_path)
			l_cut := Result.last_index_of ('\', Result.count).max (Result.last_index_of ('/', Result.count))
			if l_cut > 0 then
				Result := Result.substring (l_cut + 1, Result.count)
			end
			l_cut := Result.last_index_of ('.', Result.count)
			if l_cut > 1 then
				Result := Result.substring (1, l_cut - 1)
			end
			if Result.is_empty then
				Result := {STRING_32} "script"
			end
		end

	new_follower (a_word_count: INTEGER): PT_FOLLOWER
			-- Follower for `mode'.
		require
			non_negative: a_word_count >= 0
		do
			inspect mode
			when {PT_FOLLOW_MODE}.Constant then
				create {PT_CONSTANT_FOLLOWER} Result.make (a_word_count, speed_wpm)
			when {PT_FOLLOW_MODE}.Tracking then
				create {PT_TRACKING_FOLLOWER} Result.make (a_word_count, speed_wpm)
			else
				create {PT_VOICE_GATED_FOLLOWER} Result.make (a_word_count, speed_wpm)
			end
		ensure
			sized: Result.word_count = a_word_count
		end

invariant
	mode_known: mode >= {PT_FOLLOW_MODE}.Constant and mode <= {PT_FOLLOW_MODE}.Tracking
	speed_range: speed_wpm >= 40 and speed_wpm <= 400
	width_positive: column_width > 0
	loaded_consistently: has_script implies (attached follower_cell and attached controller_cell and attached scroll_cell and attached aligner_cell)
	follows_current_revision: (attached history_cell as al_h and attached aligner_cell as al_a and attached follower_cell as al_f) implies
		(al_a.revision = al_h.current_revision and layout.word_count = al_h.current_revision.word_count and al_f.word_count = layout.word_count)

end
