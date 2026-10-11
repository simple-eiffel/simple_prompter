note
	description: "[
		Watches the microphone's sound while a take is recorded and says when it is garbled
		(0.5.7). Reel 4 "Dumb Jesus" (2026-10-11) came through "Microphone (NVIDIA Broadcast)"
		as broadband noise gated by the speech, about -7 dB: no voice in it, so nothing for
		voice following, the analyzer or the captions, and Larry, busy reading, could not
		tell. In seven healthy takes (2026-10-10/11) no 32 ms frame reached 0.28 RMS; the
		garbled take sat near 0.45. Frames at `Garbled_level' or above adding up to
		`Garbled_seconds' within the last `Window_seconds' mean the sound is garbled; it
		stays so until `reset'.
	]"
	author: "Larry Rix"

class
	PT_SOUND_GUARD

create
	make

feature {NONE} -- Initialization

	make
			-- A guard that has heard nothing.
		do
			create loud_times.make (Window_frames)
		ensure
			fresh: not is_garbled and loud_seconds = 0
		end

feature -- Constants

	Garbled_level: REAL_64 = 0.35
			-- Frame RMS (0..1) no healthy voice reached (0.28 at most in seven takes).

	Garbled_seconds: REAL_64 = 2.0
			-- Loud time within the window that means garbled.

	Window_seconds: REAL_64 = 10.0
			-- How far back loud frames count.

	Frame_seconds: REAL_64 = 0.032
			-- One VAD frame (512 samples at 16 kHz).

	Window_frames: INTEGER = 313
			-- Frames in `Window_seconds'.

feature -- Status

	is_garbled: BOOLEAN
			-- Has the sound been garbled since the last `reset'?

	garbled_at: REAL_64
			-- Recording time (seconds) when it was found garbled.

	loud_seconds: REAL_64
			-- Loud time within the window, as of the last frame.
		do
			Result := loud_times.count * Frame_seconds
		ensure
			non_negative: Result >= 0
		end

feature -- Element change

	observe (a_frame: PT_VOICE_FRAME)
			-- Take in one frame of the microphone's sound.
		do
			if not loud_times.is_empty and then a_frame.seconds < loud_times.last then
					-- A new capture: its clock starts again at zero.
				loud_times.wipe_out
			end
			if a_frame.level >= Garbled_level then
				loud_times.extend (a_frame.seconds)
			end
			from until loud_times.is_empty or else loud_times.first > a_frame.seconds - Window_seconds loop
				loud_times.start
				loud_times.remove
			end
			if not is_garbled and loud_seconds >= Garbled_seconds then
				is_garbled := True
				garbled_at := a_frame.seconds
			end
		ensure
			latched: old is_garbled implies is_garbled
		end

	reset
			-- Forget what was heard (a new take).
		do
			loud_times.wipe_out
			is_garbled := False
			garbled_at := 0
		ensure
			clear: not is_garbled and loud_seconds = 0
		end

feature {NONE} -- Implementation

	loud_times: ARRAYED_LIST [REAL_64]
			-- Start times of the loud frames within the window, oldest first.

invariant
	garbled_time_non_negative: garbled_at >= 0

end
