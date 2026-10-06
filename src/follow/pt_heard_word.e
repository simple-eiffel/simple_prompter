note
	description: "One word recognized by the decoder, with times relative to its window and a probability."
	author: "Larry Rix"

class
	PT_HEARD_WORD

create
	make

feature {NONE} -- Initialization

	make (a_text, a_normalized: READABLE_STRING_32; a_t0, a_t1, a_probability: REAL_64)
			-- Heard `a_text' between `a_t0' and `a_t1' seconds into the window.
		require
			text_present: not a_text.is_empty
			times_ordered: a_t0 >= 0 and a_t0 <= a_t1
			probability_range: a_probability >= 0.0 and a_probability <= 1.0
		do
			create text.make_from_string (a_text)
			create normalized.make_from_string (a_normalized)
			t0 := a_t0
			t1 := a_t1
			probability := a_probability
		ensure
			text_set: text.same_string (a_text)
			normalized_set: normalized.same_string (a_normalized)
			times_set: t0 = a_t0 and t1 = a_t1
			probability_set: probability = a_probability
		end

feature -- Access

	text: STRING_32
	normalized: STRING_32
	t0, t1: REAL_64
			-- Seconds relative to the decode window start.
	probability: REAL_64

invariant
	text_present: not text.is_empty
	times_ordered: t0 >= 0 and t0 <= t1
	probability_range: probability >= 0.0 and probability <= 1.0

end
