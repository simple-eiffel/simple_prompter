note
	description: "A script word heard in the recording: which word, when, how sure, in which attempt."
	author: "Larry Rix"

class
	PT_WORD_OCCURRENCE

create
	make

feature {NONE} -- Initialization

	make (a_word: PT_WORD_ID; a_span: PT_TIME_SPAN; a_confidence: REAL_64; a_attempt: INTEGER)
		require
			real_word: not a_word.is_none
			confidence_range: a_confidence >= 0.0 and a_confidence <= 1.0
			attempt_positive: a_attempt >= 1
		do
			word := a_word
			span := a_span
			confidence := a_confidence
			attempt := a_attempt
		ensure
			word_set: word ~ a_word
			span_set: span = a_span
			confidence_set: confidence = a_confidence
			attempt_set: attempt = a_attempt
		end

feature -- Access

	word: PT_WORD_ID
	span: PT_TIME_SPAN
	confidence: REAL_64
	attempt: INTEGER

invariant
	real_word: not word.is_none
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	attempt_positive: attempt >= 1

end
