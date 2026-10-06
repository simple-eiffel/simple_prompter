note
	description: "[
		Where the speech worker and the window meet. A mailbox on its own processor
		that never blocks: every routine is a field read, an assignment or a short
		append, so neither side ever queues behind the other's work (the
		simple_taskman TM_FRAME_SLOT pattern). Voice frames and heard words cross as
		PT_SPEECH_CODEC records, one per line; the already-read prompt crosses the
		other way, numbered so the worker knows when to fetch it.
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

feature -- Worker side

	put_state (a_state: INTEGER; a_text: separate READABLE_STRING_32)
		require
			known: a_state >= Loading and a_state <= Failed
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

invariant
	known_state: state >= Loading and state <= Failed
	clock_non_negative: samples_heard >= 0

end
