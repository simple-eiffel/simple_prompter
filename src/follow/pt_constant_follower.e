note
	description: "Classic fixed-speed prompter; ignores the voice."
	author: "Larry Rix"

class
	PT_CONSTANT_FOLLOWER

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

feature -- Access

	words_per_second: REAL_64
			-- Configured speed.

feature -- Input

	on_voice (a_frame: PT_VOICE_FRAME)
			-- Remember whether the reader is speaking (display only).
		do
			is_speaking := a_frame.is_speech
		end

	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Ignored in constant mode.
		do
		end

feature -- Motion

	advance (a_dt_s: REAL_64)
			-- Move at the configured speed unless held.
		do
			caret_changed := False
			if is_held then
				velocity := 0
			else
				velocity := words_per_second
				target := (target + words_per_second * a_dt_s).min (word_count)
			end
		ensure then
			constant_rate: (not is_held and old target + words_per_second * a_dt_s <= word_count)
					implies (target - (old target + words_per_second * a_dt_s)).abs < 1.0e-9
		end

feature -- Element change

	set_wpm (a_wpm: INTEGER)
			-- Change speed.
		require
			wpm_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		do
			words_per_second := a_wpm / 60.0
		ensure
			rate_set: words_per_second = a_wpm / 60.0
			target_kept: target = old target
		end

invariant
	rate_positive: words_per_second > 0

end
