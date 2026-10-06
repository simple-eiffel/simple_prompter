note
	description: "[
		Critically damped approach of `value' toward a target: no overshoot, so
		smoothing never makes the display move backward past where it was heading.
	]"
	author: "Larry Rix"

class
	PT_SPRING

create
	make

feature {NONE} -- Initialization

	make (a_omega: REAL_64)
			-- Spring with angular frequency `a_omega' (1/s); higher = snappier.
		require
			positive: a_omega > 0
		do
			omega := a_omega
		ensure
			omega_set: omega = a_omega
			at_rest: value = 0 and rate = 0
		end

feature -- Access

	omega: REAL_64
	value: REAL_64
	rate: REAL_64
			-- d(value)/dt.

feature -- Element change

	step (a_target, a_dt_s: REAL_64)
			-- Advance `a_dt_s' seconds toward `a_target'.
		require
			non_negative: a_dt_s >= 0
		local
			l_math: DOUBLE_MATH
			l_old, l_d, l_decay, l_next, l_low, l_high: REAL_64
		do
			if a_dt_s > 0 then
				create l_math
				l_old := value
				l_d := value - a_target
				l_decay := l_math.exp (- omega * a_dt_s)
				l_next := a_target + (l_d + (rate + omega * l_d) * a_dt_s) * l_decay
					-- Never overshoot or move away (contract): clamp between the old value and the target.
				l_low := l_old.min (a_target)
				l_high := l_old.max (a_target)
				value := l_next.max (l_low).min (l_high)
				rate := (value - l_old) / a_dt_s
			end
		ensure
			no_time_no_move: a_dt_s = 0 implies value = old value
			not_farther: (a_target - value).abs <= (a_target - old value).abs + 1.0e-9
			no_overshoot: (old value <= a_target implies value <= a_target + 1.0e-9) and
					(old value >= a_target implies value >= a_target - 1.0e-9)
		end

	reset (a_value: REAL_64)
			-- Jump to `a_value' at rest.
		do
			value := a_value
			rate := 0
		ensure
			placed: value = a_value
			at_rest: rate = 0
		end

invariant
	omega_positive: omega > 0

end
