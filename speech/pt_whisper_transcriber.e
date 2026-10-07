note
	description: "[
		The full-recording speech pass for analysis (plan Step 4b; debate 01: a job in the
		speech worker, on the models it already has loaded). Reads the session's 16 kHz
		float tee, scores it with Silero in one pass to build the speech map, cuts the
		speech into passages of at most `Max_passage_s' at silences, and decodes each
		with whisper's passage settings (SPEECH_GPU_WHISPER.decode_passage), prompted
		with the text of the passage before. Word times come back absolute.
		Measured (V1): about 8 ms per second of audio for decoding.
	]"
	author: "Larry Rix"

class
	PT_WHISPER_TRANSCRIBER

inherit
	PT_TRANSCRIBER

create
	make

feature {NONE} -- Initialization

	make (a_vad: SPEECH_SILERO_VAD; a_recognizer: SPEECH_GPU_WHISPER)
		do
			vad := a_vad
			recognizer := a_recognizer
			create normalizer
		ensure
			vad_set: vad = a_vad
			recognizer_set: recognizer = a_recognizer
		end

feature -- Constants

	Rate: INTEGER = 16_000
	Chunk: INTEGER = 512
			-- Silero's chunk: 32 ms.
	Threshold: REAL_64 = 0.5
	Hangover_chunks: INTEGER = 8
			-- Silence shorter than this (256 ms) does not end a speech span (as live).
	Pad_s: REAL_64 = 0.15
			-- Audio kept around each passage, so a word's edges are not cut.
	Max_passage_s: REAL_64 = 28.0
			-- Whisper reads 30 s windows.
	Prompt_chars: INTEGER = 200

feature -- Access

	vad: SPEECH_SILERO_VAD
	recognizer: SPEECH_GPU_WHISPER

	passage_count: INTEGER
			-- Passages decoded by the last `transcribe'.

feature -- Basic operations

	transcribe (a_audio_path: READABLE_STRING_32; a_duration: REAL_64)
			-- Transcribe the 16 kHz float tee at `a_audio_path'.
		local
			l_samples: SPECIAL [REAL_32]
			l_map: PT_SPEECH_MAP
			l_spans: ARRAYED_LIST [TUPLE [t0, t1: REAL_64]]
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
		do
			is_success := False
			last_map := Void
			last_heard := Void
			last_error := Void
			passage_count := 0
			l_samples := samples_of (a_audio_path)
			if l_samples.count < Chunk then
				last_error := {STRING_32} "the take's audio track is missing or empty: " + a_audio_path
			elseif not vad.is_loaded or not recognizer.is_loaded then
				last_error := {STRING_32} "the speech models are not loaded"
			else
				vad.score_all (l_samples, 0, l_samples.count)
				if not vad.last_error.is_empty then
					last_error := vad.last_error.twin
				else
					l_spans := speech_spans (vad.probabilities, a_duration)
					create l_map.make (a_duration)
					across l_spans as ic loop
						if ic.t1 > ic.t0 and ic.t0 >= l_map.last_end and ic.t1 <= a_duration then
							l_map.extend_span (create {PT_TIME_SPAN}.make (ic.t0, ic.t1))
						end
					end
					l_words := passage_words (l_samples, l_spans, a_duration.min (l_samples.count / Rate))
					create last_heard.make (0, l_samples.count, l_words)
					last_map := l_map
					is_success := True
				end
			end
		end

feature {NONE} -- Implementation

	normalizer: PT_NORMALIZER

	speech_spans (a_p: SPECIAL [REAL_64]; a_duration: REAL_64): ARRAYED_LIST [TUPLE [t0, t1: REAL_64]]
			-- Speech as time spans: chunks at or above `Threshold', joined across short silences.
		local
			i, l_quiet: INTEGER
			l_in: BOOLEAN
			l_start, l_end, l_chunk_s: REAL_64
		do
			create Result.make (64)
			l_chunk_s := Chunk / Rate
			from i := 0 until i >= a_p.count loop
				if a_p [i] >= Threshold then
					if not l_in then
						l_in := True
						l_start := i * l_chunk_s
					end
					l_quiet := 0
					l_end := ((i + 1) * l_chunk_s).min (a_duration)
				elseif l_in then
					l_quiet := l_quiet + 1
					if l_quiet > Hangover_chunks then
						Result.extend ([l_start.min (a_duration), l_end])
						l_in := False
					end
				end
				i := i + 1
			end
			if l_in then
				Result.extend ([l_start.min (a_duration), l_end])
			end
		end

	passage_words (a_samples: SPECIAL [REAL_32]; a_spans: ARRAYED_LIST [TUPLE [t0, t1: REAL_64]]; a_limit: REAL_64): ARRAYED_LIST [PT_HEARD_WORD]
			-- Decode the speech spans as passages of at most `Max_passage_s'; words with absolute times.
		local
			i: INTEGER
			l_p0, l_p1, l_t0, l_t1: REAL_64
			l_prompt: STRING_32
			l_from, l_n: INTEGER
			l_piece: SPECIAL [REAL_32]
		do
			create Result.make (256)
			create l_prompt.make_empty
			from i := 1 until i > a_spans.count loop
					-- A passage starts at span i and takes the following spans while it stays short.
				l_p0 := a_spans [i].t0
				l_p1 := a_spans [i].t1
				from until i + 1 > a_spans.count or else a_spans [i + 1].t1 - l_p0 > Max_passage_s loop
					i := i + 1
					l_p1 := a_spans [i].t1
				end
				from until l_p0 >= l_p1 loop
						-- A single span longer than a passage is decoded in `Max_passage_s' pieces.
					l_t1 := l_p1.min (l_p0 + Max_passage_s)
					l_from := (((l_p0 - Pad_s).max (0.0)) * Rate).truncated_to_integer
					l_n := ((((l_t1 + Pad_s).min (a_limit)) * Rate).truncated_to_integer - l_from).min (a_samples.count - l_from)
					if l_n >= Chunk then
						create l_piece.make_filled (0.0, l_n)
						l_piece.copy_data (a_samples, l_from, 0, l_n)
						recognizer.decode_passage (l_piece, l_n, l_prompt)
						passage_count := passage_count + 1
						across recognizer.last_words as ic loop
							l_t0 := (l_from / Rate + ic.t0).min (a_limit)
							Result.extend (create {PT_HEARD_WORD}.make (ic.text, normalizer.normalized (ic.text),
								l_t0, (l_from / Rate + ic.t1).max (l_t0).min (a_limit), ic.probability))
						end
						l_prompt := recognizer.last_text.twin
						if l_prompt.count > Prompt_chars then
							l_prompt.keep_tail (Prompt_chars)
						end
					end
					l_p0 := l_t1
				end
				i := i + 1
			end
		end

	samples_of (a_path: READABLE_STRING_32): SPECIAL [REAL_32]
			-- The 16 kHz mono float32 little-endian file at `a_path' (empty when missing).
		local
			l_file: RAW_FILE
			l_bytes: MANAGED_POINTER
			l_n, i: INTEGER
		do
			create l_file.make_with_name (a_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				l_n := l_file.count // 4
				create l_bytes.make ((l_n * 4).max (1))
				if l_n > 0 then
					l_file.read_to_managed_pointer (l_bytes, 0, l_n * 4)
				end
				l_file.close
				create Result.make_filled (0.0, l_n)
				from i := 0 until i >= l_n loop
					Result [i] := l_bytes.read_real_32_le (i * 4)
					i := i + 1
				end
			else
				create Result.make_empty (0)
			end
		end

end
