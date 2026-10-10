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
		session tee for analysis, and goes back to listening. Beside the capture it checks
		the camera with a short ffmpeg probe of its own (PT_CAMERA_CHECK, polled each turn
		so following never waits) and, while recording, reads ffmpeg's -progress output
		(PT_CAPTURE_PROGRESS) into the slot's Camera and Video reports. Every capture is a new
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
			create camera_probe.make
			create progress.make
			create recording_devices.make (camera, microphone, 1920, 1080, 30)
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
						probe_devices
						webcam_probe_wanted := True
						load_seconds := ((now_ms - l_start) / 1000).rounded
						report (al_slot, {PT_SPEECH_SLOT}.Ready, {STRING_32} "speech ready (" + load_seconds.out + " s to load)")
						vad := l_vad
						decoder := l_decoder
						create analysis_job.make (create {PT_WHISPER_TRANSCRIBER}.make (l_vad.detector, l_decoder.recognizer))
						create publish_job.make (create {PT_WHISPER_TRANSCRIBER}.make (l_vad.detector, l_decoder.recognizer), ffmpeg)
						if attached publish_job as al_publish then
							al_publish.set_on_stage (agent tell_stage)
						end
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
							elseif not is_recording and then publish_wanted (al_slot) then
								run_publish
							elseif not is_recording and then devices_wanted (al_slot) then
								change_devices (al_slot)
							elseif not is_listening and then listen_wanted (al_slot) then
								start_listening (al_slot)
							end
							follow_camera (al_slot)
							l_got := 0
							if is_listening and then attached pipeline as al_pipeline then
								l_got := pump (al_slot, al_pipeline)
							end
							if is_recording then
								report_video (al_slot)
							end
							if l_got < Chunk_samples then
								(create {EXECUTION_ENVIRONMENT}).sleep (Idle_sleep_ms.to_integer_64 * 1_000_000)
							end
						end
					end
				end
				stop_listening
				end_probe
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

	recording_devices: PT_DEVICE_CHOICE
			-- How the camera is recorded: MJPEG when it offers it, else its own mode (OBS Virtual
			-- Camera, NVIDIA Broadcast; see `probe_devices').

	probe_devices
			-- Ask ffmpeg which modes `camera' offers and decide how to record it (PT_DEVICE_PROBE).
		local
			l_listing: STRING_32
		do
			if not camera.is_empty then
				l_listing := (create {SIMPLE_PROCESS}.make).command_output (quoted (ffmpeg)
					+ {STRING_32} " -hide_banner -f dshow -list_options true -i " + quoted ({STRING_32} "video=" + camera))
				recording_devices := (create {PT_DEVICE_PROBE}).choice (l_listing, camera, microphone)
			end
		end

	analysis_job: detachable PT_ANALYSIS_JOB

	publish_job: detachable PT_PUBLISH_JOB
			-- Publishes a rendered take (0.5.0) on the loaded models.
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

	change_devices (a_slot: separate PT_SPEECH_SLOT)
			-- Switch to the devices the Settings page chose: stop listening (the loop listens again
			-- on the new microphone), find how the new camera is recorded, and check it at once.
		require
			not_recording: not is_recording
		do
			camera := requested_camera (a_slot)
			microphone := requested_microphone (a_slot)
			take_devices (a_slot)
			stop_listening
			end_probe
			create recording_devices.make (camera, microphone, 1920, 1080, 30)
			probe_devices
			last_probe_ms := 0.0
			webcam_probe_wanted := True
			report_camera (a_slot, {PT_CAMERA_CHECK}.Unchecked, False,
				(if camera.is_empty then {STRING_32} "none set" else camera + {STRING_32} ": checking" end))
		ensure
			not_listening: not is_listening
		end

	start_recording (a_slot: separate PT_SPEECH_SLOT)
			-- Stop listening; record camera + microphone into the requested raw file and tee.
		require
			not_recording: not is_recording
		local
			l_raw, l_tee: STRING_32
			l_plan: PT_CAPTURE_PLAN
		do
			stop_listening
				-- The probe lets go first: a webcam has one owner, and even OBS Virtual Camera, which
				-- two programs can read at once, failed to open ("Could not find output pin") when the
				-- probe and the recording opened it in the same instant (live test, 2026-10-08).
			end_probe
			if not recording_devices.uses_mjpeg then
					-- Check the virtual camera again `Probe_after_start_ms' into the take.
				last_probe_ms := now_ms - Probe_every_ms + Probe_after_start_ms
			end
			l_raw := requested_raw (a_slot)
			l_tee := requested_tee (a_slot)
			create l_plan.make_recording (ffmpeg, recording_devices, l_raw, l_tee)
			start_capture (a_slot, l_plan,
				l_tee, {PT_SPEECH_SLOT}.Recording, {STRING_32} "RECORDING: " + camera + (if recording_devices.uses_mjpeg then {STRING_32} "" else {STRING_32} " (its own format)" end)
				+ {STRING_32} " + " + microphone)
			if is_listening then
				is_recording := True
				finish_at := 0.0
			end
		end

	run_publish
			-- Publish the requested take (a minute or more: ffmpeg twice, whisper, the local AI). The
			-- slot is held only to read the request and to report, never across the work: a routine
			-- with the slot as a separate argument holds it until it returns, and the window reads
			-- the slot every tick.
		require
			not_recording: not is_recording
		local
			l_request: TUPLE [root, link, hashtags, ai_url, ai_model: STRING_32; uses_ai: BOOLEAN]
		do
			if attached slot as al_slot then
				l_request := publish_request (al_slot)
				report (al_slot, {PT_SPEECH_SLOT}.Publishing, {STRING_32} "publishing the take")
				if is_listening then
					stop_listening
				end
				if attached publish_job as al_job then
					al_job.run (l_request.root, l_request.link, l_request.hashtags, l_request.ai_url, l_request.ai_model, l_request.uses_ai)
					report_publish (al_slot, al_job.succeeded, al_job.summary)
				else
					report_publish (al_slot, False, {STRING_32} "publishing unavailable: the speech models are not loaded")
				end
				if listen_wanted (al_slot) then
					start_listening (al_slot)
				else
					report (al_slot, {PT_SPEECH_SLOT}.Ready, {STRING_32} "speech ready")
				end
			end
		end

	tell_stage (a_text: STRING_32)
			-- The publish job's progress, for the window.
		do
			if attached slot as al_slot then
				report (al_slot, {PT_SPEECH_SLOT}.Publishing, a_text)
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
				al_job.run (l_root, requested_duration (a_slot))
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
			progress.stop
			l_seconds := tail.samples_read / 16_000
			is_listening := False
			is_recording := False
			finish_at := 0.0
			webcam_probe_wanted := True
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
			l_line := command_line (a_plan.arguments)
			create process.make
				-- If the prompter dies (crash, Task Manager), Windows ends this ffmpeg too:
				-- an orphan keeps the camera and the microphone.
			process.set_ends_with_owner (True)
			process.start (l_line)
			if attached process.last_error as al_e then
				failed := True
				report (a_slot, {PT_SPEECH_SLOT}.Failed, {STRING_32} "could not start ffmpeg: " + al_e + {STRING_32} " | command: " + l_line)
			else
				current_tee := a_tee.twin
				create tail.make (current_tee)
				listen_started_ms := now_ms
				is_listening := True
				if a_state = {PT_SPEECH_SLOT}.Recording then
					progress.restart (listen_started_ms)
					video_reported_ms := 0.0
				else
					progress.stop
				end
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
				if is_recording and progress.has_started and attached l_text as al_text then
					progress.feed (al_text, now_ms)
				end
			else
				l_text := process.read_available_output
				failed := True
				report (a_slot, {PT_SPEECH_SLOT}.Failed, stop_reason (l_text) + tail_of (l_text))
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
				progress.stop
				if not is_recording then
					l_ok := (create {SIMPLE_FILE}.make (current_tee)).delete
				end
				is_listening := False
				is_recording := False
			end
		ensure
			stopped: not is_listening and not is_recording
		end

feature {NONE} -- Camera health (2026-10-08)

	camera_probe: SIMPLE_ASYNC_PROCESS
			-- The running camera check (PT_CAMERA_CHECK), its own ffmpeg beside the capture's.

	is_probing: BOOLEAN
			-- Is a camera check running?

	probe_started_ms, last_probe_ms: REAL_64
			-- When the running check started; when the last one ended (0: check at once).

	webcam_probe_wanted: BOOLEAN
			-- Should a webcam be checked when no recording holds it (at start, after each take)?

	progress: PT_CAPTURE_PROGRESS
			-- The running recording's video, from ffmpeg's -progress output.

	video_reported_frames: INTEGER
	video_reported_stalled: BOOLEAN
	video_reported_ms: REAL_64
			-- What `report_video' last told the slot, and when.

	Probe_timeout_ms: REAL_64 = 8000.0
			-- Longest a camera check may run (it reads 30 frames; 0.6 s on OBS, measured 2026-10-08).

	Probe_every_ms: REAL_64 = 10000.0
			-- How often a virtual camera is checked again.

	Probe_after_start_ms: REAL_64 = 3000.0
			-- When a virtual camera is first checked again after a recording opened it.

	Video_report_ms: REAL_64 = 500.0
			-- Shortest gap between video reports while nothing changes but the frame count.

	probe_due: BOOLEAN
			-- Should the camera be checked now? A virtual camera (OBS) every `Probe_every_ms', even
			-- while recording: two programs can read it at once (measured 2026-10-08), and when OBS
			-- closes mid-take it sends its placeholder card, so frames keep coming. A webcam only
			-- when no recording holds it and once per take, so its light does not keep blinking.
		do
			if not camera.is_empty and not is_probing then
				if recording_devices.uses_mjpeg then
					Result := webcam_probe_wanted and not is_recording
				else
					Result := last_probe_ms = 0.0 or else now_ms - last_probe_ms >= Probe_every_ms
				end
			end
		end

	follow_camera (a_slot: separate PT_SPEECH_SLOT)
			-- One turn: start a check when one is due; when the running one ends (or times out),
			-- judge it and tell the slot.
		local
			l_text: detachable STRING_32
			l_check: PT_CAMERA_CHECK
		do
			if is_probing then
				l_text := camera_probe.read_available_output
				if not camera_probe.is_running or else now_ms - probe_started_ms > Probe_timeout_ms then
					end_probe
					create l_check.make (recording_devices)
					l_check.read (camera_probe.accumulated_output)
					report_camera (a_slot, l_check.verdict, l_check.is_dark, l_check.summary)
				end
			elseif probe_due then
				webcam_probe_wanted := False
				last_probe_ms := now_ms
				create camera_probe.make
				camera_probe.set_ends_with_owner (True)
				camera_probe.start (command_line ((create {PT_CAMERA_CHECK}.make (recording_devices)).arguments))
				if attached camera_probe.last_error as al_e then
					report_camera (a_slot, {PT_CAMERA_CHECK}.No_picture, False, camera + {STRING_32} ": could not start ffmpeg to check it (" + al_e + {STRING_32} ")")
				else
					is_probing := True
					probe_started_ms := now_ms
				end
			end
		ensure
			probe_clock_kept: is_probing implies probe_started_ms > 0.0
		end

	end_probe
			-- Stop the running check, if any, and keep what it printed.
		local
			l_ok: BOOLEAN
			l_exit: INTEGER
			l_text: detachable STRING_32
		do
			if is_probing then
				if camera_probe.is_running then
					l_ok := camera_probe.kill
					l_exit := camera_probe.wait (Exit_wait_ms)
				end
				l_text := camera_probe.read_available_output
				is_probing := False
				last_probe_ms := now_ms
			end
		ensure
			not_probing: not is_probing
		end

	report_video (a_slot: separate PT_SPEECH_SLOT)
			-- Tell the slot how the recording's video is doing: at once when it stalls or recovers,
			-- else at most every `Video_report_ms' while frames grow.
		require
			recording: is_recording
		local
			l_now: REAL_64
			l_stalled: BOOLEAN
		do
			if progress.has_started then
				l_now := now_ms
				l_stalled := progress.is_stalled (l_now)
				if l_stalled /= video_reported_stalled or else (progress.frames /= video_reported_frames
					and l_now - video_reported_ms >= Video_report_ms) or else video_reported_ms = 0.0 then
					video_reported_stalled := l_stalled
					video_reported_frames := progress.frames
					video_reported_ms := l_now
					put_video (a_slot, progress.frames, l_stalled, progress.summary (l_now))
				end
			end
		end

feature {NONE} -- Slot calls: each locks the slot for one short call

	report_camera (a_slot: separate PT_SPEECH_SLOT; a_verdict: INTEGER; a_dark: BOOLEAN; a_text: STRING_32)
		require
			known: a_verdict >= {PT_CAMERA_CHECK}.Unchecked and a_verdict <= {PT_CAMERA_CHECK}.No_picture
			dark_only_when_live: a_dark implies a_verdict = {PT_CAMERA_CHECK}.Live
		do
			a_slot.put_camera (a_verdict, a_dark, a_text)
		end

	put_video (a_slot: separate PT_SPEECH_SLOT; a_frames: INTEGER; a_stalled: BOOLEAN; a_text: STRING_32)
		require
			frames_non_negative: a_frames >= 0
		do
			a_slot.put_video (a_frames, a_stalled, a_text)
		end

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

	requested_duration (a_slot: separate PT_SPEECH_SLOT): REAL_64
		do
			Result := a_slot.analysis_duration
		end

	publish_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.publish_requested
		end

	publish_request (a_slot: separate PT_SPEECH_SLOT): TUPLE [root, link, hashtags, ai_url, ai_model: STRING_32; uses_ai: BOOLEAN]
			-- The requested publish, copied to this processor.
		do
			Result := [create {STRING_32}.make_from_separate (a_slot.publish_root), create {STRING_32}.make_from_separate (a_slot.publish_link),
				create {STRING_32}.make_from_separate (a_slot.publish_hashtags), create {STRING_32}.make_from_separate (a_slot.publish_ai_url),
				create {STRING_32}.make_from_separate (a_slot.publish_ai_model), a_slot.publish_uses_ai]
		end

	report_publish (a_slot: separate PT_SPEECH_SLOT; a_succeeded: BOOLEAN; a_summary: STRING_32)
		do
			a_slot.put_publish_finished (a_succeeded, a_summary)
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

	devices_wanted (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.devices_requested
		end

	requested_camera (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.device_camera)
		end

	requested_microphone (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.device_microphone)
		end

	take_devices (a_slot: separate PT_SPEECH_SLOT)
		do
			a_slot.acknowledge_devices
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

	stop_reason (a_output: detachable READABLE_STRING_32): STRING_32
			-- Why the capture ended, for the control window. A device another program holds (OBS
			-- using the webcam) shows up as "other application" in ffmpeg's error (OBS test, 2026-10-07).
		do
			if attached a_output as al_o and then al_o.as_lower.has_substring ({STRING_32} "other application") then
				Result := {STRING_32} "another program is using the "
					+ (if is_recording then camera + {STRING_32} " or " else {STRING_32} "" end) + microphone
					+ (if is_recording then {STRING_32} " (if OBS has the webcam, set camera = %"OBS Virtual Camera%")" else {STRING_32} "" end)
			elseif is_recording then
				Result := {STRING_32} "the recording stopped (ffmpeg ended)"
			else
				Result := {STRING_32} "the microphone stopped (ffmpeg ended)"
			end
		end

	command_line (a_arguments: LIST [STRING_32]): STRING_32
			-- ffmpeg with `a_arguments', each quoted as needed.
		do
			Result := quoted (ffmpeg)
			across a_arguments as ic loop
				Result.append_character (' ')
				Result.append (quoted (ic))
			end
		end

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
