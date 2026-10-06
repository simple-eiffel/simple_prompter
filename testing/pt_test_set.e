note
	description: "[
		Shared fixtures for simple_prompter tests: revisions built word by word
		(no parser needed), heard words, voice frames, journals, and `raises' for
		asserting that a contract fires. Assertions go through TEST_SET_BASE,
		never `check' (finalized `check' clauses are vacuous).
	]"
	author: "Larry Rix"

deferred class
	PT_TEST_SET

inherit
	TEST_SET_BASE

feature {NONE} -- Script fixtures

	revision_of (a_sentences: ARRAY [STRING_32]): PT_SCRIPT_REVISION
			-- Revision 1 with one passage per sentence, words split on spaces.
		do
			Result := revision_numbered (a_sentences, 1, create {PT_ID_SOURCE}.make)
		end

	revision_numbered (a_sentences: ARRAY [STRING_32]; a_number: INTEGER; a_ids: PT_ID_SOURCE): PT_SCRIPT_REVISION
			-- Revision `a_number' of `a_sentences', ids from `a_ids'.
		local
			l_words: ARRAYED_LIST [PT_WORD]
			l_passages: ARRAYED_LIST [PT_PASSAGE]
			l_source: STRING_32
			l_first, l_pos: INTEGER
			l_stop: PT_STOP_WORDS
		do
			create l_stop
			create l_words.make (32)
			create l_passages.make (8)
			create l_source.make (256)
			across a_sentences as ic_sentence loop
				l_first := l_words.count + 1
				across ic_sentence.split (' ') as ic_word loop
					if not ic_word.is_empty then
						if not l_source.is_empty then
							l_source.append_character (' ')
						end
						l_pos := l_source.count + 1
						l_source.append (ic_word)
						a_ids.issue
						l_words.extend (create {PT_WORD}.make (a_ids.last_id, ic_word, simple_normal (ic_word),
							l_pos, l_pos + ic_word.count - 1, l_passages.count + 1, 1, 0,
							l_stop.has (simple_normal (ic_word)), False, False))
					end
				end
				if l_words.count >= l_first then
					l_passages.extend (create {PT_PASSAGE}.make (l_passages.count + 1, l_first, l_words.count, 1, 0))
				end
			end
			create Result.make (a_number, {STRING_32} "fixture", l_source, l_words, l_passages,
				create {ARRAYED_LIST [PT_SECTION]}.make (0))
		end

	simple_normal (a_word: READABLE_STRING_32): STRING_32
			-- Fixture normalizer: lowercase letters and digits only.
		do
			create Result.make (a_word.count)
			across a_word.as_lower as ic loop
				if ic.is_alpha_numeric then
					Result.append_character (ic)
				end
			end
		end

	moody_sentences: ARRAY [STRING_32]
			-- The script from the Moody reel (evidence/video-analysis.md), first seven sentences.
		do
			Result := <<
				{STRING_32} "This is Moody.",
				{STRING_32} "Moody is a notch teleprompter for Mac.",
				{STRING_32} "It helps you speak clearly during video recordings, online meetings, presentations and live demos.",
				{STRING_32} "The main idea is simple: your script stays right next to your camera, in the notch.",
				{STRING_32} "So when you read your text, you still keep natural eye contact and Moody can follow your voice.",
				{STRING_32} "So when you stop speaking, it pauses, and when you continue, it scrolls again.",
				{STRING_32} "That makes it feel very natural.">>
		end

	moody: PT_SCRIPT_REVISION
		do
			Result := revision_of (moody_sentences)
		end

	history_of (a_revision: PT_SCRIPT_REVISION): PT_SCRIPT_HISTORY
			-- History started with `a_revision' (ids continue after its last id).
		local
			l_last: INTEGER_64
		do
			if a_revision.word_count > 0 then
				l_last := a_revision.word (a_revision.word_count).id.value
			end
			create Result.make (create {PT_ID_SOURCE}.make_after (l_last), create {PT_SCRIPT_PARSER}.make)
			Result.start (a_revision)
		end

feature {NONE} -- Speech fixtures

	heard (a_window_start: INTEGER_64; a_words: ARRAY [STRING_32]): PT_HEARD_WORDS
			-- Words heard 0.3 s apart in a 3 s window.
		local
			l_list: ARRAYED_LIST [PT_HEARD_WORD]
			i: INTEGER
		do
			create l_list.make (a_words.count)
			from i := a_words.lower until i > a_words.upper loop
				l_list.extend (create {PT_HEARD_WORD}.make (a_words [i], simple_normal (a_words [i]),
					(i - a_words.lower) * 0.3, (i - a_words.lower) * 0.3 + 0.25, 0.9))
				i := i + 1
			end
			create Result.make (a_window_start, 48_000, l_list)
		end

	frame (a_sample_pos: INTEGER_64; a_speech: BOOLEAN): PT_VOICE_FRAME
		do
			if a_speech then
				create Result.make (a_sample_pos, 0.4, 0.95, True)
			else
				create Result.make (a_sample_pos, 0.01, 0.02, False)
			end
		end

	silence (a_count: INTEGER): SPECIAL [REAL_32]
		do
			create Result.make_filled (0.0, a_count)
		end

feature {NONE} -- Take fixtures

	controller_for (a_revision: PT_SCRIPT_REVISION): PT_TAKE_CONTROLLER
			-- Idle controller over `a_revision' with a constant follower and an in-memory journal.
		do
			create Result.make (history_of (a_revision), create {PT_JOURNAL}.make_in_memory,
				create {PT_RECORDING_CLOCK}.make, create {PT_FAKE_CLOCK}.make,
				create {PT_CONSTANT_FOLLOWER}.make (a_revision.word_count, 120),
				create {PT_RESTART_POLICY})
		end

	span (a_t0, a_t1: REAL_64): PT_TIME_SPAN
		do
			create Result.make (a_t0, a_t1)
		end

	id (a_value: INTEGER_64): PT_WORD_ID
		do
			create Result.make (a_value)
		end

feature {NONE} -- Contract checks

	raises (a_action: ROUTINE): BOOLEAN
			-- Does calling `a_action' raise (a contract violation, here)?
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_action.call (Void)
			end
		rescue
			l_retried := True
			Result := True
			retry
		end

end
