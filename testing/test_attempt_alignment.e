note
	description: "[
		Phase 5: the attempt aligner and misread flags (T18), from defects found by
		replaying larry_read_01: a long [CUE] line stopped alignment for the rest of the
		recording, a stop word in an ad-lib skipped the script ahead, multi-word
		equivalences were never matched, and Misread flags were never raised.
	]"
	author: "Larry Rix"

class
	TEST_ATTEMPT_ALIGNMENT

inherit
	PT_TEST_SET

feature -- Cue lines

	test_long_cue_does_not_stop_alignment
			-- Cue words are skipped and not counted toward the lookahead.
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			r := parsed ({STRING_32} "One two three.%N%N[CUE: this cue has many more words than the lookahead could ever cover at all]%N%NFour five six.")
			a := aligned (r, timed (<<{STRING_32} "one", {STRING_32} "two", {STRING_32} "three", {STRING_32} "four", {STRING_32} "five", {STRING_32} "six">>))
			assert_integers_equal ("all six words aligned", 6, a.last_timeline.count)
			assert_true ("six is last", a.last_timeline.occurrence (6).word ~ r.word (r.word_count).id)
		end

feature -- Stop words

	test_stop_word_does_not_skip_ahead
			-- "So" heard first must not jump to the script's "so" four words ahead.
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			assert_true ("so is a stop word", (create {PT_STOP_WORDS}).has ({STRING_32} "so"))
			r := parsed ({STRING_32} "Now a repeated phrase so when you stop.")
			a := aligned (r, timed (<<{STRING_32} "So", {STRING_32} "now", {STRING_32} "a", {STRING_32} "repeated",
				{STRING_32} "phrase", {STRING_32} "so", {STRING_32} "when", {STRING_32} "you", {STRING_32} "stop">>))
			assert_true ("first word aligned to now", a.last_timeline.occurrence (1).word ~ r.word (1).id)
			assert_integers_equal ("every script word once", r.word_count, a.last_timeline.count)
		end

feature -- Multi-word equivalences

	test_two_heard_words_for_one_script_word
			-- "for example" stands for "e.g."; "post condition" for "postcondition".
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			r := parsed ({STRING_32} "Read the specification, e.g. a postcondition tells you.")
			a := aligned (r, timed (<<{STRING_32} "read", {STRING_32} "the", {STRING_32} "specification", {STRING_32} "for",
				{STRING_32} "example", {STRING_32} "a", {STRING_32} "post", {STRING_32} "condition", {STRING_32} "tells", {STRING_32} "you">>))
			assert_integers_equal ("all eight script words", 8, a.last_timeline.count)
			assert_true ("e.g. heard", a.last_timeline.has_in (r.word (4).id, 1))
			assert_true ("postcondition heard", a.last_timeline.has_in (r.word (6).id, 1))
			assert_true ("pair spans both heard words", a.last_timeline.occurrence_in (r.word (4).id, 1) /= Void and then
				attached a.last_timeline.occurrence_in (r.word (4).id, 1) as al_o and then al_o.span.t1 > al_o.span.t0 + 0.5)
		end

	test_one_heard_token_for_three_script_words
			-- "cpp" stands for "c p p".
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			r := parsed ({STRING_32} "Whisper dot c p p and Silero.")
			a := aligned (r, timed (<<{STRING_32} "whisper", {STRING_32} "dot", {STRING_32} "cpp", {STRING_32} "and", {STRING_32} "silero">>))
			assert_integers_equal ("all seven script words", 7, a.last_timeline.count)
			assert_true ("each p heard", a.last_timeline.has_in (r.word (4).id, 1) and a.last_timeline.has_in (r.word (5).id, 1))
			assert_true ("and follows", a.last_timeline.has_in (r.word (6).id, 1))
		end

