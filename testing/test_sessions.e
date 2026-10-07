note
	description: "[
		Step 4a library pieces: a Take Studio session on disk (folders, script copy, journal),
		the recording clock restarting with a new stream, and the raw recording's small clusters
		(spike S-R1: a hard kill lost ~0.7 s without them).
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_SESSIONS

inherit
	PT_TEST_SET

feature -- Tests

	test_session_on_disk
		local
			p: SIMPLE_PROMPTER
			l_folder: PT_SESSION_FOLDER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.load_script_text ({STRING_32} "t", {STRING_32} "One two three. Four five six.")
			p.controller.set_count_in (1.5)
			create l_folder.make (scratch_root)
			p.start_session (l_folder)
			assert_true ("open", p.has_session and p.session.folder = l_folder)
			assert_true ("folders made", (create {DIRECTORY}.make (l_folder.script_dir)).exists and (create {DIRECTORY}.make (l_folder.out_dir)).exists)
			assert_true ("script saved", (create {SIMPLE_FILE}.make (l_folder.revision_path (1))).exists)
			assert_true ("journal on disk", p.controller.journal.is_persistent)
			assert_true ("count-in kept", p.controller.count_in_seconds = 1.5)
			p.perform ({PT_ACTION}.Record)
			p.perform ({PT_ACTION}.Count_in_done)
			p.perform ({PT_ACTION}.Star)
			p.perform ({PT_ACTION}.Wrap)
			p.perform ({PT_ACTION}.Analysis_done)
			assert_true ("journal file written", (create {SIMPLE_FILE}.make (l_folder.journal_path)).exists)
			assert_integers_equal ("wrapped", {PT_TAKE_STATE}.Wrapped, p.controller.state)
			p.end_session
			assert_true ("practice again", not p.has_session and not p.controller.journal.is_persistent)
			assert_integers_equal ("idle", {PT_TAKE_STATE}.Idle, p.controller.state)
			assert_true ("count-in still kept", p.controller.count_in_seconds = 1.5)
		end

	test_recording_clock_restarts
		local
			c: PT_RECORDING_CLOCK
		do
			create c.make
			c.observe_bytes (640_000, 5_000.0)
			assert_true ("ten seconds", (c.rt - 10.0).abs < 1.0e-9)
			c.restart (6_000.0)
			assert_true ("back to zero", c.byte_count = 0 and c.rt = 0.0 and c.observed_at_ms = 6_000.0)
			c.observe_bytes (64_000, 7_000.0)
			assert_true ("counts again", (c.rt - 1.0).abs < 1.0e-9)
		end

	test_raw_recording_has_small_clusters
		local
			l_plan: PT_CAPTURE_PLAN
		do
			create l_plan.make_recording ({STRING_32} "ffmpeg.exe", create {PT_DEVICE_CHOICE}.make_default, {STRING_32} "raw.mkv", {STRING_32} "tee.f32")
			assert_true ("cluster limit", l_plan.has_pair (l_plan.arguments, "-cluster_time_limit", "500"))
			create l_plan.make_audio_only ({STRING_32} "ffmpeg.exe", create {PT_DEVICE_CHOICE}.make_default, {STRING_32} "tee.f32")
			assert_false ("no raw output in practice", l_plan.has_pair (l_plan.arguments, "-cluster_time_limit", "500"))
		end

	test_loader_reads_a_session_back
			-- A session whose ids do not start at 1 (a second script was loaded first) reads back with
			-- the same ids, so the journal's and the analysis's references hold.
		local
			p: SIMPLE_PROMPTER
			l_folder: PT_SESSION_FOLDER
			l_loader: PT_SESSION_LOADER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.load_script_text ({STRING_32} "first", {STRING_32} "An earlier script uses up some ids.")
			p.load_script_text ({STRING_32} "Episode", {STRING_32} "One two three. Four five six.")
			assert_true ("ids do not start at 1", p.history.current_revision.word (1).id.value > 1)
			create l_folder.make (scratch_root)
			p.start_session (l_folder)
			p.perform ({PT_ACTION}.Record)
			p.perform ({PT_ACTION}.Count_in_done)
			p.perform ({PT_ACTION}.Wrap)
			p.perform ({PT_ACTION}.Analysis_done)
			create l_loader.make
			l_loader.load (l_folder.root)
			assert_true ({STRING_32} "loaded: " + l_loader.last_error, l_loader.is_loaded)
			assert_strings_equal ("title kept", "Episode", l_loader.title)
			assert_true ("id base saved", l_loader.id_base = p.history.current_revision.word (1).id.value - 1)
			if attached l_loader.history as al_history and attached l_loader.journal as al_journal then
				assert_integers_equal ("same words", p.history.current_revision.word_count, al_history.current_revision.word_count)
				assert_true ("same first id", al_history.current_revision.word (1).id ~ p.history.current_revision.word (1).id)
				assert_true ("same last id", al_history.current_revision.word (6).id ~ p.history.current_revision.word (6).id)
				assert_integers_equal ("journal read back", p.controller.journal.count, al_journal.count)
			end
			assert_true ("no analysis yet", l_loader.analysis = Void)
			p.end_session
		end

feature {NONE} -- Fixtures

	scratch_root: STRING_32
			-- A fresh session folder under the temp directory.
		local
			l_ok: BOOLEAN
		do
			if attached (create {EXECUTION_ENVIRONMENT}).temporary_directory_path as al_temp then
				Result := al_temp.extended ("simple_prompter_session_test").name
			else
				Result := {STRING_32} "simple_prompter_session_test"
			end
			l_ok := (create {SIMPLE_FILE}.make (Result + {STRING_32} "\journal.jsonl")).delete
		end

end
