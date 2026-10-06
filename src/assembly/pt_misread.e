note
	description: "[
		A heard word that took the place of a different script word in one attempt: a
		one-for-one substitution found by PT_ATTEMPT_ALIGNER (T18). Equivalence-class
		matches (homophones, spoken abbreviations, number words) never become misreads,
		because the matcher accepts them as the script word.
	]"
	author: "Larry Rix"

class
	PT_MISREAD

create
	make

feature {NONE} -- Initialization

	make (a_word: PT_WORD_ID; a_script_text, a_heard_text: READABLE_STRING_32; a_span: PT_TIME_SPAN; a_attempt: INTEGER)
			-- Script word `a_word' (written `a_script_text') heard as `a_heard_text' during `a_span' of attempt `a_attempt'.
		require
			real_word: not a_word.is_none
			script_present: not a_script_text.is_empty
			heard_present: not a_heard_text.is_empty
			attempt_positive: a_attempt >= 1
		do
			word := a_word
			create script_text.make_from_string (a_script_text)
			create heard_text.make_from_string (a_heard_text)
			span := a_span
			attempt := a_attempt
		ensure
			word_set: word ~ a_word
			script_set: script_text.same_string (a_script_text)
			heard_set: heard_text.same_string (a_heard_text)
			span_set: span = a_span
			attempt_set: attempt = a_attempt
		end

feature -- Access

	word: PT_WORD_ID
			-- Script word that was expected.

	script_text: STRING_32
			-- The script word as written.

	heard_text: STRING_32
			-- What was heard instead (normalized).

	span: PT_TIME_SPAN
			-- When the heard word was spoken (recording time).

	attempt: INTEGER
			-- Attempt it was heard in.

invariant
	real_word: not word.is_none
	script_present: not script_text.is_empty
	heard_present: not heard_text.is_empty
	attempt_positive: attempt >= 1

end