feature -- Misreads (T18)

	test_one_for_one_substitution_is_a_misread
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			r := parsed ({STRING_32} "An RTX 5070 Ti card.")
			a := aligned (r, timed (<<{STRING_32} "an", {STRING_32} "RTX", {STRING_32} "55070", {STRING_32} "Ti", {STRING_32} "card">>))
			assert_integers_equal ("one misread", 1, a.last_misreads.count)
			assert_true ("script word", a.last_misreads.first.script_text.same_string ({STRING_32} "5070"))
			assert_true ("heard word", a.last_misreads.first.heard_text.same_string ({STRING_32} "55070"))
			assert_true ("misread word id", a.last_misreads.first.word ~ r.word (3).id)
			assert_integers_equal ("all five slots, the misread one too", 5, a.last_timeline.count)
		end

	test_homophones_are_not_misreads
		local
			a: PT_ATTEMPT_ALIGNER
		do
			a := aligned (parsed ({STRING_32} "Their house is there."),
				timed (<<{STRING_32} "there", {STRING_32} "house", {STRING_32} "is", {STRING_32} "their">>))
			assert_integers_equal ("no misreads", 0, a.last_misreads.count)
			assert_integers_equal ("all four aligned", 4, a.last_timeline.count)
		end

	test_uneven_gap_is_not_a_misread
			-- One heard word for two script words ("26" for "twenty twenty-six") is not a substitution.
		local
			a: PT_ATTEMPT_ALIGNER
		do
			a := aligned (parsed ({STRING_32} "It was twenty twenty six then."),
				timed (<<{STRING_32} "it", {STRING_32} "was", {STRING_32} "26", {STRING_32} "then">>))
			assert_integers_equal ("no misreads", 0, a.last_misreads.count)
		end

	test_digits_are_not_sound_alikes
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_false ("55070 is not 5070", e.are_equivalent ({STRING_32} "55070", {STRING_32} "5070"))
			assert_true ("words still sound alike", e.are_equivalent ({STRING_32} "colour", {STRING_32} "color"))
		end

feature -- Lost recovery

	test_ad_lib_word_does_not_pull_the_pointer
			-- After an ad-lib, a script word inside it ("orange") must be confirmed by the next heard
			-- word before alignment jumps there.
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			r := parsed ({STRING_32} "Red green blue.%N%NCats chase mice around the barn every morning before sunrise and the orange cat sleeps.")
			a := aligned (r, timed (<<{STRING_32} "red", {STRING_32} "green", {STRING_32} "blue", {STRING_32} "um", {STRING_32} "like",
				{STRING_32} "so", {STRING_32} "well", {STRING_32} "orange", {STRING_32} "you", {STRING_32} "know", {STRING_32} "cats",
				{STRING_32} "chase", {STRING_32} "mice", {STRING_32} "around", {STRING_32} "the", {STRING_32} "barn">>))
			assert_true ("cats aligned", a.last_timeline.has_in (r.word (4).id, 1))
			assert_true ("barn aligned", a.last_timeline.has_in (r.word (9).id, 1))
			assert_false ("orange not taken from the ad-lib", a.last_timeline.has_in (r.word (r.word_count - 2).id, 1))
		end

	test_skipped_paragraph_is_recovered
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
		do
			r := parsed ({STRING_32} "Alpha bravo charlie.%N%NThis paragraph is skipped entirely because the reader jumps ahead to the next one without saying any of these words aloud today.%N%NDelta echo foxtrot golf hotel.")
			a := aligned (r, timed (<<{STRING_32} "alpha", {STRING_32} "bravo", {STRING_32} "charlie", {STRING_32} "delta",
				{STRING_32} "echo", {STRING_32} "foxtrot", {STRING_32} "golf", {STRING_32} "hotel">>))
			assert_true ("hotel aligned", a.last_timeline.has_in (r.word (r.word_count).id, 1))
		end

feature -- Flags

	test_misread_flags_only_inside_the_final_video
		local
			f: PT_FLAGGER
			l_cuts: PT_CUT_LIST
			l_misreads: ARRAYED_LIST [PT_MISREAD]
		do
			create l_misreads.make (2)
			l_misreads.extend (create {PT_MISREAD}.make (id (3), {STRING_32} "5070", {STRING_32} "55070", span (2.0, 2.4), 1))
			l_misreads.extend (create {PT_MISREAD}.make (id (9), {STRING_32} "card", {STRING_32} "cart", span (8.0, 8.3), 1))
			create l_cuts.make
			l_cuts.extend (create {PT_CUT}.make (0, span (1.0, 4.0), <<id (1), id (2), id (3)>>, 1, 3, 1, False))
			create f.make (2.0)
			f.flag_misreads (l_misreads, l_cuts)
			assert_integers_equal ("only the kept misread", 1, f.count_of ({PT_FLAG_KIND}.Misread))
			assert_true ("message names both words", f.last_flags.first.message.has_substring ({STRING_32} "55070")
				and f.last_flags.first.message.has_substring ({STRING_32} "5070"))
			assert_integers_equal ("kept count helper", 1, f.kept_count (l_misreads, l_cuts))
		end

	test_analyzer_raises_the_misread_flag
		local
			an: PT_SESSION_ANALYZER
			r: PT_SCRIPT_REVISION
			j: PT_JOURNAL
			m: PT_SPEECH_MAP
			l_misread: BOOLEAN
		do
			r := parsed ({STRING_32} "An RTX 5070 Ti card.")
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_resume (0.5, r.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_wrap (5.0, "user"))
			create m.make (6.0)
			m.extend_span (span (1.0, 3.5))
			create an.make (create {PT_SCRIPTED_TRANSCRIBER}.make (m,
				timed (<<{STRING_32} "an", {STRING_32} "RTX", {STRING_32} "55070", {STRING_32} "Ti", {STRING_32} "card">>)),
				create {PT_ATTEMPT_BUILDER}.make, create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
				create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
				create {PT_FLAGGER}.make (2.0))
			an.analyze ({STRING_32} "raw.mkv", 6.0, j, history_of (r))
			assert_true ("success", an.last_analysis.is_success)
			across an.last_analysis.flags as ic loop
				if ic.kind = {PT_FLAG_KIND}.Misread then
					l_misread := True
				end
			end
			assert_true ("misread flagged", l_misread)
		end

