note
	description: "[
		Equivalence classes (review H7), using the exact mismatches whisper produced on
		Larry's real recording (evidence/real-voice-larry_read_01.md). Inputs are
		normalized forms: lowercase, punctuation stripped.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_EQUIVALENCES

inherit
	PT_TEST_SET

feature -- Tests: pairs from larry_read_01 (heard -> script)

	test_homophones_from_the_recording
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_true ("there ~ their", e.are_equivalent ({STRING_32} "there", {STRING_32} "their"))
			assert_true ("there ~ they're", e.are_equivalent ({STRING_32} "there", {STRING_32} "they're"))
			assert_true ("two ~ to", e.are_equivalent ({STRING_32} "two", {STRING_32} "to"))
			assert_true ("two ~ too", e.are_equivalent ({STRING_32} "two", {STRING_32} "too"))
			assert_true ("hole ~ whole", e.are_equivalent ({STRING_32} "hole", {STRING_32} "whole"))
			assert_true ("sew ~ so", e.are_equivalent ({STRING_32} "sew", {STRING_32} "so"))
		end

	test_spoken_abbreviations_from_the_recording
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_true ("'for example' ~ e.g.", e.are_equivalent ({STRING_32} "for example", {STRING_32} "eg"))
			assert_true ("mrs ~ ms", e.are_equivalent ({STRING_32} "mrs", {STRING_32} "ms"))
			assert_true ("doctor ~ dr", e.are_equivalent ({STRING_32} "doctor", {STRING_32} "dr"))
		end

	test_numbers_from_the_recording
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_true ("1 ~ one", e.are_equivalent ({STRING_32} "1", {STRING_32} "one"))
			assert_integers_equal ("twenty", 20, e.number_value ({STRING_32} "twenty"))
			assert_integers_equal ("not a number", -1, e.number_value ({STRING_32} "moody"))
		end

	test_compounds_from_the_recording
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_true ("'post condition' ~ postcondition", e.are_equivalent ({STRING_32} "post condition", {STRING_32} "postcondition"))
			assert_true ("cpp ~ 'c p p'", e.are_equivalent ({STRING_32} "cpp", {STRING_32} "c p p"))
		end

	test_phonetics_from_the_recording
			-- Phase 4 (Metaphone-style key): red until then.
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_true ("celero ~ silero", e.are_equivalent ({STRING_32} "celero", {STRING_32} "silero"))
		end

feature -- Tests: no false friends

	test_unrelated_words_differ
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_false ("camera vs teleprompter", e.are_equivalent ({STRING_32} "camera", {STRING_32} "teleprompter"))
			assert_false ("their vs here", e.are_equivalent ({STRING_32} "their", {STRING_32} "here"))
		end

end
