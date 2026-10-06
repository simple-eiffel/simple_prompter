note
	description: "A snapshot of recording health for the pill (REC dot, drop warning)."
	author: "Larry Rix"

class
	PT_RECORDER_HEALTH

create
	make

feature {NONE} -- Initialization

	make (a_alive: BOOLEAN; a_tee_bytes_per_s, a_drop_ratio: REAL_64; a_last_error: detachable READABLE_STRING_32)
		require
			rate_non_negative: a_tee_bytes_per_s >= 0
			drop_range: a_drop_ratio >= 0.0 and a_drop_ratio <= 1.0
		do
			is_alive := a_alive
			tee_bytes_per_s := a_tee_bytes_per_s
			drop_ratio := a_drop_ratio
			if attached a_last_error as al_e then
				last_error := al_e.to_string_32
			end
		ensure
			alive_set: is_alive = a_alive
			rate_set: tee_bytes_per_s = a_tee_bytes_per_s
			drop_set: drop_ratio = a_drop_ratio
		end

feature -- Constants

	Drop_warning: REAL_64 = 0.005
	Expected_bytes_per_s: REAL_64 = 64_000.0

feature -- Access

	tee_bytes_per_s: REAL_64
	drop_ratio: REAL_64
	last_error: detachable STRING_32

feature -- Status

	is_alive: BOOLEAN

	is_stalled: BOOLEAN
			-- Alive but the tee is not flowing.
		do
			Result := is_alive and tee_bytes_per_s < Expected_bytes_per_s / 2
		end

	needs_drop_warning: BOOLEAN
		do
			Result := drop_ratio > Drop_warning
		end

invariant
	rate_non_negative: tee_bytes_per_s >= 0
	drop_range: drop_ratio >= 0.0 and drop_ratio <= 1.0

end
