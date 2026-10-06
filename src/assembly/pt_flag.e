note
	description: "An analysis finding shown on the Edit Floor (amber flag)."
	author: "Larry Rix"

class
	PT_FLAG

create
	make

feature {NONE} -- Initialization

	make (a_kind: INTEGER; a_span: PT_TIME_SPAN; a_first_word, a_last_word: PT_WORD_ID; a_message: READABLE_STRING_32)
		require
			kind_known: a_kind >= {PT_FLAG_KIND}.Misread and a_kind <= {PT_FLAG_KIND}.Long_pause
			message_present: not a_message.is_empty
		do
			kind := a_kind
			span := a_span
			first_word := a_first_word
			last_word := a_last_word
			message := a_message.to_string_32
		ensure
			kind_set: kind = a_kind
			span_set: span = a_span
			words_set: first_word ~ a_first_word and last_word ~ a_last_word
			message_set: message.same_string (a_message)
		end

feature -- Access

	kind: INTEGER
	span: PT_TIME_SPAN
	first_word, last_word: PT_WORD_ID
	message: STRING_32
			-- E.g. "sentence 15: you said 'their' (script: 'there')".

invariant
	kind_known: kind >= {PT_FLAG_KIND}.Misread and kind <= {PT_FLAG_KIND}.Long_pause
	message_present: not message.is_empty

end
