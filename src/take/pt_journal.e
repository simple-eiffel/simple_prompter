note
	description: "[
		Append-only, rt-ordered Take Studio event log. When persistent, each event
		is written as one JSONL line and flushed immediately, so a crash loses at
		most a torn final line, which replay skips and counts (FR-T09).
		There are no remove/replace features (DR-006).
	]"
	author: "Larry Rix"

class
	PT_JOURNAL

create
	make_in_memory, make_on_file

feature {NONE} -- Initialization

	make_in_memory
			-- Journal without persistence (practice log off, tests).
		do
			create event_list.make (64)
			create codec.make
			create trace_buffer.make (4096)
		ensure
			empty: count = 0
			memory_only: not is_persistent
		end

	make_on_file (a_path: READABLE_STRING_32)
			-- Journal appending to `a_path' (created if absent).
		require
			path_present: not a_path.is_empty
		do
			make_in_memory
			path := a_path.to_string_32
		ensure
			empty: count = 0
			persistent: is_persistent
		end

feature -- Access

	count: INTEGER
			-- Number of events.
		do
			Result := event_list.count
		end

	event (a_index: INTEGER): PT_TAKE_EVENT
			-- Event at `a_index'.
		require
			valid_index: a_index >= 1 and a_index <= count
		do
			Result := event_list [a_index]
		end

	last_event: PT_TAKE_EVENT
			-- Most recent event.
		require
			not_empty: count > 0
		do
			Result := event_list.last
		end

	last_rt: REAL_64
			-- Recording time of the most recent event (0 when empty).

	lines_written: INTEGER
			-- JSONL lines written and flushed (persistent journals only).

	skipped_lines: INTEGER
			-- Unreadable lines skipped by `replay_from'.

	path: detachable STRING_32
			-- JSONL file, when persistent.

	codec: PT_JOURNAL_CODEC

	count_of (a_kind: INTEGER): INTEGER
			-- Number of events of `a_kind'.
		require
			kind_known: a_kind >= {PT_EVENT_KIND}.Session_start and a_kind <= {PT_EVENT_KIND}.Abort
		do
			across event_list as ic loop
				if ic.kind = a_kind then
					Result := Result + 1
				end
			end
		ensure
			bounded: Result >= 0 and Result <= count
		end

feature -- Status

	is_open: BOOLEAN = True
			-- May events be appended?

	is_persistent: BOOLEAN
			-- Does `append' write to a file?
		do
			Result := attached path
		end

feature -- Model

	events_model: MML_SEQUENCE [PT_TAKE_EVENT]
			-- Events in order.
		do
			create Result
			across event_list as ic loop
				Result := Result & ic
			end
		ensure
			same_count: Result.count = count
		end

feature -- Element change

	append (a_event: PT_TAKE_EVENT)
			-- Append `a_event' and, when persistent, write and flush one JSONL line.
		require
			rt_ordered: a_event.rt >= last_rt
			open: is_open
		do
			event_list.extend (a_event)
			last_rt := a_event.rt
			flush_trace
			if attached path as al_path then
					-- SIMPLE_FILE.append_line opens, writes and closes per call: one flushed line (Q6).
				if (create {SIMPLE_FILE}.make (al_path)).append_line (codec.encode (a_event)) then
					lines_written := lines_written + 1
				end
			end
		ensure
			appended: (events_model |=| (old events_model & a_event))
			last_updated: last_rt = a_event.rt
			persisted: is_persistent implies lines_written = old lines_written + 1
			memory_only_unwritten: not is_persistent implies lines_written = old lines_written
		end

	replay_from (a_lines: ITERABLE [READABLE_STRING_8])
			-- Rebuild from JSONL lines; unreadable lines (a torn last line after a crash) are skipped.
		require
			empty: count = 0
		do
			across a_lines as ic loop
				if not ic.is_empty then
					codec.decode (ic)
					if codec.has_event and then attached codec.last_event as al_event and then al_event.rt >= last_rt then
							-- Replay rebuilds memory only; the file already holds these lines.
						event_list.extend (al_event)
						last_rt := al_event.rt
					else
						skipped_lines := skipped_lines + 1
					end
				end
			end
		ensure
			ordered: across 2 |..| count as i all event (i).rt >= event (i - 1).rt end
			skips_counted: skipped_lines >= old skipped_lines
		end

feature -- Follow trace

	trace (a_line: READABLE_STRING_32)
			-- Buffer one follow-trace line (PT_FOLLOW_TRACE); it is written before the next event
			-- or by `flush_trace'. Replay skips its kinds; a memory journal drops it.
		require
			one_line: not a_line.has ('%N')
		do
			if is_persistent then
				trace_buffer.append (a_line)
				trace_buffer.append_character ('%N')
				trace_lines := trace_lines + 1
			end
		ensure
			counted: is_persistent implies trace_lines = old trace_lines + 1
			memory_only_dropped: not is_persistent implies trace_buffer.is_empty
		end

	flush_trace
			-- Write the buffered trace lines.
		do
			if attached path as al_path and not trace_buffer.is_empty then
				if (create {SIMPLE_FILE}.make (al_path)).append_text (trace_buffer) then
					trace_lines_written := trace_lines
				end
				trace_buffer.wipe_out
			end
		ensure
			emptied: trace_buffer.is_empty
		end

	trace_lines: INTEGER
			-- Trace lines given to `trace'.

	trace_lines_written: INTEGER
			-- Trace lines on disk as of the last successful flush.

	has_trace_pending: BOOLEAN
		do
			Result := not trace_buffer.is_empty
		end

feature {NONE} -- Implementation

	trace_buffer: STRING_32
			-- Trace lines not yet written, each ending in a new line.

	event_list: ARRAYED_LIST [PT_TAKE_EVENT]

invariant
	last_rt_non_negative: last_rt >= 0
	empty_zero: count = 0 implies last_rt = 0
	writes_bounded: lines_written <= count

end
