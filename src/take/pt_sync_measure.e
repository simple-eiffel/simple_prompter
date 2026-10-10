note
	description: "[
		Measures a take's picture-to-sound sync from claps (0.3.6), the way it was
		first measured by hand (2026-10-10): the clap's sound is the sharpest loud
		onset in the microphone copy (tee, 16 kHz); its picture is the frame where
		the hands meet - the last frame of the closing burst of motion, after
		which the picture goes still. Delay = picture time - sound time, half a
		frame interval taken off (the hands met somewhere during that frame).
		Pure: the caller hands in the samples and, per clap, small gray frames
		(PT_SYNC_MEASURER reads them with ffmpeg).
	]"
	author: "Larry Rix"

class
	PT_SYNC_MEASURE

create
	make

feature {NONE} -- Initialization

	make
		do
			create claps.make (Most_claps)
			create delays.make (Most_claps)
		ensure
			nothing_yet: claps.is_empty and delays.is_empty
		end

feature -- Constants

	Tee_rate: INTEGER = 16_000
	Most_claps: INTEGER = 6
			-- Loud onsets tried (speech can sneak in; its picture shows no clap and is dropped).
	Clap_level: REAL_64 = 0.15
			-- Loudest sample a clap reaches at least (of full scale).
	Clap_gap_seconds: REAL_64 = 0.3
	Frame_rate: INTEGER = 60
			-- Frames per second the caller's frames are spaced at.
	Frames_before_seconds: REAL_64 = 0.3
			-- The caller's frames start this long before the clap ...
	Frames_seconds: REAL_64 = 1.2
			-- ... and run this long.
	Still_fraction: REAL_64 = 0.35
			-- After the closing burst, motion below this share of its peak is "the hands met".
	Least_motion: REAL_64 = 1.0
			-- A burst weaker than this (mean gray change, 0..255) is not a clap.
	New_frame_motion: REAL_64 = 0.2
			-- Smaller change than this: a repeated frame (a 30 fps camera in a 60 fps stream).