feature -- Windows

	test_run_up_lookahead_and_substitution_limits
		local
			r: PT_SCRIPT_REVISION
			a: PT_ATTEMPT_ALIGNER
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
		do
			r := parsed ({STRING_32} "Alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar.")
			create a.make (create {PT_WORD_MATCHER})
			assert_true ("windows", a.Run_up = 6 and a.Lookahead = 8 and a.Wide_lookahead = 60 and a.Max_substitution = 3)
				-- Run-up: the reader starts two words before the caret (word 5); those words still match.
			create l_attempts.make (1)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (0, 100), r.word (5).id, 1, 5, r.word_count, False, False))
			a.align (l_attempts, history_of (r), timed (<<{STRING_32} "charlie", {STRING_32} "delta", {STRING_32} "echo">>))
			assert_true ("run-up word matched", a.last_timeline.has_in (r.word (3).id, 1))
				-- Lookahead: a word twelve spoken words ahead is not taken in normal mode.
			a := aligned (r, timed (<<{STRING_32} "alpha", {STRING_32} "mike">>))
			assert_integers_equal ("too far ahead in normal mode", 1, a.last_timeline.count)
				-- Three substituted words are misreads; four are not (an ad-lib, not a misread).
			a := aligned (r, timed (<<{STRING_32} "alpha", {STRING_32} "red", {STRING_32} "green", {STRING_32} "blue",
				{STRING_32} "echo", {STRING_32} "foxtrot">>))
			assert_integers_equal ("three misreads", 3, a.last_misreads.count)
			a := aligned (r, timed (<<{STRING_32} "alpha", {STRING_32} "red", {STRING_32} "green", {STRING_32} "blue",
				{STRING_32} "white", {STRING_32} "foxtrot", {STRING_32} "golf">>))
			assert_integers_equal ("four substitutions are not misreads", 0, a.last_misreads.count)
			assert_true ("alignment resumed", a.last_timeline.has_in (r.word (7).id, 1))
		end

feature {NONE} -- Fixtures

	parsed (a_text: READABLE_STRING_32): PT_SCRIPT_REVISION
			-- `a_text' parsed as revision 1.
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "test", a_text, 1, create {PT_ID_SOURCE}.make)
			Result := p.last_revision
		end

	timed (a_words: ARRAY [STRING_32]): PT_HEARD_WORDS
			-- `a_words' heard 0.5 s apart from 1 s, in absolute seconds.
		local
			l_list: ARRAYED_LIST [PT_HEARD_WORD]
			n: PT_NORMALIZER
			l_i: INTEGER
		do
			create n
			create l_list.make (a_words.count)
			from l_i := a_words.lower until l_i > a_words.upper loop
				l_list.extend (create {PT_HEARD_WORD}.make (a_words [l_i], n.normalized (a_words [l_i]),
					1.0 + (l_i - a_words.lower) * 0.5, 1.4 + (l_i - a_words.lower) * 0.5, 0.9))
				l_i := l_i + 1
			end
			create Result.make (0, 16_000 * 100, l_list)
		end

	aligned (a_revision: PT_SCRIPT_REVISION; a_heard: PT_HEARD_WORDS): PT_ATTEMPT_ALIGNER
			-- Attempt aligner run over one attempt covering the whole script.
		local
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
		do
			create l_attempts.make (1)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (0, 100), a_revision.word (1).id, 1, 1,
				a_revision.word_count, False, False))
			create Result.make (create {PT_WORD_MATCHER})
			Result.align (l_attempts, history_of (a_revision), a_heard)
		end

end
