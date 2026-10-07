note
	description: "[
		Analyze one wrapped take from its session folder (plan Step 4b; debate 01: runs
		in the speech worker, on the loaded models). Rebuilds the script history from
		script\r1.md (ids issued after `a_id_base', so they match the journal's) and the
		journal from journal.jsonl, runs PT_SESSION_ANALYZER over the session's tee with
		PT_WHISPER_TRANSCRIBER, and writes analysis\analysis.json (written to a temporary
		file, then renamed) and review.srt.
	]"
	author: "Larry Rix"

class
	PT_ANALYSIS_JOB

create
	make

feature {NONE} -- Initialization

	make (a_transcriber: PT_TRANSCRIBER)
		do
			transcriber := a_transcriber
			create summary.make_empty
		ensure
			transcriber_set: transcriber = a_transcriber
		end

feature -- Access

	transcriber: PT_TRANSCRIBER

	succeeded: BOOLEAN
			-- Did the last `run' produce an analysis?

	summary: STRING_32
			-- One line for the control window: the outcome, or why it failed.

	analysis_path (a_folder: PT_SESSION_FOLDER): STRING_32
			-- Where `run' writes the analysis.
		do
			Result := a_folder.analysis_dir + {STRING_32} "\analysis.json"
		end

feature -- Basic operations

	run (a_root: READABLE_STRING_32; a_id_base: INTEGER_64; a_duration: REAL_64)
			-- Analyze the take in session folder `a_root', `a_duration' seconds long.
		require
			root_present: not a_root.is_empty
			base_non_negative: a_id_base >= 0
			duration_positive: a_duration > 0
		local
			l_folder: PT_SESSION_FOLDER
			l_text: STRING_32
			l_lines: LIST [STRING_8]
			l_parser: PT_SCRIPT_PARSER
			l_ids: PT_ID_SOURCE
			l_history: PT_SCRIPT_HISTORY
			l_journal: PT_JOURNAL
			l_analyzer: PT_SESSION_ANALYZER
			l_duration: REAL_64
			l_ok: BOOLEAN
		do
			succeeded := False
			create l_folder.make (a_root)
			if not (create {SIMPLE_FILE}.make (l_folder.revision_path (1))).exists or not (create {SIMPLE_FILE}.make (l_folder.journal_path)).exists then
				summary := {STRING_32} "analysis skipped: the session's script or journal is missing"
			else
				l_text := utf_8_text (l_folder.revision_path (1))
				create l_ids.make_after (a_id_base)
				create l_parser.make
				l_parser.parse ({STRING_32} "Session script", l_text, 1, l_ids)
				create l_history.make (l_ids, l_parser)
				l_history.start (l_parser.last_revision)
				create l_journal.make_in_memory
				l_lines := byte_text (l_folder.journal_path).split ('%N')
				l_journal.replay_from (non_empty (l_lines))
				l_duration := a_duration.max (l_journal.last_rt)
				create l_analyzer.make (transcriber, create {PT_ATTEMPT_BUILDER}.make,
					create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
					create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
					create {PT_FLAGGER}.make (2.0))
				l_analyzer.analyze (l_folder.tee_path, l_duration, l_journal, l_history)
				l_ok := (create {SIMPLE_FILE}.make (l_folder.review_srt_path)).set_content (
					(create {PT_REVIEW_SRT_WRITER}.make).text (l_journal, l_history))
				if l_analyzer.last_analysis.is_success then
					write_replacing (analysis_path (l_folder), (create {PT_ANALYSIS_CODEC}.make).encode (l_analyzer.last_analysis))
					succeeded := True
					summary := {STRING_32} "analyzed: " + l_analyzer.last_analysis.cuts.count.out + {STRING_32} " cuts, "
						+ l_analyzer.last_analysis.flags.count.out + {STRING_32} " things to check, "
						+ l_analyzer.last_analysis.timeline.count.out + {STRING_32} " words heard"
				elseif attached l_analyzer.last_analysis.error as al_error then
					summary := {STRING_32} "analysis failed: " + al_error
				else
					summary := {STRING_32} "analysis failed"
				end
			end
		ensure
			explained: not summary.is_empty
		end

feature {NONE} -- Implementation

	write_replacing (a_path: STRING_32; a_text: STRING_8)
			-- Write `a_text' to `a_path' through a temporary file and a rename, so a reader never
			-- sees half a file.
		local
			l_tmp: STRING_32
			l_ok: BOOLEAN
		do
			l_tmp := a_path + {STRING_32} ".tmp"
			l_ok := (create {SIMPLE_FILE}.make (l_tmp)).set_content (a_text)
			l_ok := (create {SIMPLE_FILE}.make (a_path)).delete
			l_ok := (create {SIMPLE_FILE}.make (l_tmp)).move_to (a_path)
		end

	byte_text (a_path: READABLE_STRING_32): STRING_8
			-- The bytes of `a_path' as an 8-bit string (UTF-8 JSONL, read as written).
		do
			create Result.make (4096)
			across (create {SIMPLE_FILE}.make (a_path)).binary_content as ic loop
				Result.append_character (ic.to_character_8)
			end
			Result.prune_all ('%R')
		end

	utf_8_text (a_path: READABLE_STRING_32): STRING_32
		do
			Result := (create {SIMPLE_ENCODING}.make).utf_8_to_utf_32 (byte_text (a_path))
			if not Result.is_empty and then Result [1].natural_32_code = 0xFEFF then
				Result.remove_head (1)
			end
		end

	non_empty (a_lines: LIST [STRING_8]): ARRAYED_LIST [STRING_8]
		do
			create Result.make (a_lines.count)
			across a_lines as ic loop
				if not ic.is_empty then
					Result.extend (ic)
				end
			end
		end

end
