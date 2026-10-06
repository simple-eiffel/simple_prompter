note
	description: "[
		The analysis pass (spec F-01 section 6): transcribe the recording, build
		attempts from the journal, align heard words per attempt, choose takes,
		snap cuts into silence, raise flags. Runs in the worker exe; pure logic
		over an injected PT_TRANSCRIBER.
	]"
	author: "Larry Rix"

class
	PT_SESSION_ANALYZER

create
	make

feature {NONE} -- Initialization

	make (a_transcriber: PT_TRANSCRIBER; a_builder: PT_ATTEMPT_BUILDER; a_aligner: PT_ATTEMPT_ALIGNER;
			a_solver: PT_TAKE_SOLVER; a_snapper: PT_SILENCE_SNAPPER; a_flagger: PT_FLAGGER)
		do
			transcriber := a_transcriber
			builder := a_builder
			aligner := a_aligner
			solver := a_solver
			snapper := a_snapper
			flagger := a_flagger
			create last_analysis.make_failed ({STRING_32} "not analyzed")
		ensure
			transcriber_set: transcriber = a_transcriber
			not_yet: not last_analysis.is_success
		end

feature -- Access

	transcriber: PT_TRANSCRIBER
	builder: PT_ATTEMPT_BUILDER
	aligner: PT_ATTEMPT_ALIGNER
	solver: PT_TAKE_SOLVER
	snapper: PT_SILENCE_SNAPPER
	flagger: PT_FLAGGER

	last_analysis: PT_ANALYSIS
			-- Outcome of the last `analyze'.

feature -- Basic operations

	analyze (a_audio_path: READABLE_STRING_32; a_duration: REAL_64; a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY)
			-- Analyze a wrapped session.
		require
			path_present: not a_audio_path.is_empty
			duration_positive: a_duration > 0
			journal_within: a_journal.last_rt <= a_duration
			has_revision: a_history.revision_count >= 1
		local
			l_timeline: PT_WORD_TIMELINE
		do
			transcriber.transcribe (a_audio_path, a_duration)
			if transcriber.is_success and then attached transcriber.last_map as al_map
				and then attached transcriber.last_heard as al_heard then
				builder.build (a_journal, a_history, a_duration)
				aligner.align (builder.last_attempts, a_history, al_heard)
				l_timeline := clipped_to_speech (aligner.last_timeline, al_map)
				solver.solve (a_history, builder.last_attempts, l_timeline)
				snapper.snap (solver.last_result, al_map, l_timeline)
				flagger.flag (snapper.last_result, solver.missing_words, l_timeline, al_map)
				flagger.flag_misreads (aligner.last_misreads, snapper.last_result)
				create last_analysis.make (al_map, l_timeline, builder.last_attempts, snapper.last_result,
					flagger.last_flags, solver.decisions)
			elseif attached transcriber.last_error as al_error and then not al_error.is_empty then
				create last_analysis.make_failed (al_error)
			else
				create last_analysis.make_failed ({STRING_32} "transcription failed")
			end
		ensure
			failure_reported: not transcriber.is_success implies not last_analysis.is_success
			attempts_from_journal: last_analysis.is_success implies
					last_analysis.attempts.count = a_journal.count_of ({PT_EVENT_KIND}.Resume)
			cover_when_complete: (last_analysis.is_success and solver.is_complete) implies
					(last_analysis.cuts.words_model |=| a_history.current_revision.spoken_ids_model)
		end

feature {NONE} -- Implementation

	clipped_to_speech (a_timeline: PT_WORD_TIMELINE; a_map: PT_SPEECH_MAP): PT_WORD_TIMELINE
			-- `a_timeline' with each occurrence clipped to the speech span it overlaps: whisper word
			-- times absorb silences (real-voice evidence: a 3.68 s pause vanished; review M23).
		local
			i, j: INTEGER
			l_occ: PT_WORD_OCCURRENCE
			l_t0, l_t1, l_floor: REAL_64
		do
			create Result.make
			from i := 1 until i > a_timeline.count loop
				l_occ := a_timeline.occurrence (i)
				l_t0 := l_occ.span.t0
				l_t1 := l_occ.span.t1
				from j := 1 until j > a_map.span_count loop
					if a_map.span (j).t0 < l_t1 and l_t0 < a_map.span (j).t1 then
						l_t0 := l_t0.max (a_map.span (j).t0)
						l_t1 := l_t1.min (a_map.span (j).t1)
						j := a_map.span_count
					end
					j := j + 1
				end
				l_t0 := l_t0.max (l_floor)
				l_t1 := l_t1.max (l_t0)
				l_floor := l_t0
				Result.extend (create {PT_WORD_OCCURRENCE}.make (l_occ.word, create {PT_TIME_SPAN}.make (l_t0, l_t1),
					l_occ.confidence, l_occ.attempt))
				i := i + 1
			end
		end

end
