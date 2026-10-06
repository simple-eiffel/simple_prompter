note
	description: "[
		PT_ANALYSIS <-> analysis/*.json, the worker-exe mailbox (written via
		tmp + rename, simple_speed_reader's SR_WORKER pattern). Phase 4 uses simple_json.
	]"
	author: "Larry Rix"

class
	PT_ANALYSIS_CODEC

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_analysis.make_failed ({STRING_32} "nothing decoded")
		ensure
			nothing_decoded: not last_analysis.is_success
		end

feature -- Access

	last_analysis: PT_ANALYSIS

feature -- Conversion

	encode (a_analysis: PT_ANALYSIS): STRING_8
		local
			l_json: SIMPLE_JSON
			o, x: SIMPLE_JSON_OBJECT
			a: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			create l_json
			o := l_json.new_object.put_boolean (a_analysis.is_success, "success")
			if attached a_analysis.error as al_error then
				o := o.put_string (al_error, "error")
			end
			o := o.put_real (a_analysis.speech_map.duration, "duration")
			a := l_json.new_array
			from i := 1 until i > a_analysis.speech_map.span_count loop
				x := l_json.new_object.put_real (a_analysis.speech_map.span (i).t0, "t0").put_real (a_analysis.speech_map.span (i).t1, "t1")
				a := a.add_object (x)
				i := i + 1
			end
			o := o.put_array (a, "speech")
			a := l_json.new_array
			from i := 1 until i > a_analysis.timeline.count loop
				x := l_json.new_object.put_integer (a_analysis.timeline.occurrence (i).word.value, "w")
					.put_real (a_analysis.timeline.occurrence (i).span.t0, "t0").put_real (a_analysis.timeline.occurrence (i).span.t1, "t1")
					.put_real (a_analysis.timeline.occurrence (i).confidence, "c").put_integer (a_analysis.timeline.occurrence (i).attempt, "a")
				a := a.add_object (x)
				i := i + 1
			end
			o := o.put_array (a, "timeline")
			a := l_json.new_array
			across a_analysis.attempts as ic loop
				x := l_json.new_object.put_integer (ic.index, "i").put_real (ic.span.t0, "t0").put_real (ic.span.t1, "t1")
					.put_integer (ic.caret.value, "caret").put_integer (ic.revision, "rev").put_integer (ic.first_index, "first")
					.put_integer (ic.last_index, "last").put_boolean (ic.is_starred, "star").put_boolean (ic.is_rejected, "reject")
				a := a.add_object (x)
			end
			o := o.put_array (a, "attempts")
			o := o.put_object (cut_codec.cuts_object (a_analysis.cuts), "cuts")
			a := l_json.new_array
			across a_analysis.flags as ic loop
				x := l_json.new_object.put_integer (ic.kind, "k").put_real (ic.span.t0, "t0").put_real (ic.span.t1, "t1")
					.put_integer (ic.first_word.value, "first").put_integer (ic.last_word.value, "last").put_string (ic.message, "msg")
				a := a.add_object (x)
			end
			o := o.put_array (a, "flags")
			a := l_json.new_array
			across a_analysis.decisions as ic loop
				a := a.add_string (ic)
			end
			o := o.put_array (a, "decisions")
			Result := o.as_json
		ensure
			object: Result.starts_with ("{") and Result.ends_with ("}")
		end

	decode (a_json: READABLE_STRING_8)
			-- Parse into `last_analysis' (a failed analysis carries the parse error).
		local
			l_failed: BOOLEAN
			l_utf: UTF_CONVERTER
		do
			if l_failed then
				create last_analysis.make_failed ({STRING_32} "unreadable analysis")
			elseif a_json.is_empty then
				create last_analysis.make_failed ({STRING_32} "empty analysis")
			elseif attached (create {SIMPLE_JSON}).parse (l_utf.utf_8_string_8_to_string_32 (a_json)) as al_value
				and then al_value.is_object then
				read (al_value.as_object)
			else
				create last_analysis.make_failed ({STRING_32} "analysis is not a JSON object")
			end
		rescue
			l_failed := True
			retry
		end

feature {NONE} -- Implementation

	cut_codec: PT_CUT_CODEC
		once
			create Result.make
		end

	id_value (a_value: INTEGER_64): PT_WORD_ID
		do
			if a_value > 0 then
				create Result.make (a_value)
			end
		end

	read (o: SIMPLE_JSON_OBJECT)
			-- Rebuild `last_analysis' from `o'.
		local
			l_map: PT_SPEECH_MAP
			l_timeline: PT_WORD_TIMELINE
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
			l_flags: ARRAYED_LIST [PT_FLAG]
			l_decisions: ARRAYED_LIST [STRING_32]
			i: INTEGER
			l_t0, l_t1: REAL_64
		do
			if not o.boolean_item ("success") then
				if attached o.string_item ("error") as al_e and then not al_e.is_empty then
					create last_analysis.make_failed (al_e)
				else
					create last_analysis.make_failed ({STRING_32} "analysis failed")
				end
			else
				create l_map.make (o.real_item ("duration").max (0))
				if attached o.array_item ("speech") as al_a then
					from i := 1 until i > al_a.count loop
						if attached al_a.object_item (i) as x then
							l_t0 := x.real_item ("t0")
							l_t1 := x.real_item ("t1")
							if l_t0 >= l_map.last_end and l_t0 <= l_t1 and l_t1 <= l_map.duration then
								l_map.extend_span (create {PT_TIME_SPAN}.make (l_t0, l_t1))
							end
						end
						i := i + 1
					end
				end
				create l_timeline.make
				if attached o.array_item ("timeline") as al_a then
					from i := 1 until i > al_a.count loop
						if attached al_a.object_item (i) as x and then x.integer_item ("w") > 0 and then x.integer_item ("a") >= 1
							and then x.real_item ("t0") >= l_timeline.last_start and then x.real_item ("t0") <= x.real_item ("t1")
							and then x.real_item ("c") >= 0.0 and then x.real_item ("c") <= 1.0 then
							l_timeline.extend (create {PT_WORD_OCCURRENCE}.make (id_value (x.integer_item ("w")),
								create {PT_TIME_SPAN}.make (x.real_item ("t0"), x.real_item ("t1")), x.real_item ("c"),
								x.integer_item ("a").to_integer_32))
						end
						i := i + 1
					end
				end
				create l_attempts.make (4)
				if attached o.array_item ("attempts") as al_a then
					from i := 1 until i > al_a.count loop
						if attached al_a.object_item (i) as x and then x.integer_item ("caret") > 0 and then x.integer_item ("rev") >= 1
							and then x.integer_item ("first") >= 1 and then x.integer_item ("last") >= x.integer_item ("first") - 1
							and then x.real_item ("t0") >= 0 and then x.real_item ("t0") <= x.real_item ("t1")
							and then not (x.boolean_item ("star") and x.boolean_item ("reject")) then
							l_attempts.extend (create {PT_ATTEMPT}.make (l_attempts.count + 1,
								create {PT_TIME_SPAN}.make (x.real_item ("t0"), x.real_item ("t1")), id_value (x.integer_item ("caret")),
								x.integer_item ("rev").to_integer_32, x.integer_item ("first").to_integer_32, x.integer_item ("last").to_integer_32,
								x.boolean_item ("star"), x.boolean_item ("reject")))
						end
						i := i + 1
					end
				end
				create l_flags.make (4)
				if attached o.array_item ("flags") as al_a then
					from i := 1 until i > al_a.count loop
						if attached al_a.object_item (i) as x and then x.integer_item ("k") >= {PT_FLAG_KIND}.Misread
							and then x.integer_item ("k") <= {PT_FLAG_KIND}.Long_pause
							and then x.real_item ("t0") >= 0 and then x.real_item ("t0") <= x.real_item ("t1")
							and then attached x.string_item ("msg") as al_msg and then not al_msg.is_empty then
							l_flags.extend (create {PT_FLAG}.make (x.integer_item ("k").to_integer_32,
								create {PT_TIME_SPAN}.make (x.real_item ("t0"), x.real_item ("t1")),
								id_value (x.integer_item ("first")), id_value (x.integer_item ("last")), al_msg))
						end
						i := i + 1
					end
				end
				create l_decisions.make (8)
				if attached o.array_item ("decisions") as al_a then
					from i := 1 until i > al_a.count loop
						if attached al_a.string_item (i) as al_s then
							l_decisions.extend (al_s)
						end
						i := i + 1
					end
				end
				if attached o.object_item ("cuts") as al_cuts then
					cut_codec.read_cuts (al_cuts)
				end
				create last_analysis.make (l_map, l_timeline, l_attempts, cut_codec.last_cuts, l_flags, l_decisions)
			end
		end

end
