note
	description: "[
		Checks before recording (FR-NEW-003): ffmpeg found, devices present,
		model present (Tracking), enough disk for the planned length at the
		measured bitrate plus a margin. Inputs are injected, so it is pure.
	]"
	author: "Larry Rix"

class
	PT_PREFLIGHT

create
	make

feature {NONE} -- Initialization

	make
		do
			create problems.make (0)
		ensure
			no_problems: problems.is_empty
		end

feature -- Constants

	Margin_minutes: INTEGER = 10

feature -- Access

	problems: ARRAYED_LIST [STRING_32]
			-- Human-readable problems from the last `check_ready'.

	required_bytes (a_bitrate_bps: INTEGER_64; a_minutes: INTEGER): INTEGER_64
			-- Disk needed for `a_minutes' plus the margin at `a_bitrate_bps'.
		require
			bitrate_positive: a_bitrate_bps > 0
			minutes_non_negative: a_minutes >= 0
		do
			Result := a_bitrate_bps // 8 * 60 * (a_minutes + Margin_minutes)
		ensure
			positive: Result > 0
		end

feature -- Status

	is_ready: BOOLEAN
		do
			Result := problems.is_empty
		end

feature -- Basic operations

	check_ready (a_ffmpeg_found, a_devices_present, a_model_needed, a_model_found: BOOLEAN;
			a_free_bytes, a_bitrate_bps: INTEGER_64; a_minutes: INTEGER)
			-- Evaluate readiness.
		require
			free_non_negative: a_free_bytes >= 0
			bitrate_positive: a_bitrate_bps > 0
			minutes_non_negative: a_minutes >= 0
		do
			create problems.make (4)
			if not a_ffmpeg_found then
				problems.extend ({STRING_32} "ffmpeg was not found")
			end
			if not a_devices_present then
				problems.extend ({STRING_32} "the camera or microphone is not connected")
			end
			if a_model_needed and not a_model_found then
				problems.extend ({STRING_32} "the speech model is missing (Tracking needs it; Voice-gated does not)")
			end
			if a_free_bytes < required_bytes (a_bitrate_bps, a_minutes) then
				problems.extend ({STRING_32} "not enough disk space for this recording plus 10 minutes")
			end
		ensure
			ready_iff_no_problems: is_ready = problems.is_empty
			ffmpeg_reported: not a_ffmpeg_found implies not is_ready
			disk_reported: a_free_bytes < required_bytes (a_bitrate_bps, a_minutes) implies not is_ready
		end

end