feature -- Access

	claps: ARRAYED_LIST [REAL_64]
			-- Clap sound times (seconds into the take), earliest first, from `find_claps'.

	delays: ARRAYED_LIST [INTEGER]
			-- Delays (milliseconds) found by `add_clap_frames'.

	delay_ms: INTEGER
			-- The median of `delays', to the nearest 10 ms.
		require
			found: is_found
		local
			l_sorted: SORTED_TWO_WAY_LIST [INTEGER]
		do
			create l_sorted.make
			across delays as ic loop
				l_sorted.extend (ic)
			end
			Result := l_sorted [(l_sorted.count + 1) // 2]
			Result := ((Result / 10).rounded) * 10
		end

	is_found: BOOLEAN
		do
			Result := not delays.is_empty
		end

feature -- Sound

	find_claps (a_samples: SPECIAL [REAL_32]; a_count: INTEGER)
			-- Put in `claps' the onsets of the sharpest loud transients of `a_samples' [0 .. `a_count' - 1].
		require
			count_valid: a_count >= 0 and a_count <= a_samples.count
		local
			l_env: SPECIAL [REAL_64]
			l_n, i, j, l_best, l_hop: INTEGER
			l_pre, l_best_score, l_peak: REAL_64
			l_scores: SPECIAL [REAL_64]
			l_taken: ARRAYED_LIST [INTEGER]
			l_ok: BOOLEAN
		do
			claps.wipe_out
			delays.wipe_out
			l_hop := Tee_rate // 1000
			l_n := a_count // l_hop
			create l_env.make_filled (0.0, l_n.max (1))
			from i := 0 until i >= l_n loop
				l_peak := 0.0
				from j := i * l_hop until j >= (i + 1) * l_hop loop
					l_peak := l_peak.max (a_samples [j].abs)
					j := j + 1
				end
				l_env [i] := l_peak
				i := i + 1
			end
				-- Onset strength: the 1 ms peak against the 30 ms before it, times the peak.
			create l_scores.make_filled (0.0, l_n.max (1))
			l_pre := 0.0
			from i := 0 until i >= l_n loop
				if i >= 30 then
					l_pre := l_pre - l_env [i - 30]
				end
				if l_env [i] >= Clap_level and i >= 30 then
					l_scores [i] := l_env [i] * l_env [i] / (l_pre / 30).max (0.003)
				end
				l_pre := l_pre + l_env [i]
				i := i + 1
			end
			create l_taken.make (Most_claps)
			from until l_taken.count >= Most_claps or l_ok loop
				l_best := -1
				l_best_score := 0.0
				from i := 0 until i >= l_n loop
					if l_scores [i] > l_best_score and then across l_taken as ic all (ic - i).abs > (Clap_gap_seconds * 1000).rounded end then
						l_best := i
						l_best_score := l_scores [i]
					end
					i := i + 1
				end
				if l_best < 0 then
					l_ok := True
				else
					l_taken.extend (l_best)
				end
			end
			across l_taken as ic loop
				claps.extend (onset (a_samples, ic * l_hop, l_env [ic]))
			end
			sort (claps)
		ensure
			few: claps.count <= Most_claps
		end

feature -- Picture

	add_clap_frames (a_clap, a_start: REAL_64; a_frames: SPECIAL [NATURAL_8]; a_frame_size, a_frame_count: INTEGER)
			-- Frames from `a_start' (normally `a_clap' - `Frames_before_seconds'), `Frame_rate' a second,
			-- `a_frame_size' bytes each: if they show hands meeting near `a_clap', add the delay to `delays'.
		require
			start_before_clap: a_start <= a_clap
			size_positive: a_frame_size > 0
			frames_present: a_frame_count * a_frame_size <= a_frames.count
		local
			l_contact: REAL_64
		do
			l_contact := contact_time (a_frames, a_frame_size, a_frame_count, a_start, a_clap)
			if l_contact > 0 then
				delays.extend (((l_contact - a_clap) * 1000).rounded)
			end
		end

	contact_time (a_frames: SPECIAL [NATURAL_8]; a_frame_size, a_frame_count: INTEGER; a_start, a_clap: REAL_64): REAL_64
			-- When the hands met in frames starting at `a_start' (0 when no clap shows).
		require
			size_positive: a_frame_size > 0
			frames_present: a_frame_count * a_frame_size <= a_frames.count
		local
			l_times, l_motion: ARRAYED_LIST [REAL_64]
			i, l_peak_at, k: INTEGER
			l_m, l_peak, l_t, l_interval: REAL_64
			l_gaps: SORTED_TWO_WAY_LIST [REAL_64]
		do
			create l_times.make (a_frame_count)
			create l_motion.make (a_frame_count)
			from i := 1 until i >= a_frame_count loop
				l_m := change (a_frames, (i - 1) * a_frame_size, i * a_frame_size, a_frame_size)
				if l_m > New_frame_motion then
					l_times.extend (a_start + i / Frame_rate)
					l_motion.extend (l_m)
				end
				i := i + 1
			end
				-- The closing burst: the strongest new frame from just before the sound to well after it.
			from i := 1 until i > l_times.count loop
				l_t := l_times [i]
				if l_t >= a_clap - 0.15 and l_t <= a_clap + 0.8 and l_motion [i] > l_peak then
					l_peak := l_motion [i]
					l_peak_at := i
				end
				i := i + 1
			end
			if l_peak >= Least_motion then
					-- The hands met on the last moving frame before the picture goes still.
				from k := l_peak_at + 1 until k > l_times.count or else l_motion [k] < l_peak * Still_fraction loop
					k := k + 1
				end
				if k <= l_times.count and then l_times [k] - l_times [l_peak_at] <= 0.4 then
					create l_gaps.make
					from i := 2 until i > l_times.count loop
						l_gaps.extend (l_times [i] - l_times [i - 1])
						i := i + 1
					end
					l_interval := 1 / Frame_rate
					if not l_gaps.is_empty then
						l_interval := l_gaps [(l_gaps.count + 1) // 2]
					end
					Result := l_times [k - 1] - l_interval / 2
				end
			end
		ensure
			none_or_after_start: Result = 0 or Result > a_start
		end

feature {NONE} -- Implementation

	onset (a_samples: SPECIAL [REAL_32]; a_peak_sample: INTEGER; a_peak: REAL_64): REAL_64
			-- The first sample in the 10 ms before the 1 ms block at `a_peak_sample' louder than half `a_peak'.
		local
			i, l_from: INTEGER
			l_done: BOOLEAN
		do
			l_from := (a_peak_sample - Tee_rate // 100).max (0)
			Result := a_peak_sample / Tee_rate
			from i := l_from until l_done or i >= (a_peak_sample + Tee_rate // 1000).min (a_samples.count) loop
				if a_samples [i].abs >= a_peak / 2 then
					Result := i / Tee_rate
					l_done := True
				end
				i := i + 1
			end
		end

	change (a_frames: SPECIAL [NATURAL_8]; a_from, a_to, a_size: INTEGER): REAL_64
			-- Mean absolute gray difference between the frames at byte `a_from' and `a_to'.
		local
			i: INTEGER
			l_sum: INTEGER_64
		do
			from i := 0 until i >= a_size loop
				l_sum := l_sum + (a_frames [a_from + i].to_integer_32 - a_frames [a_to + i].to_integer_32).abs
				i := i + 1
			end
			Result := l_sum / a_size
		end

	sort (a_list: ARRAYED_LIST [REAL_64])
			-- Earliest first.
		local
			l_sorted: SORTED_TWO_WAY_LIST [REAL_64]
		do
			create l_sorted.make
			across a_list as ic loop
				l_sorted.extend (ic)
			end
			a_list.wipe_out
			across l_sorted as ic loop
				a_list.extend (ic)
			end
		end

end
