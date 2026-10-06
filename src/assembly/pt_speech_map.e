note
	description: "[
		VAD speech runs over a recording: ordered, disjoint spans within
		`duration'. Everything outside a span is silence (where cuts belong).
	]"
	author: "Larry Rix"

class
	PT_SPEECH_MAP

create
	make

feature {NONE} -- Initialization

	make (a_duration: REAL_64)
			-- Map of a recording `a_duration' seconds long, no speech yet.
		require
			non_negative: a_duration >= 0
		do
			duration := a_duration
			create span_list.make (64)
		ensure
			duration_set: duration = a_duration
			no_speech: span_count = 0
		end

feature -- Access

	duration: REAL_64

	span_count: INTEGER
		do
			Result := span_list.count
		end

	span (a_index: INTEGER): PT_TIME_SPAN
		require
			valid_index: a_index >= 1 and a_index <= span_count
		do
			Result := span_list [a_index]
		end

	last_end: REAL_64
			-- End of the last speech span (0 when none).
		do
			if not span_list.is_empty then
				Result := span_list.last.t1
			end
		end

feature -- Queries

	is_silent_at (a_t: REAL_64): BOOLEAN
			-- Is `a_t' outside every speech span?
		require
			in_range: a_t >= 0 and a_t <= duration
		do
			Result := not across span_list as ic some ic.contains (a_t) end
		ensure
			definition: Result = not across 1 |..| span_count as i some span (i).contains (a_t) end
		end

	silence_around (a_t: REAL_64): detachable PT_TIME_SPAN
			-- Maximal silent interval containing `a_t', if `a_t' is silent.
		require
			in_range: a_t >= 0 and a_t <= duration
		local
			l_from, l_to: REAL_64
		do
			if is_silent_at (a_t) then
				l_to := duration
				across span_list as ic loop
					if ic.t1 < a_t then
						l_from := ic.t1
					elseif ic.t0 > a_t and ic.t0 < l_to then
						l_to := ic.t0
					end
				end
				create Result.make (l_from, l_to)
			end
		ensure
			only_when_silent: attached Result implies is_silent_at (a_t)
			contains_t: attached Result as al_r implies al_r.contains (a_t)
		end

feature -- Model

	spans_model: MML_SEQUENCE [PT_TIME_SPAN]
		do
			create Result
			across span_list as ic loop
				Result := Result & ic
			end
		ensure
			same_count: Result.count = span_count
		end

feature -- Element change

	extend_span (a_span: PT_TIME_SPAN)
			-- Add the next speech span.
		require
			after_previous: a_span.t0 >= last_end
			within: a_span.t1 <= duration
		do
			span_list.extend (a_span)
		ensure
			appended: (spans_model |=| (old spans_model & a_span))
		end

feature {NONE} -- Implementation

	span_list: ARRAYED_LIST [PT_TIME_SPAN]

invariant
	duration_non_negative: duration >= 0
	within: last_end <= duration

end
