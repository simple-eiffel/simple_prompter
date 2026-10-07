note
	description: "[
		Where the speech worker and the window meet. A mailbox on its own processor
		that never blocks: every routine is a field read, an assignment or a short
		append, so neither side ever queues behind the other's work (the
		simple_taskman TM_FRAME_SLOT pattern). Voice frames and heard words cross as
		PT_SPEECH_CODEC records, one per line; the already-read prompt crosses the
		other way, numbered so the worker knows when to fetch it. Recording (plan
		Step 4a) is requested here too: the worker switches its one ffmpeg from the
		microphone alone to camera + microphone, and every new capture is a new
		`stream' (records cleared, sample clock back to zero).
	]"
	author: "Larry Rix"

class
	PT_SPEECH_SLOT

create
	make

feature {NONE} -- Initialization

	make
		do
			create records.make (4096)
			create prompt.make_empty
			create status_text.make_from_string ({STRING_32} "loading the speech models")
			state := Loading
		ensure
			loading: state = Loading
			empty: records.is_empty and samples_heard = 0
			nothing_requested: not listen_requested and not stop_requested and not has_stopped
		end

feature -- Constants

	Loading: INTEGER = 1
	Ready: INTEGER = 2
	Listening: INTEGER = 3
	Failed: INTEGER = 4
	Recording: INTEGER = 5
	Analyzing: INTEGER = 6

	Max_record_bytes: INTEGER = 1_000_000
			-- Records beyond this (the window stalled) replace what is waiting.

feature -- Access

	state: INTEGER
	status_text: STRING_32
			-- What the worker is doing, or why it failed.

	records: STRING_8
			-- Codec records waiting for the window, each ending in a new line.

	dropped: INTEGER
			-- Times waiting records were thrown away because the window fell behind.

	samples_heard: INTEGER_64
			-- Microphone samples the worker has consumed: the recording clock.

	prompt: STRING_32
			-- Already-read text for the decoder.

	prompt_serial: INTEGER
			-- Bumped by every `set_prompt'.

	listen_requested: BOOLEAN
	stop_requested: BOOLEAN
	has_stopped: BOOLEAN

	stream: INTEGER
			-- Bumped by the worker at every new capture (listening or recording).

	record_requested: BOOLEAN
			-- Should the worker record (camera + microphone) into `record_raw' and `record_tee'?

	finish_requested: BOOLEAN
			-- Should the worker finish the recording (after its short tail)?

	recording_finished: BOOLEAN
			-- Has the worker closed the last recording (raw file complete as far as a kill allows)?

	record_raw, record_tee: STRING_32
			-- Where the requested recording goes.
		attribute
			create Result.make_empty
		end

	recorded_seconds: REAL_64
			-- Length of the last finished recording, from its tee.

	analysis_requested: BOOLEAN
			-- Should the worker analyze the take in `analysis_root'?

	analysis_finished: BOOLEAN
			-- Has the worker finished the last analysis (successfully or not)?

	analysis_succeeded: BOOLEAN

	analysis_root: STRING_32
			-- Session folder of the requested analysis.
		attribute
			create Result.make_empty
		end

	analysis_duration: REAL_64
			-- The take's length, seconds.

	analysis_summary: STRING_32
			-- The worker's one-line outcome.
		attribute
			create Result.make_empty
		end

feature -- Worker side

	put_state (a_state: INTEGER; a_text: separate READABLE_STRING_32)
		require
			known: a_state >= Loading and a_state <= Analyzing
		do
			state := a_state
			create status_text.make_from_separate (a_text)
		ensure
			set: state = a_state
		end

	put_records (a_text: separate READABLE_STRING_8; a_samples: INTEGER_64)
			-- Append `a_text' (whole records); the clock is now `a_samples'.
		require
			clock_monotone: a_samples >= samples_heard
		do
			if records.count + a_text.count > Max_record_bytes then
				records.wipe_out
				dropped := dropped + 1
			end
			records.append (create {STRING_8}.make_from_separate (a_text))
			samples_heard := a_samples
		ensure
			clock_set: samples_heard = a_samples
		end

	put_stopped
		do
			has_stopped := True
		ensure
			stopped: has_stopped
		end

	put_stream (a_stream: INTEGER)
			-- A new capture began: what is waiting belongs to the old one.
		require
			newer: a_stream > stream
		do
			stream := a_stream
			records.wipe_out
			samples_heard := 0
		ensure
			set: stream = a_stream
			fresh: records.is_empty and samples_heard = 0
		end

	put_analysis_finished (a_succeeded: BOOLEAN; a_summary: separate READABLE_STRING_32)
			-- The analysis is over.
		do
			analysis_requested := False
			analysis_finished := True
			analysis_succeeded := a_succeeded
			create analysis_summary.make_from_separate (a_summary)
		ensure
			finished: analysis_finished and not analysis_requested
		end

	put_recording_finished (a_seconds: REAL_64)
			-- The recording is closed; it ran `a_seconds'.
		require
			length_non_negative: a_seconds >= 0
		do
			record_requested := False
			finish_requested := False
			recording_finished := True
			recorded_seconds := a_seconds
		ensure
			finished: recording_finished and not record_requested and not finish_requested
		end

feature -- Window side

	clear_records
			-- The window has taken `records'.
		do
			records.wipe_out
		ensure
			empty: records.is_empty
		end

	set_prompt (a_text: separate READABLE_STRING_32)
		do
			create prompt.make_from_separate (a_text)
			prompt_serial := prompt_serial + 1
		ensure
			bumped: prompt_serial = old prompt_serial + 1
		end

	request_listen
			-- Start the microphone as soon as the models are ready.
		do
			listen_requested := True
		ensure
			requested: listen_requested
		end

	request_stop
		do
			stop_requested := True
		ensure
			requested: stop_requested
		end

	request_record (a_raw, a_tee: separate READABLE_STRING_32)
			-- Record camera + microphone into `a_raw' (and the 16 kHz tee `a_tee').
		require
			not_recording: not record_requested
		do
			create record_raw.make_from_separate (a_raw)
			create record_tee.make_from_separate (a_tee)
			record_requested := True
			finish_requested := False
			recording_finished := False
		ensure
			requested: record_requested and not recording_finished
		end

	request_finish
			-- End the recording (the worker keeps a short tail first).
		require
			recording: record_requested
		do
			finish_requested := True
		ensure
			requested: finish_requested
		end

	acknowledge_finished
			-- The window has seen `recording_finished'.
		do
			recording_finished := False
		ensure
			seen: not recording_finished
		end

	request_analysis (a_root: separate READABLE_STRING_32; a_duration: REAL_64)
			-- Analyze the take in session folder `a_root'.
		require
			not_analyzing: not analysis_requested
			duration_positive: a_duration > 0
		do
			create analysis_root.make_from_separate (a_root)
			analysis_duration := a_duration
			analysis_finished := False
			analysis_requested := True
		ensure
			requested: analysis_requested and not analysis_finished
		end

	acknowledge_analysis
			-- The window has seen `analysis_finished'.
		do
			analysis_finished := False
		ensure
			seen: not analysis_finished
		end

invariant
	known_state: state >= Loading and state <= Analyzing
	finish_only_while_recording: finish_requested implies record_requested
	clock_non_negative: samples_heard >= 0

end
