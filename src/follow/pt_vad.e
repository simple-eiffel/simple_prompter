note
	description: "[
		Voice activity detector over one 512-sample frame at 16 kHz. The app
		supplies a Silero model through simple_speech (PT_SILERO_VAD); tests use
		PT_SCRIPTED_VAD. Silero is recurrent: each frame updates a hidden state the
		next frame needs. So scoring a frame is a command (`analyze'), its result is a
		query (`last_probability'), and `reset' clears the carried state (CQS audit;
		contract change approved by Larry, 2026-10-05).
	]"
	author: "Larry Rix"

deferred class
	PT_VAD

feature -- Constants

	Frame_samples: INTEGER = 512
			-- 32 ms at 16 kHz.

feature -- Access

	last_probability: REAL_64
			-- Speech probability of the frame given to the last `analyze' (0 before any).

feature -- Detection

	analyze (a_samples: SPECIAL [REAL_32]; a_offset: INTEGER; a_first_sample: INTEGER_64)
			-- Score the frame `a_samples' [a_offset .. a_offset + Frame_samples - 1], which starts at
			-- sample `a_first_sample' of the recording. A stateful detector advances its state here.
		require
			frame_inside: a_offset >= 0 and a_offset + Frame_samples <= a_samples.count
			position_non_negative: a_first_sample >= 0
		deferred
		ensure
			probability_range: last_probability >= 0.0 and last_probability <= 1.0
		end

	reset
			-- Forget any state carried from frame to frame (a new session, a gap in the stream).
		deferred
		ensure
			cleared: last_probability = 0.0
		end

invariant
	probability_range: last_probability >= 0.0 and last_probability <= 1.0

end
