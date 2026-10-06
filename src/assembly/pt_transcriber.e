note
	description: "[
		Full-recording speech pass for analysis: a VAD speech map plus every word
		heard, with absolute times (window start 0). The worker exe supplies
		whisper through simple_speech (PT_WHISPER_TRANSCRIBER); tests use
		PT_SCRIPTED_TRANSCRIBER.
	]"
	author: "Larry Rix"

deferred class
	PT_TRANSCRIBER

feature -- Access

	last_map: detachable PT_SPEECH_MAP
			-- Speech map from the last successful `transcribe'.

	last_heard: detachable PT_HEARD_WORDS
			-- Words from the last successful `transcribe' (times are absolute seconds).

	last_error: detachable STRING_32
			-- Why the last `transcribe' failed.

feature -- Status

	is_success: BOOLEAN
			-- Did the last `transcribe' succeed?

feature -- Basic operations

	transcribe (a_audio_path: READABLE_STRING_32; a_duration: REAL_64)
			-- Transcribe the recording at `a_audio_path' (`a_duration' seconds long).
		require
			path_present: not a_audio_path.is_empty
			duration_positive: a_duration > 0
		deferred
		ensure
			outcome: is_success xor attached last_error
			map_on_success: is_success implies (attached last_map as al_map and then al_map.duration = a_duration)
			words_on_success: is_success implies attached last_heard
		end

end
