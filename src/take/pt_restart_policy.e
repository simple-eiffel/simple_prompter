note
	description: "[
		Where a restart begins. Again: start of the current passage, or of the
		previous passage when the flub came within the first Early_words words
		(simple_speed_reader's replay_sentence rule), or the last confidently
		aligned passage when alignment is unsure. Browse: step by passage or paragraph.
	]"
	author: "Larry Rix"

class
	PT_RESTART_POLICY

feature -- Constants

	Early_words: INTEGER = 2
	Unit_passage: INTEGER = 1
	Unit_paragraph: INTEGER = 2

feature -- Queries

	passage_start (a_revision: PT_SCRIPT_REVISION; a_word: INTEGER): INTEGER
			-- First word of the passage containing `a_word'.
		require
			valid: a_word >= 1 and a_word <= a_revision.word_count
		do
			Result := a_revision.passage (a_revision.passage_of (a_word)).first_word
		ensure
			not_after: Result <= a_word
			in_same_passage: a_revision.passage_of (Result) = a_revision.passage_of (a_word)
		end

	again_caret (a_revision: PT_SCRIPT_REVISION; a_position: INTEGER; a_confident: BOOLEAN;
			a_last_confident: INTEGER): INTEGER
			-- Caret for Again with the reader at `a_position'; `a_last_confident' is the last
			-- confidently aligned word (used when not `a_confident').
		require
			valid_position: a_position >= 1 and a_position <= a_revision.word_count
			valid_fallback: a_last_confident >= 1 and a_last_confident <= a_position
		local
			l_start, l_passage: INTEGER
		do
			if not a_confident then
				Result := passage_start (a_revision, a_last_confident)
			else
				l_start := passage_start (a_revision, a_position)
				l_passage := a_revision.passage_of (a_position)
				if a_position - l_start < Early_words and l_passage > 1 then
					Result := a_revision.passage (l_passage - 1).first_word
				else
					Result := l_start
				end
			end
		ensure
			valid: Result >= 1 and Result <= a_revision.word_count
			at_passage_start: Result = passage_start (a_revision, Result)
			not_after: Result <= a_position
			previous_if_early: (a_confident and a_position - passage_start (a_revision, a_position) < Early_words
					and a_revision.passage_of (a_position) > 1)
				implies a_revision.passage_of (Result) = a_revision.passage_of (a_position) - 1
			fallback_when_unsure: not a_confident implies Result = passage_start (a_revision, a_last_confident)
		end

	step_back (a_revision: PT_SCRIPT_REVISION; a_caret, a_unit: INTEGER): INTEGER
			-- Caret one `a_unit' back from `a_caret' (stays at word 1 at the start).
		require
			valid_caret: a_caret >= 1 and a_caret <= a_revision.word_count
			known_unit: a_unit = Unit_passage or a_unit = Unit_paragraph
		local
			l_passage, l_start, l_paragraph: INTEGER
		do
			l_passage := a_revision.passage_of (a_caret)
			if a_unit = Unit_passage then
				l_start := a_revision.passage (l_passage).first_word
				if a_caret > l_start then
					Result := l_start
				elseif l_passage > 1 then
					Result := a_revision.passage (l_passage - 1).first_word
				else
					Result := l_start
				end
			else
				l_paragraph := a_revision.passage (l_passage).paragraph_index
				l_start := paragraph_start (a_revision, l_paragraph)
				if a_caret > l_start then
					Result := l_start
				elseif l_passage > 1 then
					Result := paragraph_start (a_revision, a_revision.passage (l_passage - 1).paragraph_index)
				else
					Result := l_start
				end
			end
		ensure
			valid: Result >= 1 and Result <= a_revision.word_count
			not_after: Result <= a_caret
			moves_unless_first: a_revision.passage_of (a_caret) > 1 implies Result < a_caret
			at_passage_start: Result = passage_start (a_revision, Result)
		end

	step_forward (a_revision: PT_SCRIPT_REVISION; a_caret, a_unit: INTEGER): INTEGER
			-- Caret one `a_unit' forward from `a_caret' (stays put in the last unit).
		require
			valid_caret: a_caret >= 1 and a_caret <= a_revision.word_count
			known_unit: a_unit = Unit_passage or a_unit = Unit_paragraph
		local
			l_passage, i: INTEGER
		do
			Result := a_caret
			l_passage := a_revision.passage_of (a_caret)
			if l_passage < a_revision.passage_count then
				Result := a_revision.passage (l_passage + 1).first_word
				if a_unit = Unit_paragraph then
					from i := l_passage + 1 until i > a_revision.passage_count
						or else a_revision.passage (i).paragraph_index /= a_revision.passage (l_passage).paragraph_index
					loop
						i := i + 1
					end
					if i <= a_revision.passage_count then
						Result := a_revision.passage (i).first_word
					end
				end
			end
		ensure
			valid: Result >= 1 and Result <= a_revision.word_count
			not_before: Result >= a_caret
			moves_unless_last: a_revision.passage_of (a_caret) < a_revision.passage_count implies Result > a_caret
			at_passage_start: Result > a_caret implies Result = passage_start (a_revision, Result)
		end

feature {NONE} -- Implementation

	paragraph_start (a_revision: PT_SCRIPT_REVISION; a_paragraph: INTEGER): INTEGER
			-- First word of the first passage in paragraph `a_paragraph'.
		local
			i: INTEGER
		do
			from i := 1 until Result > 0 or i > a_revision.passage_count loop
				if a_revision.passage (i).paragraph_index = a_paragraph then
					Result := a_revision.passage (i).first_word
				end
				i := i + 1
			end
		end

end
