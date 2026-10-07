note
	description: "[
		Analyze one wrapped take from its session folder (plan Step 4b; debate 01: runs
		in the speech worker, on the loaded models). Reads the session back with
		PT_SESSION_LOADER (script ids match the journal's), runs PT_SESSION_ANALYZER over the session's tee with
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
			-- Where `run' writes the analysis (where PT_SESSION_LOADER reads it).
		do
			Result := (create {PT_SESSION_LOADER}.make).analysis_path (a_folder)
		end

feature -- Basic operations

	run (a_root: READABLE_STRING_32; a_duration: REAL_64)
			-- Analyze the take in session folder `a_root', `a_duration' seconds long.
		require
			root_present: not a_root.is_empty
			duration_positive: a_duration > 0
		local
			l_loader: PT_SESSION_LOADER
			l_analyzer: PT_SESSION_ANALYZER
			l_ok: BOOLEAN
		do
			succeeded := False
			create l_loader.make
			l_loader.load (a_root)
			if not l_loader.is_loaded then
				summary := {STRING_32} "analysis skipped: " + l_loader.last_error
			elseif attached l_loader.folder as al_folder and attached l_loader.history as al_history
				and attached l_loader.journal as al_journal then
				create l_analyzer.make (transcriber, create {PT_ATTEMPT_BUILDER}.make,
					create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
					create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
					create {PT_FLAGGER}.make (2.0))
				l_analyzer.analyze (al_folder.tee_path, a_duration.max (al_journal.last_rt), al_journal, al_history)
				l_ok := (create {SIMPLE_FILE}.make (al_folder.review_srt_path)).set_content (
					(create {PT_REVIEW_SRT_WRITER}.make).text (al_journal, al_history))
				if l_analyzer.last_analysis.is_success then
					write_replacing (analysis_path (al_folder), (create {PT_ANALYSIS_CODEC}.make).encode (l_analyzer.last_analysis))
					succeeded := True
					summary := {STRING_32} "analyzed: " + l_analyzer.last_analysis.cuts.count.out + {STRING_32} " cuts, "
						+ l_analyzer.last_analysis.flags.count.out + {STRING_32} " things to check, "
						+ l_analyzer.last_analysis.timeline.count.out + {STRING_32} " words heard"
				elseif attached l_analyzer.last_analysis.error as al_error then
					summary := {STRING_32} "analysis failed: " + al_error
				else
					summary := {STRING_32} "analysis failed"
				end
			else
				summary := {STRING_32} "analysis skipped: the session could not be read"
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

end
