note
	description: "[
		Voice activity detector over one 512-sample frame at 16 kHz. The app
		supplies a Silero model through simple_speech (PT_SILERO_VAD); tests use
		PT_SCRIPTED_VAD. The frame's start sample is passed so doubles stay pure.
	]"
	author: "Larry Rix"

deferred class
	PT_VAD

feature -- Constants

	Frame_samples: INTEGER = 512
			-- 32 ms at 16 kHz.

feature -- Detection

	speech_probability (a_samples: SPECIAL [REAL_32]; a_offset: INTEGER; a_first_sample: INTEGER_64): REAL_64
			-- Probability that the frame `a_samples' [a_offset .. a_offset + Frame_samples - 1],
			-- which starts at sample `a_first_sample' of the recording, is speech.
		require
			frame_inside: a_offset >= 0 and a_offset + Frame_samples <= a_samples.count
			position_non_negative: a_first_sample >= 0
		deferred
		ensure
			probability_range: Result >= 0.0 and Result <= 1.0
		end

end
