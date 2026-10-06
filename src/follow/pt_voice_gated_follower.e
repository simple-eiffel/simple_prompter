note
	description: "[
		Fixed speed while the VAD says speech. Velocity ramps up over Ramp_up_s
		when speech starts and down over Ramp_down_s when it stops (NFR-001 pause
		<= 250 ms), the simple_speed_reader brake-glide idea applied to the speech gate.
	]"
	author: "Larry Rix"

class
	PT_VOICE_GATED_FOLLOWER

inherit
	PT_FOLLOWER

create
	make

feature {NONE} -- Initialization

	make (a_word_count: INTEGER; a_wpm: INTEGER)
			-- Follower over `a_word_count' words at `a_wpm', held at the start.
		require
			words_non_negative: a_word_count >= 0
			wpm_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		do
			word_count := a_word_count
			words_per_second := a_wpm / 60.0
			is_held := True
		ensure
			at_start: target = 0
			held_initially: is_held
			rate_set: words_per_second = a_wpm / 60.0
		end

feature -- Constants

	Min_wpm: INTEGER = 40
	Max_wpm: INTEGER = 400
	Ramp_up_s: REAL_64 = 0.15
	Ramp_down_s: REAL_64 = 0.20

feature -- Access

	words_per_second: REAL_64
			-- Speed while speaking.

feature -- Status

	ramp_finished: BOOLEAN
			-- Has velocity reached its gated goal (full speed while speaking, 0 while silent)?
		do
			if is_speaking then
				Result := velocity >= words_per_second
			else
				Result := velocity = 0
			end
		end

feature -- Input

	on_voice (a_frame: PT_VOICE_FRAME)
			-- Gate on the VAD decision.
		do
			is_speaking := a_frame.is_speech
		end

	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Ignored in voice-gated mode.
		do
		end

feature -- Motion

	advance (a_dt_s: REAL_64)
			-- Ramp velocity toward the gate's goal, then move.
		do
			caret_changed := False
			if is_held then
				velocity := 0
			else
				if is_speaking then
					velocity := (velocity + words_per_second * a_dt_s / Ramp_up_s).min (words_per_second)
				else
					velocity := (velocity - words_per_second * a_dt_s / Ramp_down_s).max (0.0)
				end
				target := (target + velocity * a_dt_s).min (word_count)
			end
		ensure then
			silent_stops: (not is_speaking and ramp_finished) implies velocity = 0
			speed_capped: velocity <= words_per_second
		end

invariant
	rate_positive: words_per_second > 0

end
