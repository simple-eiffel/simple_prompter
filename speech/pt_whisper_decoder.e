note
	description: "[
		Whisper on the GPU behind PT_DECODER (simple_speech_gpu's SPEECH_GPU_WHISPER):
		decodes one rolling window with no carried context, prompted only with text
		already read. Word times are clamped inside the window, as the contract asks.
		Lives on the speech worker's processor: loading and decoding block.
	]"
	author: "Larry Rix"

class
	PT_WHISPER_DECODER

inherit
	PT_DECODER

create
	make

feature {NONE} -- Initialization

	make (a_model_path: READABLE_STRING_32)
			-- Load the model on the GPU.
		require
			path_present: not a_model_path.is_empty
		do
			create recognizer.make (a_model_path, True)
			create normalizer
		end

feature -- Access

	recognizer: SPEECH_GPU_WHISPER

	is_loaded: BOOLEAN
		do
			Result := recognizer.is_loaded
		end

feature -- Commands

	warm_up
			-- Run the GPU kernels once (the first decode is several times slower).
		require
			loaded: is_loaded
		local
			l_quiet: SPECIAL [REAL_32]
		do
			create l_quiet.make_filled (0.0, 16_000)
			recognizer.decode (l_quiet, l_quiet.count, "")
		end

feature -- Decoding

	decode (a_samples: SPECIAL [REAL_32]; a_count: INTEGER; a_window_start: INTEGER_64;
			a_prompt: READABLE_STRING_32): PT_HEARD_WORDS
			-- Words heard in the window, times in seconds from the window's start.
		local
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_limit, l_t0, l_t1: REAL_64
		do
			create l_words.make (16)
			if recognizer.is_loaded then
				recognizer.decode (a_samples, a_count, a_prompt)
				l_limit := a_count / 16_000
				across recognizer.last_words as ic loop
					l_t0 := ic.t0.min (l_limit)
					l_t1 := ic.t1.max (l_t0).min (l_limit)
					l_words.extend (create {PT_HEARD_WORD}.make (ic.text, normalizer.normalized (ic.text), l_t0, l_t1, ic.probability))
				end
			end
			create Result.make (a_window_start, a_count, l_words)
		end

feature {NONE} -- Implementation

	normalizer: PT_NORMALIZER

end
