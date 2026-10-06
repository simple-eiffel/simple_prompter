note
	description: "[
		The final video as an ordered list of source intervals, plus the mapping
		from recording time to output time and the complement ("the edit floor").
	]"
	author: "Larry Rix"

class
	PT_CUT_LIST

create
	make

feature {NONE} -- Initialization

	make
		do
			create cut_list.make (16)
		ensure
			empty: count = 0
		end

feature -- Access

	count: INTEGER
		do
			Result := cut_list.count
		end

	cut (a_index: INTEGER): PT_CUT
		require
			valid_index: a_index >= 1 and a_index <= count
		do
			Result := cut_list [a_index]
		end

	output_duration: REAL_64
			-- Length of the final video.
		do
			across cut_list as ic loop
				Result := Result + ic.span.duration
			end
		ensure
			sum: (Result - span_total (cuts_model)).abs < 1.0e-9
		end

	is_kept (a_src: INTEGER; a_rt: REAL_64): BOOLEAN
			-- Is time `a_rt' of source `a_src' in the final video?
		do
			Result := across cut_list as ic some ic.src = a_src and ic.span.contains (a_rt) end
		end

	to_output_time (a_src: INTEGER; a_rt: REAL_64): REAL_64
			-- Where `a_rt' of source `a_src' lands in the final video.
		require
			kept: is_kept (a_src, a_rt)
		local
			l_done: BOOLEAN
		do
			across cut_list as ic until l_done loop
				if ic.src = a_src and ic.span.contains (a_rt) then
					Result := Result + (a_rt - ic.span.t0)
					l_done := True
				else
					Result := Result + ic.span.duration
				end
			end
		ensure
			in_range: Result >= 0 and Result <= output_duration + 1.0e-9
		end

	floor_spans (a_src: INTEGER; a_raw_duration: REAL_64): ARRAYED_LIST [PT_TIME_SPAN]
			-- Parts of source `a_src' (length `a_raw_duration') not in the final video.
		require
			duration_non_negative: a_raw_duration >= 0
		local
			l_kept: ARRAYED_LIST [PT_TIME_SPAN]
			l_at: REAL_64
			i, j: INTEGER
			l_swap: PT_TIME_SPAN
		do
			create Result.make (count + 1)
			create l_kept.make (count)
			across cut_list as ic loop
				if ic.src = a_src then
					l_kept.extend (ic.span)
				end
			end
				-- Order by start (pickups may put a source's spans out of output order).
			from i := 2 until i > l_kept.count loop
				from j := i until j < 2 or else l_kept [j - 1].t0 <= l_kept [j].t0 loop
					l_swap := l_kept [j]
					l_kept [j] := l_kept [j - 1]
					l_kept [j - 1] := l_swap
					j := j - 1
				end
				i := i + 1
			end
			across l_kept as ic loop
				if ic.t0 > l_at then
					Result.extend (create {PT_TIME_SPAN}.make (l_at, ic.t0.min (a_raw_duration)))
				end
				l_at := l_at.max (ic.t1)
			end
			if l_at < a_raw_duration then
				Result.extend (create {PT_TIME_SPAN}.make (l_at, a_raw_duration))
			end
		ensure
			complement: ((source_kept_duration (a_src) + list_total (Result)) - a_raw_duration).abs < 1.0e-6
		end

	source_kept_duration (a_src: INTEGER): REAL_64
			-- Total kept time from source `a_src'.
		do
			across cut_list as ic loop
				if ic.src = a_src then
					Result := Result + ic.span.duration
				end
			end
		end

feature -- Model

	cuts_model: MML_SEQUENCE [PT_CUT]
		do
			create Result
			across cut_list as ic loop
				Result := Result & ic
			end
		ensure
			same_count: Result.count = count
		end

	words_model: MML_SEQUENCE [PT_WORD_ID]
			-- Word ids carried by the final video, in output order.
		do
			create Result
			across cut_list as ic loop
				across ic.word_ids as ic_id loop
					Result := Result & ic_id
				end
			end
		end

feature -- Model helpers

	span_total (a_cuts: MML_SEQUENCE [PT_CUT]): REAL_64
			-- Sum of span durations in `a_cuts'.
		local
			i: INTEGER
		do
			from i := 1 until i > a_cuts.count loop
				Result := Result + a_cuts [i].span.duration
				i := i + 1
			end
		end

	list_total (a_spans: LIST [PT_TIME_SPAN]): REAL_64
			-- Sum of durations in `a_spans'.
		do
			across a_spans as ic loop
				Result := Result + ic.duration
			end
		end

feature -- Element change

	extend (a_cut: PT_CUT)
			-- Append the next cut in output (script) order.
		require
			script_order: count = 0 or else a_cut.first_word_index > cut (count).last_word_index
		do
			cut_list.extend (a_cut)
		ensure
			appended: (cuts_model |=| (old cuts_model & a_cut))
		end

feature {NONE} -- Implementation

	cut_list: ARRAYED_LIST [PT_CUT]

invariant
	count_non_negative: count >= 0

end
