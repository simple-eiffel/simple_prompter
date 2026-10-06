note
	description: "[
		Voice activity from Silero (simple_speech_gpu's SPEECH_SILERO_VAD). The native
		model forgets its recurrent state on every call, so each new frame is scored as
		the end of a half-second trailing window kept here; `reset' starts the window
		empty (a new stream).
	]"
	author: "Larry Rix"

class
	PT_SILERO_VAD

inherit
	PT_VAD

create
	make

feature {NONE} -- Initialization

	make (a_model_path: READABLE_STRING_32)
		require
			path_present: not a_model_path.is_empty
		do
			create detector.make (a_model_path)
			create ring.make_filled (0.0, Context_samples)
		end

feature -- Constants

	Context_samples: INTEGER = 8192
			-- Half a second (16 chunks of 512).

feature -- Access

	detector: SPEECH_SILERO_VAD

	is_loaded: BOOLEAN
		do
			Result := detector.is_loaded
		end

feature -- Detection

	analyze (a_samples: SPECIAL [REAL_32]; a_offset: INTEGER; a_first_sample: INTEGER_64)
			-- Slide the frame into the trailing window and score the window's last chunk.
		do
			ring.move_data (Frame_samples, 0, Context_samples - Frame_samples)
			ring.copy_data (a_samples, a_offset, Context_samples - Frame_samples, Frame_samples)
			filled := (filled + Frame_samples).min (Context_samples)
			if detector.is_loaded then
				detector.score (ring, Context_samples - filled, filled)
				last_probability := detector.last_probability
			else
				last_probability := 0.0
			end
		end

	reset
			-- Forget the trailing window.
		do
			ring.fill_with (0.0, 0, Context_samples - 1)
			filled := 0
			last_probability := 0.0
		end

feature {NONE} -- Implementation

	ring: SPECIAL [REAL_32]
			-- The most recent `Context_samples' samples, newest last.

	filled: INTEGER
			-- How much of `ring' holds real samples.

invariant
	filled_range: filled >= 0 and filled <= Context_samples

end
