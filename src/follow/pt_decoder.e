note
	description: "[
		Speech recognizer over one rolling window. The app supplies whisper
		through simple_speech (PT_WHISPER_DECODER: greedy, no_context = True,
		prompt = already-read script, word timestamps; spike gotchas 1-2); tests
		use PT_SCRIPTED_DECODER.
	]"
	author: "Larry Rix"

deferred class
	PT_DECODER

feature -- Decoding

	decode (a_samples: SPECIAL [REAL_32]; a_count: INTEGER; a_window_start: INTEGER_64;
			a_prompt: READABLE_STRING_32): PT_HEARD_WORDS
			-- Words heard in the first `a_count' samples of `a_samples', a window starting
			-- at sample `a_window_start'. `a_prompt' is text ALREADY spoken (never upcoming text).
		require
			count_valid: a_count > 0 and a_count <= a_samples.count
			start_non_negative: a_window_start >= 0
		deferred
		ensure
			window_kept: Result.window_start = a_window_start and Result.window_samples = a_count
			words_inside: across 1 |..| Result.count as i all Result.word (i).t1 <= a_count / 16_000 + 0.05 end
		end

end
