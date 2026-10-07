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

	end_session
			-- Close the session (after Wrap, or before recording): later takes are practice again,
			-- on a fresh in-memory journal; the controller starts again, idle; the count-in is kept.
		require
			open: has_session
			not_recording: not controller.is_recording
		local
			l_count_in: REAL_64
		do
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
		require
			loaded: has_script
		do
			follower.on_voice (a_frame)
		end

	feed_heard (a_heard: PT_HEARD_WORDS)
			-- Decode result: align, steer the follower, sample into the controller.
		require
			loaded: has_script
		do
			aligner.update (a_heard)
			follower.on_alignment (aligner.last_alignment)
			controller.sample_alignment (aligner.last_alignment)
		end

	tick (a_now_ms: REAL_64)
		require
			loaded: has_script
			not_backward: scroll.is_started implies a_now_ms >= scroll.last_ms
		do
			scroll.tick (a_now_ms)
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
