note
	description: "[
		Follows the spoken word. While speaking, velocity = measured rate plus a
		spring term toward the aligned word (never negative). After the last
		anchored alignment it coasts at the measured rate for at most Coast_limit
		seconds, then holds still (ad-libs don't drag the script). Before the
		first alignment it behaves like voice-gated at the fallback speed.
		In a pause shortly after an anchor it closes the gap to the word last
		said, never beyond it: the measured rate includes pauses, so a follower
		that only moved while sound was heard fell further behind every sentence
		(live replay of larry_read_01, 2026-10-06).
	]"
	author: "Larry Rix"

class
	PT_TRACKING_FOLLOWER

inherit
	PT_FOLLOWER
		redefine
			set_caret
		end

create
	make

feature {NONE} -- Initialization

	make (a_word_count: INTEGER; a_fallback_wpm: INTEGER)
			-- Follower over `a_word_count' words; `a_fallback_wpm' until the first alignment.
		require
			words_non_negative: a_word_count >= 0
			wpm_range: a_fallback_wpm >= 40 and a_fallback_wpm <= 400
		do
			word_count := a_word_count
			fallback_rate := a_fallback_wpm / 60.0
			measured_rate := fallback_rate
			is_held := True
		ensure
			at_start: target = 0
			held_initially: is_held
			fallback_set: fallback_rate = a_fallback_wpm / 60.0
		end

feature -- Constants

	Coast_limit: REAL_64 = 1.5
	Min_rate: REAL_64 = 1.0
	Max_rate_factor: REAL_64 = 3.0
			-- Headroom to catch up (1.6 in spec 07 left the live follower 10-80 words behind).
	Snap_lag: INTEGER = 8
			-- Words behind a fresh anchor (about a line) beyond which the follower jumps instead of steering.
	Steer_gain: REAL_64 = 1.5
			-- Extra words per second per word of lag behind the aligned word.

feature -- Access

	fallback_rate: REAL_64
			-- Words per second used before the first alignment.

	measured_rate: REAL_64
			-- Speaking rate from alignments (words per second).

	aligned_word: INTEGER
			-- Word index of the latest anchored alignment.

	seconds_since_anchor: REAL_64
			-- Time since the latest anchored alignment.

	has_alignment: BOOLEAN
			-- Has an anchored alignment arrived since the last caret change?

feature -- Input

	on_voice (a_frame: PT_VOICE_FRAME)
			-- Remember whether the reader is speaking.
		do
			is_speaking := a_frame.is_speech
		end

	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Adopt an anchored estimate as the steering goal.
		do
			if a_alignment.is_anchored then
				aligned_word := a_alignment.word_index.min (word_count)
				if a_alignment.rate_wps > 0 then
					measured_rate := a_alignment.rate_wps.max (Min_rate)
				end
				seconds_since_anchor := 0
				has_alignment := True
			end
		end

feature -- Motion

	advance (a_dt_s: REAL_64)
			-- Steer toward the aligned word at the measured rate; coast, then hold.
		do
			caret_changed := False
			seconds_since_anchor := seconds_since_anchor + a_dt_s
			if is_held then
				velocity := 0
			elseif has_alignment and seconds_since_anchor > Coast_limit then
				velocity := 0
			elseif not is_speaking then
				if has_alignment then
						-- A pause: catch up to the word last said, never past it.
					velocity := (Steer_gain * (aligned_word - target)).max (0.0).min (rate_cap)
				else
					velocity := 0
				end
			elseif not has_alignment then
				velocity := fallback_rate.min (rate_cap)
			else
				velocity := (measured_rate + Steer_gain * (aligned_word - target)).max (0.0).min (rate_cap)
			end
			if not is_held and has_alignment and seconds_since_anchor <= Coast_limit and aligned_word - target > Snap_lag then
					-- More than a line behind a fresh anchor (a skipped paragraph, a late start):
					-- jump to the reader; the scroll's spring turns the jump into a quick glide.
				target := aligned_word.to_double.min (word_count)
			end
			if not is_held then
				if is_speaking then
					target := (target + velocity * a_dt_s).min (word_count)
				else
					target := (target + velocity * a_dt_s).min (aligned_word.to_double.max (target)).min (word_count)
				end
			end
		ensure then
			coast_limited: (has_alignment and seconds_since_anchor > Coast_limit) implies velocity = 0
			rate_capped: velocity <= Max_rate_factor * measured_rate.max (Min_rate)
			clock_runs: seconds_since_anchor = old seconds_since_anchor + a_dt_s
		end

feature -- Control

	set_caret (a_index: INTEGER)
			-- Restart: forget the old alignment; steer from the caret.
		do
			Precursor (a_index)
			aligned_word := a_index
			has_alignment := False
			seconds_since_anchor := 0
		end

feature {NONE} -- Implementation

	rate_cap: REAL_64
			-- Highest velocity allowed.
		do
			Result := Max_rate_factor * measured_rate.max (Min_rate)
		end

invariant
	rates_positive: fallback_rate > 0 and measured_rate > 0
	aligned_in_script: aligned_word >= 0 and aligned_word <= word_count
	clock_non_negative: seconds_since_anchor >= 0

end
