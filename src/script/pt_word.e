note
	description: "One readable token of a script revision, with a stable identity."
	author: "Larry Rix"

class
	PT_WORD

create
	make

feature {NONE} -- Initialization

	make (a_id: PT_WORD_ID; a_text, a_normalized: READABLE_STRING_32;
			a_char_start, a_char_end, a_passage, a_paragraph, a_section: INTEGER;
			a_is_stop, a_is_cue, a_is_heading: BOOLEAN)
			-- Create word `a_text' with identity `a_id'.
		require
			real_id: not a_id.is_none
			text_present: not a_text.is_empty
			span_ordered: a_char_start >= 1 and a_char_start <= a_char_end
			structure_positive: a_passage >= 1 and a_paragraph >= 1 and a_section >= 0
			normalized_not_longer: a_normalized.count <= a_text.count
			cue_not_heading: not (a_is_cue and a_is_heading)
		do
			id := a_id
			create text.make_from_string (a_text)
			create normalized.make_from_string (a_normalized)
			char_start := a_char_start
			char_end := a_char_end
			passage_index := a_passage
			paragraph_index := a_paragraph
			section_index := a_section
			is_stop_word := a_is_stop
			is_cue := a_is_cue
			is_heading := a_is_heading
		ensure
			id_set: id ~ a_id
			text_set: text.same_string (a_text)
			normalized_set: normalized.same_string (a_normalized)
			span_set: char_start = a_char_start and char_end = a_char_end
			structure_set: passage_index = a_passage and paragraph_index = a_paragraph and section_index = a_section
			flags_set: is_stop_word = a_is_stop and is_cue = a_is_cue and is_heading = a_is_heading
		end

feature -- Access

	id: PT_WORD_ID
			-- Stable identity.

	text: STRING_32
			-- Text as written in the script.

	normalized: STRING_32
			-- Lowercase, punctuation stripped, digits kept (PT_NORMALIZER).

	char_start, char_end: INTEGER
			-- Character span in the revision's source text.

	passage_index, paragraph_index, section_index: INTEGER
			-- Structure indexes (section 0 = before the first heading).

feature -- Status

	is_stop_word: BOOLEAN
			-- Is this a stop word (never moves alignment alone)?

	is_cue: BOOLEAN
			-- Is this inside a [CUE] marker (shown dimmed, never spoken)?

	is_heading: BOOLEAN
			-- Is this part of a heading? Optional: matchable if read aloud, never required
			-- for exact cover (real-voice evidence: Larry read the headings; review M24).

	is_required: BOOLEAN
			-- Must this word appear in the final cut?
		do
			Result := not is_cue and not is_heading
		ensure
			definition: Result = (not is_cue and not is_heading)
		end

invariant
	real_id: not id.is_none
	text_present: not text.is_empty
	span_ordered: char_start >= 1 and char_start <= char_end
	structure_positive: passage_index >= 1 and paragraph_index >= 1 and section_index >= 0
	normalized_not_longer: normalized.count <= text.count
	cue_not_heading: not (is_cue and is_heading)

end
