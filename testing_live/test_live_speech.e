note
	description: "[
		Plan Steps 2+3, verified on the real thing. `replay' pushes a recording of Larry
		through the LIVE path - appended to a tee file in 50 ms pieces as ffmpeg would,
		tailed by PT_TAIL_SOURCE, scored by Silero and decoded by whisper on the GPU
		inside PT_SPEECH_PIPELINE, carried as codec records, fed to the facade in
		Tracking mode - and the tests hold the follower to the acceptance of
		TEST_REAL_VOICE (within one line of distinctive words, never backward; checked
		`Live_latency_s' after each word), plus a real-time budget. The read test uses
		hand-picked checkpoints; the sermon (a private fixture: skipped where absent)
		checks every distinctive word that occurs once in both script and transcript.
		The worker test runs PT_SPEECH_WORKER on its own processor with the real
		microphone: load, listen, stop.
	]"
	author: "Larry Rix"

class
	TEST_LIVE_SPEECH

inherit
	TEST_SET_BASE

feature -- Replay

	test_live_path_follows_larry
			-- The read test: ad-lib, skipped paragraph, homophones, cues.
		local
			l_failures: STRING_32
		do
			replay (Read_wav, Read_script, Read_words)
			print ("    [live] aligner at checkpoints:")
			across << {STRING_32} "teleprompter", {STRING_32} "camera", {STRING_32} "specification", {STRING_32} "watching", {STRING_32} "processors", {STRING_32} "patience" >> as ic loop
				print (" " + position_at (aligned, heard_time (ic) + Live_latency_s).out)
			end
			print ("%N")
			create l_failures.make_empty
			across << {STRING_32} "teleprompter", {STRING_32} "camera", {STRING_32} "specification",
				{STRING_32} "gigabytes", {STRING_32} "watching", {STRING_32} "repeated", {STRING_32} "waits",
				{STRING_32} "processors", {STRING_32} "construction", {STRING_32} "patience" >> as ic loop
				check_point (ic, index_of_word (ic), l_failures, True)
			end
			assert_true ({STRING_32} "within one line at every checkpoint" + l_failures, l_failures.is_empty)
			assert_integers_equal ("never backward", 0, backward_moves)
			assert_true ("decoded while speaking", decodes > 100)
			assert_true ("keeps up with real time: " + wall_s.out + " s", wall_s < samples.count / Rate * 0.6)
			print ("    [live] decode p95 " + p95_decode_ms.truncated_to_integer.out + " ms, worst " + worst_ms.truncated_to_integer.out + " ms%N")
				-- NFR-002: tracking update latency <= 700 ms p95. A decode longer than one 250 ms step
				-- only delays the next step, so the step bounds the 95th percentile and NFR-002 the worst.
			assert_true ("decode p95 inside a step: " + p95_decode_ms.out, p95_decode_ms < 250.0)
			assert_true ("worst decode within NFR-002 (700 ms): " + worst_ms.out, worst_ms < 700.0)
		end

	test_live_path_follows_a_sermon
			-- Five and a half minutes of "Wise of Heart", read naturally (2026-10-06).
		local
			l_failures: STRING_32
			l_checked, l_missed: INTEGER
			l_index: INTEGER
		do
			if not (create {SIMPLE_FILE}.make (Sermon_wav)).exists then
				print ("    [sermon] fixture absent here (private recording): skipped%N")
			else
				replay (Sermon_wav, Sermon_script, Sermon_words)
				create l_failures.make_empty
				across distinctive_words as ic loop
					l_index := index_of_word (ic)
					l_checked := l_checked + 1
					check_point (ic, l_index, l_failures, False)
				end
				l_missed := l_failures.occurrences ('[')
				print ("    [sermon] " + l_checked.out + " distinctive words checked, " + l_missed.out + " more than a line away:" + l_failures.to_string_8 + "%N")
				assert_true ("enough checkpoints", l_checked >= 20)
				assert_true ({STRING_32} "within one line at 90%% of the checkpoints" + l_failures, l_missed * 10 <= l_checked)
				assert_integers_equal ("never backward", 0, backward_moves)
				assert_true ("keeps up with real time: " + wall_s.out + " s", wall_s < samples.count / Rate * 0.6)
				print ("    [live] decode p95 " + p95_decode_ms.truncated_to_integer.out + " ms, worst " + worst_ms.truncated_to_integer.out + " ms%N")
				-- NFR-002: tracking update latency <= 700 ms p95. A decode longer than one 250 ms step
				-- only delays the next step, so the step bounds the 95th percentile and NFR-002 the worst.
			assert_true ("decode p95 inside a step: " + p95_decode_ms.out, p95_decode_ms < 250.0)
			assert_true ("worst decode within NFR-002 (700 ms): " + worst_ms.out, worst_ms < 700.0)
			end
		end

