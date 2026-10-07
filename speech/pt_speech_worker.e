note
	description: "[
		Live speech on its own processor (approved intent Q9). Loads Silero and
		whisper (GPU) here, so the window never waits on them; when the window asks,
		starts ffmpeg capturing the microphone into the 16 kHz float tee file, tails
		that file into PT_SPEECH_PIPELINE, and deposits the voice frames and heard
		words in the slot as codec records. When the window asks for a recording
		(plan Step 4a), the same one ffmpeg is restarted on camera + microphone with
		PT_CAPTURE_PLAN.make_recording (raw MKV + the session's tee), following goes
		on from that tee, and on finish it records `Tail_ms' more, stops, keeps the
		session tee for analysis, and goes back to listening. Every capture is a new
		stream: a fresh pipeline, so its sample clock is the recording's own. ffmpeg's merged stdout/stderr pipe is
		drained every turn (a full pipe would stall ffmpeg and the tee file with it).

		The window calls this object exactly once, asynchronously (`attach_slot' then
		`run'); after that it talks only to the slot. However `run' ends, the slot is
		told: a failure through its state, and every exit through `put_stopped'.
	]"
	author: "Larry Rix"

class
	PT_SPEECH_WORKER

create
	make

feature {NONE} -- Initialization

	make (a_ffmpeg, a_camera, a_microphone, a_tee_path, a_model, a_vad_model: separate READABLE_STRING_32)
		do
			create ffmpeg.make_from_separate (a_ffmpeg)
			create camera.make_from_separate (a_camera)
			create microphone.make_from_separate (a_microphone)
			create current_tee.make_empty
			create tee_path.make_from_separate (a_tee_path)
			create model_path.make_from_separate (a_model)
			create vad_model_path.make_from_separate (a_vad_model)
			create codec.make
			create outgoing.make (4096)
			create buffer.make_filled (0.0, Chunk_samples)
			create tail.make (tee_path)
			create process.make
		ensure
			idle: not is_running and not is_listening
		end

feature -- Constants

	Chunk_samples: INTEGER = 4096
			-- Most samples pushed per turn (256 ms; at most one decode).

	Idle_sleep_ms: INTEGER = 10
	Exit_wait_ms: INTEGER = 3000
			-- Longest wait for a killed ffmpeg to exit.
	Tail_ms: REAL_64 = 1000.0
			-- Recording kept after a finish request: covers the tail pad and the last MKV cluster
			-- a hard stop can lose (spike S-R1).
	Start_timeout_ms: REAL_64 = 8000.0
			-- How long ffmpeg may take to produce the tee file.

feature -- Access

	ffmpeg, camera, microphone, tee_path, model_path, vad_model_path: STRING_32
	slot: detachable separate PT_SPEECH_SLOT

feature -- Status

	is_running: BOOLEAN
	is_listening: BOOLEAN
			-- Is a capture (listening or recording) running?

	is_recording: BOOLEAN
			-- Is the running capture a recording?

	load_seconds: INTEGER
			-- How long loading and warming the models took.

feature -- Element change

	attach_slot (a_slot: separate PT_SPEECH_SLOT)
		require
			not_running: not is_running
		do
			slot := a_slot
		ensure
			attached_slot: slot = a_slot
		end

feature -- Execution

	run
			-- Load, then listen when asked, until the slot asks to stop.
		require
			has_slot: attached slot
			not_running: not is_running
		local
			l_vad: detachable PT_SILERO_VAD
			l_decoder: detachable PT_WHISPER_DECODER
			l_got: INTEGER
			l_start: REAL_64
			l_failed: BOOLEAN
		do
			if attached slot as al_slot then
				if not l_failed then
					is_running := True
					l_start := now_ms
					create l_vad.make (vad_model_path)
					create l_decoder.make (model_path)
					if not l_vad.is_loaded then
						report (al_slot, {PT_SPEECH_SLOT}.Failed, l_vad.detector.last_error)
					elseif not l_decoder.is_loaded then
						report (al_slot, {PT_SPEECH_SLOT}.Failed, l_decoder.recognizer.last_error)
					else
						l_decoder.warm_up
						load_seconds := ((now_ms - l_start) / 1000).rounded
						report (al_slot, {PT_SPEECH_SLOT}.Ready, {STRING_32} "speech ready (" + load_seconds.out + " s to load)")
						vad := l_vad
						decoder := l_decoder
						create analysis_job.make (create {PT_WHISPER_TRANSCRIBER}.make (l_vad.detector, l_decoder.recognizer))
						from
						until
							stop_wanted (al_slot) or failed
						loop
							if is_recording and finish_at = 0.0 and then finish_wanted (al_slot) then
								finish_at := now_ms + Tail_ms
							end
							if is_recording and finish_at > 0.0 and then now_ms >= finish_at then
								finish_recording (al_slot)
							end
							if not is_recording and then record_wanted (al_slot) then
								start_recording (al_slot)
							elseif not is_recording and then analysis_wanted (al_slot) then
								run_analysis (al_slot)
							elseif not is_listening and then listen_wanted (al_slot) then
								start_listening (al_slot)
							end
							l_got := 0
							if is_listening and then attached pipeline as al_pipeline then
								l_got := pump (al_slot, al_pipeline)
							end
							if l_got < Chunk_samples then
								(create {EXECUTION_ENVIRONMENT}).sleep (Idle_sleep_ms.to_integer_64 * 1_000_000)
							end
						end
					end
				end
				stop_listening
				if attached l_decoder as al_d then
					al_d.recognizer.close
				end
				if attached l_vad as al_v then
					al_v.detector.close
				end
				report_stopped (al_slot)
				is_running := False
			end
		ensure
			stopped: not is_running and not is_listening
		rescue
			l_failed := True
			if attached slot as al_slot then
				report (al_slot, {PT_SPEECH_SLOT}.Failed, {STRING_32} "speech stopped: " + exception_text)
			end
			retry
		end

feature {NONE} -- Listening

	process: SIMPLE_ASYNC_PROCESS
	tail: PT_TAIL_SOURCE
	buffer: SPECIAL [REAL_32]
	codec: PT_SPEECH_CODEC
	outgoing: STRING_8
	listen_started_ms: REAL_64
	prompt_serial_seen: INTEGER
	failed: BOOLEAN

	vad: detachable PT_SILERO_VAD
	decoder: detachable PT_WHISPER_DECODER
	pipeline: detachable PT_SPEECH_PIPELINE
			-- The current stream's pipeline (a new one per capture).

	stream: INTEGER
			-- The current capture's number (see PT_SPEECH_SLOT.stream).

	analysis_job: detachable PT_ANALYSIS_JOB
			-- Analyzes wrapped takes on the loaded models (debate 01).

	current_tee: STRING_32
			-- The tee file of the running capture.

	finish_at: REAL_64
			-- When the recording stops (0: no finish requested yet).

	start_listening (a_slot: separate PT_SPEECH_SLOT)
			-- Start ffmpeg on the microphone, writing the tee file.
		require
			not_listening: not is_listening
		local
			l_ok: BOOLEAN
		do
			l_ok := (create {SIMPLE_FILE}.make (tee_path)).delete
			start_capture (a_slot, create {PT_CAPTURE_PLAN}.make_audio_only (ffmpeg, create {PT_DEVICE_CHOICE}.make ({STRING_32} "", microphone, 1, 1, 1), tee_path),
				tee_path, {PT_SPEECH_SLOT}.Listening, {STRING_32} "listening: " + microphone + {STRING_32} " (speech loaded in " + load_seconds.out + {STRING_32} " s)")
		ensure
			not_recording: not is_recording
		end

	start_recording (a_slot: separate PT_SPEECH_SLOT)
			-- Stop listening; record camera + microphone into the requested raw file and tee.
		require
			not_recording: not is_recording
		local
			l_raw, l_tee: STRING_32
		do
			stop_listening
			l_raw := requested_raw (a_slot)
			l_tee := requested_tee (a_slot)
			start_capture (a_slot, create {PT_CAPTURE_PLAN}.make_recording (ffmpeg, create {PT_DEVICE_CHOICE}.make (camera, microphone, 1920, 1080, 30), l_raw, l_tee),
				l_tee, {PT_SPEECH_SLOT}.Recording, {STRING_32} "RECORDING: " + camera + {STRING_32} " + " + microphone)
			if is_listening then
				is_recording := True
				finish_at := 0.0
			end
		end

	run_analysis (a_slot: separate PT_SPEECH_SLOT)
			-- Analyze the requested take (blocking this processor for seconds, holding no slot),
			-- report it, and listen again on a fresh stream (the audio heard meanwhile is stale).
		require
			not_recording: not is_recording
		local
			l_root: STRING_32
		do
			report (a_slot, {PT_SPEECH_SLOT}.Analyzing, {STRING_32} "analyzing the take")
			l_root := requested_analysis_root (a_slot)
			if attached analysis_job as al_job then
				al_job.run (l_root, requested_id_base (a_slot), requested_duration (a_slot))
				report_analysis (a_slot, al_job.succeeded, al_job.summary)
			else
				report_analysis (a_slot, False, {STRING_32} "analysis unavailable: the speech models are not loaded")
			end
			if is_listening then
				stop_listening
			end
			if listen_wanted (a_slot) then
				start_listening (a_slot)
			end
		end

	finish_recording (a_slot: separate PT_SPEECH_SLOT)
			-- Stop the recording (its tail is done), keep its tee for analysis, and listen again.
		require
			recording: is_recording
		local
			l_seconds: REAL_64
		do
			end_ffmpeg
			tail.close
			l_seconds := tail.samples_read / 16_000
			is_listening := False
			is_recording := False
			finish_at := 0.0
			report_finished (a_slot, l_seconds)
			if listen_wanted (a_slot) then
				start_listening (a_slot)
			end
		ensure
			not_recording: not is_recording
		end

	end_ffmpeg
			-- Kill ffmpeg and wait (up to `Exit_wait_ms') until it has really exited, so its files are
			-- closed: a killed process ends asynchronously, and the Step 4a live test hit "permission
			-- denied" on raw.mkv in that window (debate 01 V6: the recording is closed before analysis).
		local
			l_ok: BOOLEAN
			l_exit: INTEGER
		do
			if process.is_started and then process.is_running then
				l_ok := process.kill
				l_exit := process.wait (Exit_wait_ms)
			end
		ensure
			ended: process.is_started implies not process.is_running
		end

	start_capture (a_slot: separate PT_SPEECH_SLOT; a_plan: PT_CAPTURE_PLAN; a_tee: STRING_32; a_state: INTEGER; a_status: STRING_32)
			-- Run ffmpeg with `a_plan' and follow `a_tee' as a new stream.
		require
			not_capturing: not is_listening
		local
			l_line: STRING_32
			l_ok: BOOLEAN
		do
				-- Never follow a tee left by an earlier run: tailing would start on stale audio
				-- before ffmpeg's -y truncates the file (found by the Step 4a live test).
			l_ok := (create {SIMPLE_FILE}.make (a_tee)).delete
			l_line := quoted (ffmpeg)
			across a_plan.arguments as ic loop
				l_line.append_character (' ')
				l_line.append (quoted (ic))
			end
			create process.make
			process.start (l_line)
			if attached process.last_error as al_e then
				failed := True
				report (a_slot, {PT_SPEECH_SLOT}.Failed, {STRING_32} "could not start ffmpeg: " + al_e + {STRING_32} " | command: " + l_line)
			else
				current_tee := a_tee.twin
				create tail.make (current_tee)
				listen_started_ms := now_ms
				is_listening := True
				if attached vad as al_vad and attached decoder as al_decoder then
					create pipeline.make (al_vad, al_decoder)
				end
				stream := stream + 1
				prompt_serial_seen := -1
				announce_stream (a_slot, stream)
				report (a_slot, a_state, a_status)
			end
		end

	pump (a_slot: separate PT_SPEECH_SLOT; a_pipeline: PT_SPEECH_PIPELINE): INTEGER
			-- One turn: drain ffmpeg, read new samples, push them, deposit the records.
			-- Answers how many samples were consumed.
		require
			listening: is_listening
		local
			l_text: detachable STRING_32
		do
			if process.is_running then
				l_text := process.read_available_output
				process.accumulated_output.wipe_out
			else
				l_text := process.read_available_output
				failed := True
				report (a_slot, {PT_SPEECH_SLOT}.Failed, {STRING_32} "the microphone stopped (ffmpeg ended)" + tail_of (l_text))
			end
			if not failed and not tail.is_open then
				if (create {SIMPLE_FILE}.make (current_tee)).exists then
					tail.open
				elseif now_ms - listen_started_ms > Start_timeout_ms then
					failed := True
					report (a_slot, {PT_SPEECH_SLOT}.Failed, {STRING_32} "the microphone did not start: " + microphone)
				end
			end
			if not failed and tail.is_open then
				if prompt_serial (a_slot) /= prompt_serial_seen then
					prompt_serial_seen := prompt_serial (a_slot)
					a_pipeline.set_prompt (fetched_prompt (a_slot))
				end
				tail.read_into (buffer)
				Result := tail.last_count
				if Result > 0 then
					a_pipeline.push (buffer, Result)
					outgoing.wipe_out
					across 1 |..| a_pipeline.pending_frame_count as ic loop
						outgoing.append (codec.encode_frame (a_pipeline.pending_frame (ic)))
						outgoing.append_character ('%N')
					end
					across 1 |..| a_pipeline.pending_heard_count as ic loop
						outgoing.append (codec.encode_heard (a_pipeline.pending_heard (ic)))
						outgoing.append_character ('%N')
					end
					a_pipeline.clear_pending
					deposit (a_slot, outgoing, a_pipeline.samples_seen)
				end
			end
		end

	stop_listening
			-- Stop ffmpeg; remove the tee file unless it is a recording's (the session keeps it).
		local
			l_ok: BOOLEAN
		do
			if is_listening then
				end_ffmpeg
				tail.close
				if not is_recording then
					l_ok := (create {SIMPLE_FILE}.make (current_tee)).delete
				end
				is_listening := False
				is_recording := False
			end
		ensure
			stopped: not is_listening and not is_recording
		end

feature {NONE} -- Slot calls: each locks the slot for one short call

	report (a_slot: separate PT_SPEECH_SLOT; a_state: INTEGER; a_text: STRING_32)
		do
			a_slot.put_state (a_state, a_text)
		end

	deposit (a_slot: separate PT_SPEECH_SLOT; a_text: STRING_8; a_samples: INTEGER_64)
		require
			clock_monotone: a_samples >= a_slot.samples_heard
		do
			a_slot.put_records (a_text, a_samples)
		end

	report_stopped (a_slot: separate PT_SPEECH_SLOT)
		do
			a_slot.put_stopped
		end

	stop_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.stop_requested
		end

	listen_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.listen_requested
		end

	analysis_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.analysis_requested
		end

	requested_analysis_root (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.analysis_root)
		end

	requested_id_base (a_slot: separate PT_SPEECH_SLOT): INTEGER_64
		do
			Result := a_slot.analysis_id_base
		end

	requested_duration (a_slot: separate PT_SPEECH_SLOT): REAL_64
		do
			Result := a_slot.analysis_duration
		end

	report_analysis (a_slot: separate PT_SPEECH_SLOT; a_succeeded: BOOLEAN; a_summary: STRING_32)
		do
			a_slot.put_analysis_finished (a_succeeded, a_summary)
		end

	record_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.record_requested and not a_slot.recording_finished
		end

	finish_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.finish_requested
		end

	requested_raw (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.record_raw)
		end

	requested_tee (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.record_tee)
		end

	announce_stream (a_slot: separate PT_SPEECH_SLOT; a_stream: INTEGER)
		require
			newer: a_stream > a_slot.stream
		do
			a_slot.put_stream (a_stream)
		end

	report_finished (a_slot: separate PT_SPEECH_SLOT; a_seconds: REAL_64)
		require
			length_non_negative: a_seconds >= 0
		do
			a_slot.put_recording_finished (a_seconds)
		end

	prompt_serial (a_slot: separate PT_SPEECH_SLOT): INTEGER
		do
			Result := a_slot.prompt_serial
		end

	fetched_prompt (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.prompt)
		end

feature {NONE} -- Implementation

	quoted (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' as one command-line argument, always a new string: `to_string_32' on a
			-- STRING_32 answers the same object, and appending to that once grew the `ffmpeg' path
			-- itself (every capture after the first then failed to start).
		do
			if a_text.is_empty or a_text.has (' ') or a_text.has ('(') or a_text.has ('&') then
				Result := {STRING_32} "%"" + a_text + {STRING_32} "%""
			else
				create Result.make_from_string (a_text)
			end
		ensure
			fresh: Result /= a_text
		end

	tail_of (a_text: detachable READABLE_STRING_32): STRING_32
			-- The end of ffmpeg's last output, for a failure message.
		do
			create Result.make_empty
			if attached a_text as al_t and then not al_t.is_empty then
				Result.append ({STRING_32} ": ")
				Result.append (al_t.substring ((al_t.count - 200).max (1), al_t.count))
				Result.left_adjust
				Result.right_adjust
			end
		end

	exception_text: STRING_32
		do
			if attached (create {EXCEPTION_MANAGER_FACTORY}).exception_manager.last_exception as al_e then
				Result := al_e.generator.to_string_32
				if attached al_e.description as al_d then
					Result.append ({STRING_32} " - " + al_d)
				end
			else
				Result := {STRING_32} "unknown error"
			end
		end

	now_ms: REAL_64
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
