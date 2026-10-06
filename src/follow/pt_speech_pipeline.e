note
	description: "[
		Pure speech scheduling (approved intent Q9). Fed 16 kHz mono samples (from
		the ffmpeg tee file), it emits one PT_VOICE_FRAME per 512 samples and,
		while speech is recent, decodes the last Window_samples every Step_samples
		with the already-read prompt, emitting PT_HEARD_WORDS. The sample count
		is the recording clock. The SCOOP worker (speech/ cluster) only owns the
		processor and the blocking externals behind PT_VAD and PT_DECODER.
	]"
	author: "Larry Rix"

class
	PT_SPEECH_PIPELINE

create
	make

feature {NONE} -- Initialization

	make (a_vad: PT_VAD; a_decoder: PT_DECODER)
			-- Pipeline using `a_vad' and `a_decoder'; decoding enabled.
		do
			vad := a_vad
			decoder := a_decoder
			threshold := Default_threshold
			is_decoding_enabled := True
			create prompt.make_empty
			create ring.make_filled (0.0, Window_samples)
			create frame_buffer.make_filled (0.0, Frame_samples)
			frames_since_speech := Hangover_frames + 1
			create pending_frame_list.make (16)
			create pending_heard_list.make (2)
		ensure
			vad_set: vad = a_vad
			decoder_set: decoder = a_decoder
			fresh: samples_seen = 0 and pending_frame_count = 0 and pending_heard_count = 0
			decoding: is_decoding_enabled
		end

feature -- Constants

	Sample_rate: INTEGER = 16_000
	Frame_samples: INTEGER = 512
	Step_samples: INTEGER = 4_000
			-- 250 ms between decodes.
	Window_samples: INTEGER = 48_000
			-- 3 s decode window.
	Hangover_frames: INTEGER = 8
			-- Frames of silence (256 ms) before speech is considered over.
	Default_threshold: REAL_64 = 0.5

feature -- Access

	vad: PT_VAD
	decoder: PT_DECODER

	threshold: REAL_64
			-- Speech probability threshold.

	prompt: STRING_32
			-- Already-read script text given to the decoder (never upcoming text).

	samples_seen: INTEGER_64
			-- Samples pushed so far: the recording clock (rt = samples_seen / Sample_rate).

	pending_frame_count: INTEGER
		do
			Result := pending_frame_list.count
		end

	pending_heard_count: INTEGER
		do
			Result := pending_heard_list.count
		end

	pending_frame (a_index: INTEGER): PT_VOICE_FRAME
		require
			valid_index: a_index >= 1 and a_index <= pending_frame_count
		do
			Result := pending_frame_list [a_index]
		end

	pending_heard (a_index: INTEGER): PT_HEARD_WORDS
		require
			valid_index: a_index >= 1 and a_index <= pending_heard_count
		do
			Result := pending_heard_list [a_index]
		end

