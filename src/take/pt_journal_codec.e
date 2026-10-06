note
	description: "[
		PT_TAKE_EVENT <-> one JSONL line (spec F-01 section 9.3), e.g.
		{"t":"flub","rt":102.310,"word":141,"by":"clicker"}
		Phase 4 builds and parses with simple_json.
	]"
	author: "Larry Rix"

class
	PT_JOURNAL_CODEC

create
	make

feature {NONE} -- Initialization

	make
			-- Codec with nothing decoded.
		do
		ensure
			nothing_decoded: not has_event and not has_error
		end

feature -- Encoding

	encode (a_event: PT_TAKE_EVENT): STRING_8
			-- One-line JSON object for `a_event' (UTF-8, no newline).
		local
			l_json: SIMPLE_JSON
			o: SIMPLE_JSON_OBJECT
			a: SIMPLE_JSON_ARRAY
		do
			create l_json
			o := l_json.new_object
			o := o.put_string (kinds.name (a_event.kind).to_string_32, "t")
			o := o.put_real (a_event.rt, "rt")
			if not a_event.word.is_none then
				o := o.put_integer (a_event.word.value, "word")
			end
			if not a_event.caret.is_none then
				o := o.put_integer (a_event.caret.value, "caret")
			end
			if a_event.from_rev > 0 then
				o := o.put_integer (a_event.from_rev, "from")
			end
			if a_event.to_rev > 0 then
				o := o.put_integer (a_event.to_rev, "to")
			end
			if not a_event.range_first.is_none then
				o := o.put_integer (a_event.range_first.value, "first")
			end
			if not a_event.range_last.is_none then
				o := o.put_integer (a_event.range_last.value, "last")
			end
			if attached a_event.old_text as al_old then
				o := o.put_string (al_old, "old")
			end
			if attached a_event.new_text as al_new then
				o := o.put_string (al_new, "new")
			end
			if attached a_event.new_ids as al_ids then
				a := l_json.new_array
				across al_ids as ic loop
					a := a.add_integer (ic.value)
				end
				o := o.put_array (a, "ids")
			end
			if attached a_event.text as al_text then
				o := o.put_string (al_text, "text")
			end
			if not a_event.by.is_empty then
				o := o.put_string (a_event.by.to_string_32, "by")
			end
			if a_event.confidence > 0 then
				o := o.put_real (a_event.confidence, "conf")
			end
			if a_event.seconds > 0 then
				o := o.put_real (a_event.seconds, "secs")
			end
			Result := o.as_json
		ensure
			one_line: not Result.has ('%N') and not Result.has ('%R')
			object: Result.starts_with ("{") and Result.ends_with ("}")
		end

feature -- Decoding

	decode (a_line: READABLE_STRING_8)
			-- Parse `a_line'; set `last_event' or `last_error'.
		local
			l_failed: BOOLEAN
			l_utf: UTF_CONVERTER
		do
			has_event := False
			last_event := Void
			last_error := Void
			if l_failed then
				last_error := {STRING_32} "unreadable journal line"
			elseif a_line.is_empty then
				last_error := {STRING_32} "empty line"
			elseif attached (create {SIMPLE_JSON}).parse (l_utf.utf_8_string_8_to_string_32 (a_line)) as al_value
				and then al_value.is_object then
				build (al_value.as_object)
			else
				last_error := {STRING_32} "not a JSON object"
			end
		ensure
			exactly_one_outcome: has_event xor has_error
		rescue
				-- simple_json's parser may raise on malformed input (its adversarial tests say so).
			l_failed := True
			retry
		end

	last_event: detachable PT_TAKE_EVENT
			-- Event from the last successful `decode'.

	last_error: detachable STRING_32
			-- Reason the last `decode' failed.

	has_event: BOOLEAN
			-- Did the last `decode' succeed?

	has_error: BOOLEAN
			-- Did the last `decode' fail?
		do
			Result := not has_event and attached last_error
		end

feature {NONE} -- Implementation

	kinds: PT_EVENT_KIND
			-- Kind names.
		once
			create Result
		end

	kind_of (a_name: READABLE_STRING_GENERAL): INTEGER
			-- Kind code for JSONL name `a_name', 0 if unknown.
		local
			i: INTEGER
		do
			from i := {PT_EVENT_KIND}.Session_start until Result /= 0 or i > {PT_EVENT_KIND}.Abort loop
				if kinds.name (i).same_string_general (a_name) then
					Result := i
				end
				i := i + 1
			end
		end

	id_of (o: SIMPLE_JSON_OBJECT; a_key: STRING_32): PT_WORD_ID
			-- Word id stored under `a_key' (none when absent or not positive).
		do
			if o.has_key (a_key) and then o.integer_item (a_key) > 0 then
				create Result.make (o.integer_item (a_key))
			end
		end

	text_of (o: SIMPLE_JSON_OBJECT; a_key: STRING_32): STRING_32
			-- String under `a_key', empty when absent.
		do
			if attached o.string_item (a_key) as al_s then
				Result := al_s
			else
				create Result.make_empty
			end
		end

	build (o: SIMPLE_JSON_OBJECT)
			-- Construct the event that `o' describes, or set `last_error'.
		local
			l_kind, l_from, l_to, i: INTEGER
			l_rt, l_conf, l_secs: REAL_64
			l_ids: ARRAYED_LIST [PT_WORD_ID]
			l_by: STRING_8
			l_event: detachable PT_TAKE_EVENT
		do
			l_kind := kind_of (text_of (o, "t"))
			l_rt := o.real_item ("rt")
			l_from := o.integer_item ("from").to_integer_32
			l_to := o.integer_item ("to").to_integer_32
			l_conf := o.real_item ("conf")
			l_secs := o.real_item ("secs")
			l_by := text_of (o, "by").to_string_8
			if l_by.is_empty then
				l_by := "system"
			end
			if l_rt < 0 or l_kind = 0 then
				last_error := {STRING_32} "unknown kind or negative time"
			else
				inspect l_kind
				when {PT_EVENT_KIND}.Session_start then
					if l_to >= 1 then
						create l_event.make_session_start (l_rt, l_to, text_of (o, "text"))
					end
				when {PT_EVENT_KIND}.Resume then
					if l_to >= 1 and not id_of (o, "caret").is_none then
						create l_event.make_resume (l_rt, id_of (o, "caret"), l_to)
					end
				when {PT_EVENT_KIND}.Hold then
					create l_event.make_hold (l_rt, l_by)
				when {PT_EVENT_KIND}.Flub then
					create l_event.make_flub (l_rt, id_of (o, "word"), l_by)
				when {PT_EVENT_KIND}.Rewind_to then
					if not id_of (o, "caret").is_none then
						create l_event.make_rewind_to (l_rt, id_of (o, "caret"), text_of (o, "text"))
					end
				when {PT_EVENT_KIND}.Count_in then
					if l_secs >= 0 then
						create l_event.make_count_in (l_rt, l_secs)
					end
				when {PT_EVENT_KIND}.Edit then
					if l_from >= 1 then
						create l_ids.make (4)
						if attached o.array_item ("ids") as al_ids then
							from i := 1 until i > al_ids.count loop
								if al_ids.integer_item (i) > 0 then
									l_ids.extend (create {PT_WORD_ID}.make (al_ids.integer_item (i)))
								end
								i := i + 1
							end
						end
						create l_event.make_edit (l_rt, l_from, id_of (o, "first"), id_of (o, "last"),
							text_of (o, "old"), text_of (o, "new"), l_ids)
					end
				when {PT_EVENT_KIND}.Star then
					create l_event.make_star (l_rt, l_by)
				when {PT_EVENT_KIND}.Reject then
					create l_event.make_reject (l_rt, l_by)
				when {PT_EVENT_KIND}.Marker then
					create l_event.make_marker (l_rt, text_of (o, "text"), l_by)
				when {PT_EVENT_KIND}.Skip then
					if l_from >= 1 then
						create l_event.make_skip (l_rt, l_from, id_of (o, "first"), id_of (o, "last"))
					end
				when {PT_EVENT_KIND}.Align then
					if l_conf >= 0.0 and l_conf <= 1.0 then
						create l_event.make_align (l_rt, id_of (o, "word"), l_conf)
					end
				when {PT_EVENT_KIND}.Wrap then
					create l_event.make_wrap (l_rt, l_by)
				when {PT_EVENT_KIND}.Abort then
					create l_event.make_abort (l_rt, text_of (o, "text"))
				end
				if attached l_event as al_e then
					last_event := al_e
					has_event := True
				else
					last_error := {STRING_32} "fields missing for this kind"
				end
			end
		end

invariant
	event_when_success: has_event implies attached last_event

end