feature {NONE} -- Replay

	replay (a_wav, a_script, a_words: STRING)
			-- Push `a_wav' through the live path over `a_script'; `a_words' holds the word times
			-- of an offline transcription (the checkpoints' clock).
		local
			p: SIMPLE_PROMPTER
			l_clock: PT_FAKE_CLOCK
			l_pipeline: PT_SPEECH_PIPELINE
			l_tail: PT_TAIL_SOURCE
			l_codec: PT_SPEECH_CODEC
			l_buffer: SPECIAL [REAL_32]
			l_anchored, l_written, l_piece, l_prompt_at, i: INTEGER
			l_start, l_decode_ms: REAL_64
		do
			samples := wav_samples (a_wav)
			heard_words := word_times (a_words)
			create l_clock.make
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p := p.with_mode ({PT_FOLLOW_MODE}.Tracking).with_clock (l_clock)
			p.load_script_text ({STRING_32} "Script", file_text (a_script))
			revision := p.history.current_revision
			p.controller.set_count_in (0)
			p.perform ({PT_ACTION}.Play)
			p.perform ({PT_ACTION}.Count_in_done)
			create l_pipeline.make (vad, decoder)
			create l_codec.make
			create l_buffer.make_filled (0.0, {PT_SPEECH_WORKER}.Chunk_samples)
			create steps.make (2000)
			create aligned.make (2000)
			create decode_times.make (2000)
			decodes := 0
			worst_ms := 0
			start_tee
			create l_tail.make (tee_path)
			l_tail.open
			assert_true ("tee file open", l_tail.is_open)
			l_start := now_ms
			from until l_written >= samples.count loop
				l_piece := Piece_samples.min (samples.count - l_written)
				append_tee (l_written, l_piece)
				l_written := l_written + l_piece
				l_clock.set (l_written / 16.0)
				from l_tail.read_into (l_buffer) until l_tail.last_count = 0 loop
					l_pipeline.push (l_buffer, l_tail.last_count)
					if l_pipeline.pending_heard_count > 0 then
						decode_times.extend (decoder.recognizer.last_decode_ms)
						decodes := decodes + l_pipeline.pending_heard_count
						l_decode_ms := l_decode_ms + decoder.recognizer.last_decode_ms
						worst_ms := worst_ms.max (decoder.recognizer.last_decode_ms)
					end
					if p.controller.state = {PT_TAKE_STATE}.Reading then
						across 1 |..| l_pipeline.pending_frame_count as ic loop
							l_codec.decode (l_codec.encode_frame (l_pipeline.pending_frame (ic)))
							if attached l_codec.last_frame as al_f then
								p.feed_voice (al_f)
							end
						end
						across 1 |..| l_pipeline.pending_heard_count as ic loop
							l_codec.decode (l_codec.encode_heard (l_pipeline.pending_heard (ic)))
							if attached l_codec.last_heard as al_h then
								p.feed_heard (al_h)
								if p.aligner.last_alignment.anchor_count > 0 then
									l_anchored := l_anchored + 1
								end
							end
						end
					end
					l_pipeline.clear_pending
					p.recording_clock.observe_bytes (l_pipeline.samples_seen * 4, l_clock.now_ms)
					l_tail.read_into (l_buffer)
				end
				if p.controller.state = {PT_TAKE_STATE}.Reading and then p.controller.reader_position /= l_prompt_at then
					l_prompt_at := p.controller.reader_position
					l_pipeline.set_prompt (p.prompt_text)
				end
				p.tick (l_clock.now_ms)
				if l_written \\ Step_samples < Piece_samples then
					steps.extend (p.controller.reader_position)
					aligned.extend (p.aligner.position)
				end
			end
			wall_s := (now_ms - l_start) / 1000
			l_tail.close
			end_tee
			backward_moves := 0
			from i := 2 until i > steps.count loop
				if steps [i] < steps [i - 1] then
					backward_moves := backward_moves + 1
				end
				i := i + 1
			end
			print ("    [live] " + (samples.count / Rate).truncated_to_integer.out + " s of audio in "
				+ wall_s.truncated_to_integer.out + " s; " + decodes.out + " decodes, mean "
				+ (l_decode_ms / decodes.max (1)).truncated_to_integer.out + " ms, worst " + worst_ms.truncated_to_integer.out
				+ " ms; " + l_anchored.out + " anchored alignments; pill ends at word " + p.controller.reader_position.out
				+ " of " + revision.word_count.out + "%N")
		end

	samples: SPECIAL [REAL_32]
			-- The recording being replayed.
		attribute
			create Result.make_empty (0)
		end

	heard_words: ARRAYED_LIST [TUPLE [t0, t1: REAL_64; text: STRING_32]]
			-- Its offline word times.
		attribute
			create Result.make (0)
		end

	revision: PT_SCRIPT_REVISION
			-- The script being replayed.
		attribute
			Result := placeholder_revision
		end

	placeholder_revision: PT_SCRIPT_REVISION
			-- A one-word script until `replay' loads one.
		local
			l_parser: PT_SCRIPT_PARSER
		do
			create l_parser.make
			l_parser.parse ({STRING_32} "none", {STRING_32} "None.", 1, create {PT_ID_SOURCE}.make)
			Result := l_parser.last_revision
		end

	steps, aligned: ARRAYED_LIST [INTEGER]
			-- Pill (reader) and aligner positions every 250 ms.
		attribute
			create Result.make (0)
		end

	decodes, backward_moves: INTEGER
	wall_s, worst_ms: REAL_64

	decode_times: ARRAYED_LIST [REAL_64]
			-- Each decode's wall time, ms.
		attribute
			create Result.make (0)
		end

	p95_decode_ms: REAL_64
			-- 95th percentile of `decode_times'.
		local
			l_sorted: SORTED_TWO_WAY_LIST [REAL_64]
		do
			create l_sorted.make
			across decode_times as ic loop
				l_sorted.extend (ic)
			end
			if not l_sorted.is_empty then
				Result := l_sorted [((l_sorted.count * 95) // 100).max (1)]
			end
		end

	distinctive_words: ARRAYED_LIST [STRING_32]
			-- Heard words of seven letters or more, not stop words, said once and written once.
		local
			n: PT_NORMALIZER
			l_heard: HASH_TABLE [INTEGER, STRING_32]
			l_written: HASH_TABLE [INTEGER, STRING_32]
			l_word: STRING_32
			i: INTEGER
		do
			create n
			create l_heard.make (512)
			create l_written.make (2048)
			across heard_words as ic loop
				l_word := n.normalized (ic.text)
				l_heard.force (l_heard.item (l_word) + 1, l_word)
			end
			from i := 1 until i > revision.word_count loop
				l_word := revision.word (i).normalized
				l_written.force (l_written.item (l_word) + 1, l_word)
				i := i + 1
			end
			create Result.make (64)
			across heard_words as ic loop
				l_word := n.normalized (ic.text)
				if l_word.count >= 7 and l_heard.item (l_word) = 1 and l_written.item (l_word) = 1
					and then not revision.word (index_of_word (l_word)).is_stop_word then
					Result.extend (l_word)
				end
			end
		end

feature -- Load time

	test_long_script_loads_fast
			-- An 8,000-word sermon must load in well under a second: the app lays it out before its
			-- window and its speech worker start (a 30 s start was found on 2026-10-07).
		local
			p: SIMPLE_PROMPTER
			l_parser: PT_SCRIPT_PARSER
			l_text: STRING_32
			l_t0, l_parse, l_load: REAL_64
			l_was: BOOLEAN
			l_count: INTEGER
		do
			if not (create {SIMPLE_FILE}.make (Sermon_script)).exists then
				print ("    [load] fixture absent here (private script): skipped%N")
			else
				l_text := file_text (Sermon_script)
				l_t0 := now_ms
				create l_parser.make
				l_parser.parse ({STRING_32} "s", l_text, 1, create {PT_ID_SOURCE}.make)
				l_parse := now_ms - l_t0
					-- Where the time goes: the same parse with contract checking off, then one
					-- postcondition's expression alone.
				l_was := {ISE_RUNTIME}.check_assert (False)
				l_t0 := now_ms
				create l_parser.make
				l_parser.parse ({STRING_32} "s", l_text, 1, create {PT_ID_SOURCE}.make)
				print ("    [load] parse with contracts off: " + (now_ms - l_t0).truncated_to_integer.out + " ms%N")
				l_t0 := now_ms
				l_count := l_parser.last_revision.ids_model.range.count
				print ("    [load] ids_model.range.count (postcondition ids_unique) alone: " + (now_ms - l_t0).truncated_to_integer.out + " ms for " + l_count.out + " ids%N")
				l_was := {ISE_RUNTIME}.check_assert (l_was)
				create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
				p := p.with_measure (create {PT_FIXED_MEASURE}.make (10.0, 20.0), 560.0)
				l_t0 := now_ms
				p.load_script_text ({STRING_32} "s", l_text)
				l_load := now_ms - l_t0
				print ("    [load] " + p.history.current_revision.word_count.out + " words: parse " + l_parse.truncated_to_integer.out
					+ " ms; full load (parse, history, layout, aligner, controller) " + l_load.truncated_to_integer.out + " ms%N")
				assert_true ("loads in under a second: " + l_load.out, l_load < 1000.0)
			end
		end

feature -- Worker

	test_worker_listens_to_the_microphone
			-- Real models and the real microphone on the worker's own processor.
		local
			l_slot: separate PT_SPEECH_SLOT
			l_worker: separate PT_SPEECH_WORKER
			l_waited: INTEGER
		do
			create l_slot.make
			create l_worker.make (Ffmpeg_path, {STRING_32} "FHD Camera", {STRING_32} "Microphone (FHD Camera Microphone)", tee_path, Model, Vad_model)
			launch (l_worker, l_slot)
			from until slot_state (l_slot) /= {PT_SPEECH_SLOT}.Loading or l_waited > 60_000 loop
				sleep_ms (100)
				l_waited := l_waited + 100
			end
			assert_true ({STRING_32} "ready: " + slot_status (l_slot), slot_state (l_slot) = {PT_SPEECH_SLOT}.Ready)
			request_listen (l_slot)
			l_waited := 0
			from until slot_samples (l_slot) >= 32_000 or slot_state (l_slot) = {PT_SPEECH_SLOT}.Failed or l_waited > 15_000 loop
				sleep_ms (100)
				l_waited := l_waited + 100
			end
			print ("    [worker] " + slot_status (l_slot).to_string_8 + "; " + slot_samples (l_slot).out + " samples after " + l_waited.out + " ms%N")
			assert_true ({STRING_32} "listening: " + slot_status (l_slot), slot_state (l_slot) = {PT_SPEECH_SLOT}.Listening)
			assert_true ("two seconds of microphone samples", slot_samples (l_slot) >= 32_000)
			assert_true ("voice frames arrived", slot_has_frames (l_slot))
			request_stop (l_slot)
			l_waited := 0
			from until slot_stopped (l_slot) or l_waited > 10_000 loop
				sleep_ms (50)
				l_waited := l_waited + 50
			end
			assert_true ("stopped", slot_stopped (l_slot))
			assert_false ("tee file removed", (create {SIMPLE_FILE}.make (tee_path)).exists)
		end

	test_worker_records_a_take
			-- Step 4a: the worker switches its one ffmpeg to camera + microphone, records into a
			-- session's raw.mkv and tee.f32, finishes after its tail, and listens again on a new stream.
		local
			l_slot: separate PT_SPEECH_SLOT
			l_worker: separate PT_SPEECH_WORKER
			l_waited, l_listen_stream, l_record_stream: INTEGER
			l_dir, l_raw, l_tee: STRING_32
			l_ok: BOOLEAN
			l_finish_ms: REAL_64
		do
			l_dir := tee_path + {STRING_32} ".take"
			l_ok := (create {SIMPLE_FILE}.make (l_dir)).create_directory_recursive
			l_raw := l_dir + {STRING_32} "\raw.mkv"
			l_tee := l_dir + {STRING_32} "\tee.f32"
				-- Leftovers of an earlier failed run must not be mistaken for this recording.
			l_ok := (create {SIMPLE_FILE}.make (l_raw)).delete
			l_ok := (create {SIMPLE_FILE}.make (l_tee)).delete
			create l_slot.make
			create l_worker.make (Ffmpeg_path, {STRING_32} "FHD Camera", {STRING_32} "Microphone (FHD Camera Microphone)", tee_path, Model, Vad_model)
			launch (l_worker, l_slot)
			request_listen (l_slot)
			from until slot_state (l_slot) = {PT_SPEECH_SLOT}.Listening or slot_state (l_slot) = {PT_SPEECH_SLOT}.Failed or l_waited > 60_000 loop
				sleep_ms (100)
				l_waited := l_waited + 100
			end
			assert_true ({STRING_32} "listening first: " + slot_status (l_slot), slot_state (l_slot) = {PT_SPEECH_SLOT}.Listening)
			l_listen_stream := slot_stream (l_slot)
			request_record (l_slot, l_raw, l_tee)
			l_waited := 0
			from until (slot_state (l_slot) = {PT_SPEECH_SLOT}.Recording and slot_samples (l_slot) >= 64_000) or slot_state (l_slot) = {PT_SPEECH_SLOT}.Failed or l_waited > 20_000 loop
				sleep_ms (100)
				l_waited := l_waited + 100
			end
			l_record_stream := slot_stream (l_slot)
			print ("    [record] " + slot_status (l_slot).to_string_8 + "; stream " + l_listen_stream.out + " -> " + l_record_stream.out + "; " + slot_samples (l_slot).out + " samples after " + l_waited.out + " ms%N")
			assert_true ({STRING_32} "recording: " + slot_status (l_slot), slot_state (l_slot) = {PT_SPEECH_SLOT}.Recording)
			assert_true ("a new stream for the recording", l_record_stream > l_listen_stream)
			request_finish (l_slot)
			l_finish_ms := now_ms
			l_waited := 0
			from until slot_finished (l_slot) or slot_state (l_slot) = {PT_SPEECH_SLOT}.Failed or l_waited > 10_000 loop
				sleep_ms (50)
				l_waited := l_waited + 50
			end
			l_waited := (now_ms - l_finish_ms).truncated_to_integer
			assert_true ("recording finished", slot_finished (l_slot))
			print ("    [record] finished after " + l_waited.out + " ms: " + slot_recorded (l_slot).out + " s recorded; raw.mkv "
				+ (create {RAW_FILE}.make_with_name (l_raw)).count.out + " bytes; tee " + ((create {RAW_FILE}.make_with_name (l_tee)).count // 64_000).out + " s%N")
			assert_true ("tail kept (at least 1 s past the request)", l_waited >= 900)
			assert_true ("raw.mkv written", (create {RAW_FILE}.make_with_name (l_raw)).exists and then (create {RAW_FILE}.make_with_name (l_raw)).count > 100_000)
			assert_true ("tee kept for analysis", (create {RAW_FILE}.make_with_name (l_tee)).exists and then (create {RAW_FILE}.make_with_name (l_tee)).count >= 4 * 64_000)
			l_waited := 0
			from until (slot_state (l_slot) = {PT_SPEECH_SLOT}.Listening and slot_stream (l_slot) > l_record_stream) or l_waited > 15_000 loop
				sleep_ms (100)
				l_waited := l_waited + 100
			end
			assert_true ("listening again on a new stream", slot_state (l_slot) = {PT_SPEECH_SLOT}.Listening and slot_stream (l_slot) > l_record_stream)
			request_stop (l_slot)
			l_waited := 0
			from until slot_stopped (l_slot) or l_waited > 10_000 loop
				sleep_ms (50)
				l_waited := l_waited + 50
			end
			assert_true ("stopped", slot_stopped (l_slot))
			l_ok := (create {SIMPLE_FILE}.make (l_raw)).delete
			l_ok := (create {SIMPLE_FILE}.make (l_tee)).delete
			l_ok := (create {SIMPLE_FILE}.make (l_dir)).delete_directory
		end

feature {NONE} -- Separate calls

	launch (a_worker: separate PT_SPEECH_WORKER; a_slot: separate PT_SPEECH_SLOT)
		do
			a_worker.attach_slot (a_slot)
			a_worker.run
		end

	slot_state (a_slot: separate PT_SPEECH_SLOT): INTEGER
		do
			Result := a_slot.state
		end

	slot_status (a_slot: separate PT_SPEECH_SLOT): STRING_32
		do
			create Result.make_from_separate (a_slot.status_text)
		end

	slot_samples (a_slot: separate PT_SPEECH_SLOT): INTEGER_64
		do
			Result := a_slot.samples_heard
		end

	slot_has_frames (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := (create {STRING_8}.make_from_separate (a_slot.records)).has_substring ("F|")
		end

	slot_stopped (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.has_stopped
		end

	request_record (a_slot: separate PT_SPEECH_SLOT; a_raw, a_tee: STRING_32)
		require
			idle: not a_slot.record_requested
		do
			a_slot.request_record (a_raw, a_tee)
		end

	request_finish (a_slot: separate PT_SPEECH_SLOT)
		require
			recording: a_slot.record_requested
		do
			a_slot.request_finish
		end

	slot_finished (a_slot: separate PT_SPEECH_SLOT): BOOLEAN
		do
			Result := a_slot.recording_finished
		end

	slot_recorded (a_slot: separate PT_SPEECH_SLOT): REAL_64
		do
			Result := a_slot.recorded_seconds
		end

	slot_stream (a_slot: separate PT_SPEECH_SLOT): INTEGER
		do
			Result := a_slot.stream
		end

	request_listen (a_slot: separate PT_SPEECH_SLOT)
		do
			a_slot.request_listen
		end

	request_stop (a_slot: separate PT_SPEECH_SLOT)
		do
			a_slot.request_stop
		end

feature {NONE} -- Fixtures

	Rate: INTEGER = 16_000
	Piece_samples: INTEGER = 800
			-- 50 ms, about what ffmpeg flushes at a time.
	Step_samples: INTEGER = 4_000
			-- One position sample per 250 ms (TEST_REAL_VOICE's step).
	Live_latency_s: REAL_64 = 1.5
			-- TEST_REAL_VOICE allows 1.0 s on finished word times; live adds about 0.55 s by
			-- design (one agreement step, 0.25 s, plus the 0.3 s tail guard of PT_HEARD_STABILIZER).

	Model: STRING_32 = "D:\prod\simple_speech\models\ggml-large-v3-turbo-q5_0.bin"
	Vad_model: STRING_32 = "D:\prod\simple_speech\models\ggml-silero-v6.2.0.bin"
	Ffmpeg_path: STRING_32 = "C:\ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe"
	Read_wav: STRING = "D:\prod\simple_prompter\testing\fixtures\larry_read_01.wav"
	Read_words: STRING = "D:\prod\simple_prompter\testing\fixtures\larry_read_01.words.tsv"
	Read_script: STRING = "D:\prod\simple_prompter\testing\fixtures\read_test_01.md"
	Sermon_wav: STRING = "D:\prod\simple_prompter\testing\fixtures\larry_sermon_01.wav"
	Sermon_words: STRING = "D:\prod\simple_prompter\testing\fixtures\larry_sermon_01.words.tsv"
	Sermon_script: STRING = "D:\prod\simple_prompter\testing\fixtures\larry_sermon_01.md"

	tee_path: STRING_32
		once
			if attached (create {EXECUTION_ENVIRONMENT}).temporary_directory_path as al_temp then
				Result := al_temp.extended ("simple_prompter_live_test.f32").name
			else
				Result := {STRING_32} "simple_prompter_live_test.f32"
			end
		end

	vad: PT_SILERO_VAD
		once
			create Result.make (Vad_model)
		end

	decoder: PT_WHISPER_DECODER
		once
			create Result.make (Model)
			Result.warm_up
		end

	tee: detachable RAW_FILE

	start_tee
		local
			l_file: RAW_FILE
		do
			create l_file.make_with_name (tee_path)
			l_file.open_write
			tee := l_file
		end

	append_tee (a_from, a_count: INTEGER)
			-- Write samples `a_from' .. `a_from' + `a_count' - 1 as float32 little endian.
		local
			l_bytes: MANAGED_POINTER
			i: INTEGER
		do
			if attached tee as al_tee then
				create l_bytes.make (a_count * 4)
				from i := 0 until i >= a_count loop
					l_bytes.put_real_32_le (samples [a_from + i], i * 4)
					i := i + 1
				end
				al_tee.put_managed_pointer (l_bytes, 0, a_count * 4)
				al_tee.flush
			end
		end

	end_tee
		local
			l_ok: BOOLEAN
		do
			if attached tee as al_tee then
				al_tee.close
			end
			l_ok := (create {SIMPLE_FILE}.make (tee_path)).delete
		end

	wav_samples (a_path: STRING): SPECIAL [REAL_32]
			-- The whole recording at `a_path' as floats (16-bit PCM WAV, "data" chunk).
		local
			l_file: RAW_FILE
			l_bytes: MANAGED_POINTER
			l_pos, l_data, l_size, i, l_n: INTEGER
		do
			create l_file.make_open_read (a_path)
			create l_bytes.make (l_file.count)
			l_file.read_to_managed_pointer (l_bytes, 0, l_file.count)
			l_file.close
			from l_pos := 12 until l_data > 0 or l_pos + 8 > l_bytes.count loop
				l_size := l_bytes.read_integer_32_le (l_pos + 4)
				if l_bytes.read_natural_8 (l_pos) = ('d').code.to_natural_8 and l_bytes.read_natural_8 (l_pos + 1) = ('a').code.to_natural_8
					and l_bytes.read_natural_8 (l_pos + 2) = ('t').code.to_natural_8 and l_bytes.read_natural_8 (l_pos + 3) = ('a').code.to_natural_8 then
					l_data := l_pos + 8
				else
					l_pos := l_pos + 8 + l_size
				end
			end
			l_n := ((l_bytes.count - l_data) // 2).max (0)
			create Result.make_filled (0, l_n)
			from i := 0 until i >= l_n loop
				Result [i] := (l_bytes.read_integer_16_le (l_data + 2 * i) / 32768.0).truncated_to_real
				i := i + 1
			end
		end

	word_times (a_path: STRING): ARRAYED_LIST [TUPLE [t0, t1: REAL_64; text: STRING_32]]
			-- Word times of an offline transcription ("t0<TAB>t1<TAB>word" per line).
		local
			l_fields: LIST [STRING_32]
		do
			create Result.make (1000)
			across file_text (a_path).split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 3 and then l_fields [1].is_double and then l_fields [2].is_double then
					Result.extend ([l_fields [1].to_double, l_fields [2].to_double, l_fields [3]])
				end
			end
		end

	position_at (a_steps: ARRAYED_LIST [INTEGER]; a_t: REAL_64): INTEGER
			-- Position after the step at time `a_t'.
		do
			Result := a_steps [((a_t * Rate / Step_samples).truncated_to_integer).max (1).min (a_steps.count)]
		end

	heard_time (a_normalized: READABLE_STRING_32): REAL_64
			-- End time of the first heard word whose normal form is `a_normalized'.
		local
			n: PT_NORMALIZER
			l_found: BOOLEAN
		do
			create n
			across heard_words as ic until l_found loop
				if n.normalized (ic.text).same_string (a_normalized) then
					Result := ic.t1
					l_found := True
				end
			end
		end

	index_of_word (a_normalized: READABLE_STRING_32): INTEGER
			-- First word index of `revision' with normal form `a_normalized' (0 if none).
		local
			i: INTEGER
		do
			from i := 1 until Result > 0 or i > revision.word_count loop
				if revision.word (i).normalized.same_string (a_normalized) then
					Result := i
				end
				i := i + 1
			end
		end

	check_point (a_word: READABLE_STRING_32; a_expected: INTEGER; a_failures: STRING_32; a_show: BOOLEAN)
			-- `Live_latency_s' after `a_word' is heard, the pill is within 8 words of `a_expected'.
		local
			l_actual: INTEGER
		do
			l_actual := position_at (steps, heard_time (a_word) + Live_latency_s)
			if a_show then
				print ("    [check] " + a_word.to_string_8 + ": script " + a_expected.out + ", pill " + l_actual.out + "%N")
			end
			if a_expected = 0 or (l_actual - a_expected).abs > 8 then
				a_failures.append ({STRING_32} " [" + a_word + {STRING_32} " at " + heard_time (a_word).truncated_to_integer.out
					+ {STRING_32} " s: script " + a_expected.out + {STRING_32} ", pill " + l_actual.out + {STRING_32} "]")
			end
		end

	file_text (a_path: READABLE_STRING_GENERAL): STRING_32
			-- UTF-8 text of `a_path'.
		local
			l_raw: STRING_8
		do
			create l_raw.make (4096)
			across (create {SIMPLE_FILE}.make (a_path)).binary_content as ic loop
				l_raw.append_character (ic.to_character_8)
			end
			Result := (create {SIMPLE_ENCODING}.make).utf_8_to_utf_32 (l_raw)
			Result.prune_all ('%R')
		end

	sleep_ms (a_ms: INTEGER)
		do
			(create {EXECUTION_ENVIRONMENT}).sleep (a_ms.to_integer_64 * 1_000_000)
		end

	now_ms: REAL_64
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
