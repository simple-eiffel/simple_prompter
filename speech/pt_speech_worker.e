note
	description: "[
		Live speech on its own processor (approved intent Q9). Loads Silero and
		whisper (GPU) here, so the window never waits on them; when the window asks,
		starts ffmpeg capturing the microphone into the 16 kHz float tee file, tails
		that file into PT_SPEECH_PIPELINE, and deposits the voice frames and heard
		words in the slot as codec records. ffmpeg's merged stdout/stderr pipe is
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

	make (a_ffmpeg, a_microphone, a_tee_path, a_model, a_vad_model: separate READABLE_STRING_32)
		do
			create ffmpeg.make_from_separate (a_ffmpeg)
			create microphone.make_from_separate (a_microphone)
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
	Start_timeout_ms: REAL_64 = 8000.0
			-- How long ffmpeg may take to produce the tee file.

feature -- Access

	ffmpeg, microphone, tee_path, model_path, vad_model_path: STRING_32
	slot: detachable separate PT_SPEECH_SLOT

feature -- Status

	is_running: BOOLEAN
	is_listening: BOOLEAN

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
			l_pipeline: PT_SPEECH_PIPELINE
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
						create l_pipeline.make (l_vad, l_decoder)
						from
						until
							stop_wanted (al_slot) or failed
						loop
							if not is_listening and then listen_wanted (al_slot) then
								start_listening (al_slot)
							end
							l_got := 0
							if is_listening then
								l_got := pump (al_slot, l_pipeline)
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

	start_listening (a_slot: separate PT_SPEECH_SLOT)
			-- Start ffmpeg on the microphone, writing the tee file.
		require
			not_listening: not is_listening
		local
			l_plan: PT_CAPTURE_PLAN
			l_line: STRING_32
			l_ok: BOOLEAN
		do
			l_ok := (create {SIMPLE_FILE}.make (tee_path)).delete
			create l_plan.make_audio_only (ffmpeg, create {PT_DEVICE_CHOICE}.make ({STRING_32} "", microphone, 1, 1, 1), tee_path)
			l_line := quoted (ffmpeg)
			across l_plan.arguments as ic loop
				l_line.append_character (' ')
				l_line.append (quoted (ic))
			end
			create process.make
			process.start (l_line)
			if attached process.last_error as al_e then
				failed := True
				report (a_slot, {PT_SPEECH_SLOT}.Failed, {STRING_32} "could not start ffmpeg: " + al_e)
			else
				create tail.make (tee_path)
				listen_started_ms := now_ms
				is_listening := True
				report (a_slot, {PT_SPEECH_SLOT}.Listening, {STRING_32} "listening: " + microphone + {STRING_32} " (speech loaded in " + load_seconds.out + {STRING_32} " s)")
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
				if (create {SIMPLE_FILE}.make (tee_path)).exists then
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
			-- Stop ffmpeg and remove the tee file.
		local
			l_ok: BOOLEAN
		do
			if is_listening then
				if process.is_running then
					l_ok := process.kill
				end
				tail.close
				l_ok := (create {SIMPLE_FILE}.make (tee_path)).delete
				is_listening := False
			end
		ensure
			stopped: not is_listening
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
			-- `a_text' as one command-line argument.
		do
			if a_text.is_empty or a_text.has (' ') or a_text.has ('(') or a_text.has ('&') then
				Result := {STRING_32} "%"" + a_text + {STRING_32} "%""
			else
				Result := a_text.to_string_32
			end
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
