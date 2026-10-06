note
	description: "[
		Recording time from the ffmpeg tee file: rt = bytes / 64,000 (16 kHz mono
		32-bit float). Between file observations, rt is interpolated from the
		monotone clock, bounded by Max_interpolation_s. The single place where
		bytes become seconds (spec D-T02, A-101).
	]"
	author: "Larry Rix"

class
	PT_RECORDING_CLOCK

create
	make

feature {NONE} -- Initialization

	make
			-- Clock at rt 0.
		do
		ensure
			at_zero: rt = 0 and byte_count = 0 and observed_at_ms = 0
		end

feature -- Constants

	Bytes_per_second: INTEGER = 64_000
	Max_interpolation_s: REAL_64 = 0.25
			-- To be confirmed from spike T-0 (tail flush granularity).

feature -- Access

	byte_count: INTEGER_64
			-- Tee file size at the last observation.

	observed_at_ms: REAL_64
			-- Monotone clock time of the last observation.

	rt: REAL_64
			-- Recording time at the last observation, seconds.

	sample_count: INTEGER_64
			-- Samples (16 kHz) at the last observation: the clock the speech pipeline counts in.
		do
			Result := byte_count // 4
		ensure
			non_negative: Result >= 0
		end

	rt_at (a_now_ms: REAL_64): REAL_64
			-- Recording time at clock time `a_now_ms', interpolated.
		require
			after: a_now_ms >= observed_at_ms
		do
			Result := rt + ((a_now_ms - observed_at_ms) / 1000.0).min (Max_interpolation_s)
		ensure
			not_before: Result >= rt
			bounded: Result <= rt + Max_interpolation_s
		end

feature -- Element change

	observe_bytes (a_total: INTEGER_64; a_at_ms: REAL_64)
			-- The tee file holds `a_total' bytes at clock time `a_at_ms'.
		require
			monotone: a_total >= byte_count
			time_ok: a_at_ms >= observed_at_ms
		do
			byte_count := a_total
			observed_at_ms := a_at_ms
			rt := a_total / Bytes_per_second
		ensure
			counted: byte_count = a_total
			time_set: observed_at_ms = a_at_ms
			rt_exact: (rt - a_total / Bytes_per_second).abs < 1.0e-9
		end

invariant
	rt_non_negative: rt >= 0
	bytes_non_negative: byte_count >= 0
	time_non_negative: observed_at_ms >= 0

end
