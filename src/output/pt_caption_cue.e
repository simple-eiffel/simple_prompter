note
	description: "One caption: output-time interval, text from the final script, and the word ids it shows."
	author: "Larry Rix"

class
	PT_CAPTION_CUE

create
	make

feature {NONE} -- Initialization

	make (a_t0, a_t1: REAL_64; a_text: READABLE_STRING_32; a_word_ids: ITERABLE [PT_WORD_ID])
		require
			times_ordered: a_t0 >= 0 and a_t0 < a_t1
			text_present: not a_text.is_empty
		do
			t0 := a_t0
			t1 := a_t1
			text := a_text.to_string_32
			create word_ids.make (8)
			across a_word_ids as ic loop
				word_ids.extend (ic)
			end
		ensure
			times_set: t0 = a_t0 and t1 = a_t1
			text_set: text.same_string (a_text)
		end

feature -- Access

	t0, t1: REAL_64
	text: STRING_32
	word_ids: ARRAYED_LIST [PT_WORD_ID]

invariant
	times_ordered: t0 >= 0 and t0 < t1
	text_present: not text.is_empty

end
