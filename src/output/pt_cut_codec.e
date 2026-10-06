note
	description: "PT_CUT_LIST <-> cut.json (spec F-01 section 9.5). Phase 4 uses simple_json."
	author: "Larry Rix"

class
	PT_CUT_CODEC

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_cuts.make
		ensure
			nothing_decoded: not has_cuts and last_error = Void
		end

feature -- Access

	last_cuts: PT_CUT_LIST
	last_error: detachable STRING_32
	has_cuts: BOOLEAN

feature -- Conversion

	encode (a_cuts: PT_CUT_LIST): STRING_8
			-- JSON document for `a_cuts'.
		do
			Result := cuts_object (a_cuts).as_json
		ensure
			object: Result.starts_with ("{") and Result.ends_with ("}")
		end

	decode (a_json: READABLE_STRING_8)
			-- Parse `a_json' into `last_cuts', or set `last_error'.
		local
			l_failed: BOOLEAN
			l_utf: UTF_CONVERTER
		do
			has_cuts := False
			last_error := Void
			create last_cuts.make
			if l_failed then
				last_error := {STRING_32} "unreadable cut.json"
			elseif a_json.is_empty then
				last_error := {STRING_32} "empty cut.json"
			elseif attached (create {SIMPLE_JSON}).parse (l_utf.utf_8_string_8_to_string_32 (a_json)) as al_value
				and then al_value.is_object then
				read_cuts (al_value.as_object)
			else
				last_error := {STRING_32} "cut.json is not a JSON object"
			end
		ensure
			outcome: has_cuts xor attached last_error
		rescue
			l_failed := True
			retry
		end

feature -- Conversion helpers (shared with PT_ANALYSIS_CODEC)

	cuts_object (a_cuts: PT_CUT_LIST): SIMPLE_JSON_OBJECT
			-- {"intervals":[{"src","in","out","words":[ids],"first","last","attempt","tight"}]}.
		local
			l_json: SIMPLE_JSON
			l_list: SIMPLE_JSON_ARRAY
			l_ids: SIMPLE_JSON_ARRAY
			o: SIMPLE_JSON_OBJECT
			i: INTEGER
		do
			create l_json
			l_list := l_json.new_array
			from i := 1 until i > a_cuts.count loop
				l_ids := l_json.new_array
				across a_cuts.cut (i).word_ids as ic loop
					l_ids := l_ids.add_integer (ic.value)
				end
				o := l_json.new_object
				o := o.put_integer (a_cuts.cut (i).src, "src")
				o := o.put_real (a_cuts.cut (i).span.t0, "in")
				o := o.put_real (a_cuts.cut (i).span.t1, "out")
				o := o.put_array (l_ids, "words")
				o := o.put_integer (a_cuts.cut (i).first_word_index, "first")
				o := o.put_integer (a_cuts.cut (i).last_word_index, "last")
				o := o.put_integer (a_cuts.cut (i).attempt, "attempt")
				o := o.put_boolean (a_cuts.cut (i).is_tight, "tight")
				l_list := l_list.add_object (o)
				i := i + 1
			end
			Result := l_json.new_object.put_array (l_list, "intervals")
		end

	read_cuts (a_object: SIMPLE_JSON_OBJECT)
			-- Fill `last_cuts' from `a_object', or set `last_error'.
		local
			i, j, l_src, l_first, l_last, l_attempt: INTEGER
			l_in, l_out: REAL_64
			l_ids: ARRAYED_LIST [PT_WORD_ID]
			l_good: BOOLEAN
		do
			create last_cuts.make
			has_cuts := False
			last_error := Void
			l_good := True
			if attached a_object.array_item ("intervals") as al_list then
				from i := 1 until not l_good or i > al_list.count loop
					if attached al_list.object_item (i) as o then
						l_src := o.integer_item ("src").to_integer_32
						l_in := o.real_item ("in")
						l_out := o.real_item ("out")
						l_first := o.integer_item ("first").to_integer_32
						l_last := o.integer_item ("last").to_integer_32
						l_attempt := o.integer_item ("attempt").to_integer_32
						create l_ids.make (8)
						if attached o.array_item ("words") as al_words then
							from j := 1 until j > al_words.count loop
								if al_words.integer_item (j) > 0 then
									l_ids.extend (create {PT_WORD_ID}.make (al_words.integer_item (j)))
								end
								j := j + 1
							end
						end
						l_good := l_src >= 0 and l_in >= 0 and l_in <= l_out and l_first >= 1 and l_first <= l_last
							and l_attempt >= 1 and l_ids.count <= l_last - l_first + 1
							and (last_cuts.count = 0 or else l_first > last_cuts.cut (last_cuts.count).last_word_index)
						if l_good then
							last_cuts.extend (create {PT_CUT}.make (l_src, create {PT_TIME_SPAN}.make (l_in, l_out), l_ids,
								l_first, l_last, l_attempt, o.boolean_item ("tight")))
						end
					else
						l_good := False
					end
					i := i + 1
				end
			else
				l_good := False
			end
			if l_good then
				has_cuts := True
			else
				create last_cuts.make
				last_error := {STRING_32} "cut.json has an invalid interval"
			end
		end

end
