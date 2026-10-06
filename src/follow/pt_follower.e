note
	description: "[
		Follow policy: turns voice frames and alignments into a scroll target
		(fractional word position) and velocity. Inputs change intent only;
		motion happens in `advance'. The target never moves backward except by
		an explicit caret change (DR-015).
	]"
	author: "Larry Rix"

deferred class
	PT_FOLLOWER

feature -- Access

	target: REAL_64
			-- Words already read (fractional). The reader is on word floor (target) + 1; a
			-- restart at caret word k sets the target to k - 1 (one convention with
			-- PT_ALIGNER.position, review H1).

	velocity: REAL_64
			-- Words per second.

	word_count: INTEGER
			-- Words in the script being followed.

feature -- Status

	is_held: BOOLEAN
			-- Is motion frozen?

	caret_changed: BOOLEAN
			-- Did the last command move the target by caret (the only backward path)?

	is_speaking: BOOLEAN
			-- Did the last voice frame say speech?

feature -- Input

	on_voice (a_frame: PT_VOICE_FRAME)
			-- Take a VAD frame into account.
		deferred
		ensure
			position_untouched: target = old target
		end

	on_alignment (a_alignment: PT_ALIGNMENT)
			-- Take an aligner estimate into account.
		deferred
		ensure
			position_untouched: target = old target
		end

feature -- Motion

	advance (a_dt_s: REAL_64)
			-- Move `a_dt_s' seconds forward in time.
		require
			non_negative: a_dt_s >= 0
		deferred
		ensure
			held_frozen: is_held implies target = old target
			never_backward: target >= old target
			end_clamped: target <= word_count
			velocity_non_negative: velocity >= 0
		end

feature -- Control

	hold
			-- Freeze motion.
		do
			is_held := True
			velocity := 0
			caret_changed := False
		ensure
			held: is_held
			stopped: velocity = 0
			target_kept: target = old target
		end

	release
			-- Allow motion.
		do
			is_held := False
		ensure
			running: not is_held
			target_kept: target = old target
		end

	set_caret (a_index: INTEGER)
			-- Set the words-read target to `a_index' (caret word k: `a_index' = k - 1).
			-- The only way to move backward.
		require
			valid: a_index >= 0 and a_index <= word_count
		do
			target := a_index
			caret_changed := True
		ensure
			placed: target = a_index.to_double
			flagged: caret_changed
		end

	rescale (a_word_count: INTEGER)
			-- The script was revised to `a_word_count' words; clamp the target.
		require
			non_negative: a_word_count >= 0
		do
			word_count := a_word_count
			target := target.min (a_word_count)
		ensure
			resized: word_count = a_word_count
			clamped: target = (old target).min (a_word_count)
		end

invariant
	velocity_non_negative: velocity >= 0
	held_still: is_held implies velocity = 0
	target_range: target >= 0 and target <= word_count
	word_count_non_negative: word_count >= 0

end
