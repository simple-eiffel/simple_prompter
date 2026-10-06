note
	description: "Pure speech pipeline (approved Q9) with scripted VAD and decoder; speech codec."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_PIPELINE

inherit
	PT_TEST_SET

feature -- Tests

	test_push_advances_recording_clock
		local
			p: PT_SPEECH_PIPELINE
		do
			create p.make (create {PT_SCRIPTED_VAD}.make (<<0.0>>), create {PT_SCRIPTED_DECODER}.make)
			p.push (silence (1_000), 1_000)
			p.push (silence (600), 600)
			assert_true ("1600 samples", p.samples_seen = 1_600)
		end

	test_one_frame_per_512_samples
		local
			p: PT_SPEECH_PIPELINE
		do
			create p.make (create {PT_SCRIPTED_VAD}.make (<<0.0, 0.0, 0.0, 0.0>>), create {PT_SCRIPTED_DECODER}.make)
			p.push (silence (1_600), 1_600)
			assert_integers_equal ("three whole frames", 3, p.pending_frame_count)
		end

	test_no_decode_when_disabled
		local
			p: PT_SPEECH_PIPELINE
			d: PT_SCRIPTED_DECODER
		do
			create d.make
			create p.make (create {PT_SCRIPTED_VAD}.make (<<1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0>>), d)
			p.disable_decoding
			p.push (silence (5_000), 5_000)
			assert_integers_equal ("no heard results", 0, p.pending_heard_count)
			assert_integers_equal ("decoder untouched", 0, d.decode_count)
		end

	test_decodes_while_speaking_with_prompt
		local
			p: PT_SPEECH_PIPELINE
			d: PT_SCRIPTED_DECODER
		do
			create d.make
			create p.make (create {PT_SCRIPTED_VAD}.make (<<1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0>>), d)
			p.set_prompt ({STRING_32} "This is Moody.")
			p.push (silence (4_000), 4_000)
			assert_integers_equal ("one decode at the 250 ms step", 1, p.pending_heard_count)
			assert_true ("prompt passed", d.last_prompt.same_string ({STRING_32} "This is Moody."))
		end

	test_clear_pending_keeps_clock
		local
			p: PT_SPEECH_PIPELINE
		do
			create p.make (create {PT_SCRIPTED_VAD}.make (<<0.0>>), create {PT_SCRIPTED_DECODER}.make)
			p.push (silence (2_048), 2_048)
			p.clear_pending
			assert_integers_equal ("cleared", 0, p.pending_frame_count)
			assert_true ("clock kept", p.samples_seen = 2_048)
		end

	test_scripted_doubles
		local
			v: PT_SCRIPTED_VAD
			d: PT_SCRIPTED_DECODER
			h: PT_HEARD_WORDS
		do
			create v.make (<<0.1, 0.9>>)
			assert_reals_equal ("frame 1", 0.9, v.speech_probability (silence (512), 0, 512), 1.0e-9)
			assert_reals_equal ("beyond script", 0.0, v.speech_probability (silence (512), 0, 99_999), 1.0e-9)
			create d.make
			d.script_window (0, <<{STRING_32} "This", {STRING_32} "is">>)
			h := d.decode (silence (16_000), 16_000, 0, {STRING_32} "")
			assert_integers_equal ("two words", 2, h.count)
		end

	test_speech_codec_round_trip
		local
			k: PT_SPEECH_CODEC
		do
			create k.make
			k.decode (k.encode_frame (frame (1_024, True)))
			assert_true ("frame back", attached k.last_frame)
			if attached k.last_frame as al_f then
				assert_true ("position", al_f.sample_pos = 1_024)
				assert_true ("speech", al_f.is_speech)
			end
		end

end