feature -- Status

	is_decoding_enabled: BOOLEAN
			-- Decode windows (Tracking mode)? Voice-gated mode needs frames only.

	is_in_speech: BOOLEAN
			-- Is speech current (within the hangover)?

	last_push_had_speech: BOOLEAN
			-- Was speech current at any point during the last `push' (or just before it)?

feature -- Element change

	push (a_samples: SPECIAL [REAL_32]; a_count: INTEGER)
			-- Consume the first `a_count' samples of `a_samples'.
		require
			count_valid: a_count >= 0 and a_count <= a_samples.count
		local
			i: INTEGER
			l_sample: REAL_32
		do
			last_push_had_speech := is_in_speech
			from i := 0 until i >= a_count loop
				l_sample := a_samples [i]
				ring [write_pos] := l_sample
				write_pos := (write_pos + 1) \\ Window_samples
				ring_fill := (ring_fill + 1).min (Window_samples)
				frame_buffer [frame_fill] := l_sample
				frame_fill := frame_fill + 1
				samples_seen := samples_seen + 1
				if frame_fill = Frame_samples then
					emit_frame (samples_seen - Frame_samples)
					frame_fill := 0
				end
				if samples_seen \\ Step_samples = 0 and is_decoding_enabled and is_in_speech then
					decode_window
				end
				i := i + 1
			end
		ensure
			clock_advanced: samples_seen = old samples_seen + a_count
			frames_emitted: pending_frame_count = old pending_frame_count +
					(samples_seen // Frame_samples - old samples_seen // Frame_samples).to_integer_32
			decodes_bounded: pending_heard_count <= old pending_heard_count +
					(samples_seen // Step_samples - old samples_seen // Step_samples).to_integer_32
			no_decode_when_disabled: not is_decoding_enabled implies pending_heard_count = old pending_heard_count
			decode_only_in_speech: pending_heard_count > old pending_heard_count implies last_push_had_speech
		end

	set_prompt (a_text: READABLE_STRING_32)
			-- Already-read text for the next decodes (I-003; spike gotcha 2: never upcoming text).
		do
			prompt.make_from_string (a_text)
		ensure
			set: prompt.same_string (a_text)
		end

	set_threshold (a_threshold: REAL_64)
		require
			range: a_threshold > 0.0 and a_threshold < 1.0
		do
			threshold := a_threshold
		ensure
			set: threshold = a_threshold
		end

	enable_decoding
		do
			is_decoding_enabled := True
		ensure
			enabled: is_decoding_enabled
		end

	disable_decoding
		do
			is_decoding_enabled := False
		ensure
			disabled: not is_decoding_enabled
		end

	clear_pending
			-- Forget emitted frames and decode results (after the consumer has read them).
		do
			pending_frame_list.wipe_out
			pending_heard_list.wipe_out
		ensure
			cleared: pending_frame_count = 0 and pending_heard_count = 0
			clock_kept: samples_seen = old samples_seen
		end

feature {NONE} -- Implementation

	ring: SPECIAL [REAL_32]
			-- Last Window_samples samples (circular).

	write_pos: INTEGER
			-- Next write index in `ring'.

	ring_fill: INTEGER
			-- Valid samples in `ring' (<= Window_samples).

	frame_buffer: SPECIAL [REAL_32]
			-- Samples of the frame being filled.

	frame_fill: INTEGER
			-- Samples in `frame_buffer'.

	frames_since_speech: INTEGER
			-- Frames since the last speech frame (Hangover_frames + 1 = silent).

	emit_frame (a_first_sample: INTEGER_64)
			-- Score the full `frame_buffer' and record a voice frame.
		local
			j: INTEGER
			l_sum, l_level, l_probability: REAL_64
			l_math: DOUBLE_MATH
		do
			from j := 0 until j >= Frame_samples loop
				l_sum := l_sum + frame_buffer [j] * frame_buffer [j]
				j := j + 1
			end
			create l_math
			l_level := l_math.sqrt (l_sum / Frame_samples).min (1.0)
			l_probability := vad.speech_probability (frame_buffer, 0, a_first_sample)
			if l_probability >= threshold then
				frames_since_speech := 0
				last_push_had_speech := True
			elseif frames_since_speech <= Hangover_frames then
				frames_since_speech := frames_since_speech + 1
			end
			is_in_speech := frames_since_speech <= Hangover_frames
			pending_frame_list.extend (create {PT_VOICE_FRAME}.make (a_first_sample, l_level, l_probability, is_in_speech))
		end

	decode_window
			-- Decode the newest `ring_fill' samples in time order.
		require
			has_samples: ring_fill > 0
		local
			l_window: SPECIAL [REAL_32]
			j, l_first: INTEGER
		do
			create l_window.make_filled (0.0, ring_fill)
			l_first := (write_pos - ring_fill + Window_samples) \\ Window_samples
			from j := 0 until j >= ring_fill loop
				l_window [j] := ring [(l_first + j) \\ Window_samples]
				j := j + 1
			end
			pending_heard_list.extend (decoder.decode (l_window, ring_fill, samples_seen - ring_fill, prompt))
		end

	pending_frame_list: ARRAYED_LIST [PT_VOICE_FRAME]
	pending_heard_list: ARRAYED_LIST [PT_HEARD_WORDS]

invariant
	threshold_range: threshold > 0.0 and threshold < 1.0
	clock_non_negative: samples_seen >= 0
	ring_sized: ring.count = Window_samples
	step_divides_window: Window_samples \\ Step_samples = 0

end
