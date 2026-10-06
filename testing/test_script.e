note
	description: "Script cluster: word ids, revisions, id source, stop words, parser, history, normalizer."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_SCRIPT

inherit
	PT_TEST_SET

feature -- Tests: identity and revisions

	test_word_id_default_is_none
		local
			l_none: PT_WORD_ID
		do
			assert_true ("default is none", l_none.is_none)
			assert_false ("made is real", id (7).is_none)
			assert_true ("value equality", id (7) ~ id (7))
		end

	test_revision_structure_from_fixture
		local
			r: PT_SCRIPT_REVISION
		do
			r := moody
			assert_integers_equal ("seven passages", 7, r.passage_count)
			assert_integers_equal ("first word", 1, r.passage (1).first_word)
			assert_integers_equal ("ids model count", r.word_count, r.ids_model.count)
			assert_integers_equal ("ids unique", r.word_count, r.ids_model.range.count)
			assert_true ("text of first passage", r.text_of_range (1, 3).same_string ({STRING_32} "This is Moody."))
		end

	test_index_of_and_passage_of
		local
			r: PT_SCRIPT_REVISION
		do
			r := moody
			assert_integers_equal ("index of word 5", 5, r.index_of (r.word (5).id))
			assert_integers_equal ("absent id", 0, r.index_of (id (9_999)))
			assert_integers_equal ("word 4 in passage 2", 2, r.passage_of (4))
		end

	test_revision_rejects_duplicate_ids
		local
			l_words: ARRAYED_LIST [PT_WORD]
			l_passages: ARRAYED_LIST [PT_PASSAGE]
		do
			create l_words.make (2)
			l_words.extend (create {PT_WORD}.make (id (1), {STRING_32} "a", {STRING_32} "a", 1, 1, 1, 1, 0, True, False, False))
			l_words.extend (create {PT_WORD}.make (id (1), {STRING_32} "b", {STRING_32} "b", 3, 3, 1, 1, 0, False, False, False))
			create l_passages.make (1)
			l_passages.extend (create {PT_PASSAGE}.make (1, 1, 2, 1, 0))
			assert_refused ("duplicate ids refused", agent (a_w: ARRAYED_LIST [PT_WORD]; a_p: ARRAYED_LIST [PT_PASSAGE])
				local l_r: PT_SCRIPT_REVISION
				do create l_r.make (1, {STRING_32} "t", {STRING_32} "a b", a_w, a_p, create {ARRAYED_LIST [PT_SECTION]}.make (0)) end (l_words, l_passages))
		end

	test_id_source_is_monotone
		local
			l_ids: PT_ID_SOURCE
		do
			create l_ids.make
			l_ids.issue
			l_ids.issue
			assert_integers_equal ("second id", 2, l_ids.last_id.value.to_integer_32)
		end

	test_stop_words
		local
			l_stop: PT_STOP_WORDS
		do
			create l_stop
			assert_true ("the", l_stop.has ({STRING_32} "the"))
			assert_false ("teleprompter", l_stop.has ({STRING_32} "teleprompter"))
		end

feature -- Tests: parser and history (Phase 4 behavior)

	test_parser_finds_words_and_passages
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "t", {STRING_32} "This is Moody. Moody is a notch teleprompter for Mac.", 1, create {PT_ID_SOURCE}.make)
			assert_integers_equal ("ten words", 10, p.last_revision.word_count)
			assert_integers_equal ("two passages", 2, p.last_revision.passage_count)
		end

	test_parser_cues_are_not_spoken
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "t", {STRING_32} "[CUE: pause] Hello there.", 1, create {PT_ID_SOURCE}.make)
			assert_integers_equal ("two spoken words", 2, p.last_revision.spoken_ids_model.count)
		end

	test_history_edit_keeps_untouched_ids
		local
			h: PT_SCRIPT_HISTORY
			r: PT_SCRIPT_REVISION
		do
			r := revision_of (<<{STRING_32} "Your script stays in the notch today.">>)
			h := history_of (r)
			h.apply_edit (6, 6, {STRING_32} "webcam")
			assert_integers_equal ("two revisions", 2, h.revision_count)
			assert_true ("prefix id kept", h.current_revision.word (1).id ~ r.word (1).id)
			assert_true ("suffix id kept", h.current_revision.word (7).id ~ r.word (7).id)
			assert_false ("edited word has a new id", h.current_revision.word (6).id ~ r.word (6).id)
		end

	test_normalizer
		local
			n: PT_NORMALIZER
		do
			create n
			assert_true ("lower, no punctuation", n.normalized ({STRING_32} "Moody.").same_string ({STRING_32} "moody"))
			assert_true ("inner apostrophe kept", n.normalized ({STRING_32} "They're").same_string ({STRING_32} "they're"))
		end

end
