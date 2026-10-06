note
	description: "Follow mode codes (reached as {PT_FOLLOW_MODE}.Constant etc.)."
	author: "Larry Rix"

class
	PT_FOLLOW_MODE

feature -- Constants

	Constant: INTEGER = 1
			-- Fixed speed, ignores the voice.

	Voice_gated: INTEGER = 2
			-- Fixed speed while VAD says speech.

	Tracking: INTEGER = 3
			-- Follows the spoken word (GPU ASR + aligner).

end
