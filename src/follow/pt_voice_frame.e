note
	description: "[
		Summary of one VAD frame (512 samples = 32 ms at 16 kHz): position on the
		recording's sample clock, RMS level, speech probability and decision.
		Crosses SCOOP processors by value (encoded by PT_SPEECH_CODEC).
	]"
	author: "Larry Rix"

class
	PT_VOICE_FRAME

create
	make

feature {NONE} -- Initialization

	make (a_sample_pos: INTEGER_64; a_level, a_speech_probability: REAL_64; a_is_speech: BOOLEAN)
			-- Frame starting at sample `a_sample_pos'.
		require
			position_non_negative: a_sample_pos >= 0
			level_range: a_level >= 0.0 and a_level <= 1.0
			probability_range: a_speech_probability >= 0.0 and a_speech_probability <= 1.0
		do
			sample_pos := a_sample_pos
			level := a_level
			speech_probability := a_speech_probability
			is_speech := a_is_speech
		ensure
			position_set: sample_pos = a_sample_pos
			level_set: level = a_level
			probability_set: speech_probability = a_speech_probability
			decision_set: is_speech = a_is_speech
		end

feature -- Access

	sample_pos: INTEGER_64
			-- First sample of the frame on the 16 kHz recording clock.

	level: REAL_64
			-- RMS level, 0..1 (drives the glow).

	speech_probability: REAL_64
			-- VAD probability that the frame is speech.

	is_speech: BOOLEAN
			-- VAD decision (probability against the pipeline threshold, with hangover).

	seconds: REAL_64
			-- Frame start in seconds.
		do
			Result := sample_pos / 16_000
		ensure
			non_negative: Result >= 0
		end

invariant
	position_non_negative: sample_pos >= 0
	level_range: level >= 0.0 and level <= 1.0
	probability_range: speech_probability >= 0.0 and speech_probability <= 1.0

end
