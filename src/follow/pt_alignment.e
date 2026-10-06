note
	description: "The aligner's estimate of where the reader is, with the evidence behind it."
	author: "Larry Rix"

class
	PT_ALIGNMENT

create
	make

feature {NONE} -- Initialization

	make (a_word_index: INTEGER; a_confidence: REAL_64; a_matched_count, a_anchor_count: INTEGER;
			a_rate_wps: REAL_64; a_sample_pos: INTEGER_64)
			-- Reader at word `a_word_index' as of sample `a_sample_pos'.
		require
			index_non_negative: a_word_index >= 0
			confidence_range: a_confidence >= 0.0 and a_confidence <= 1.0
			counts_ordered: a_anchor_count >= 0 and a_anchor_count <= a_matched_count
			rate_non_negative: a_rate_wps >= 0
			position_non_negative: a_sample_pos >= 0
		do
			word_index := a_word_index
			confidence := a_confidence
			matched_count := a_matched_count
			anchor_count := a_anchor_count
			rate_wps := a_rate_wps
			sample_pos := a_sample_pos
		ensure
			index_set: word_index = a_word_index
			confidence_set: confidence = a_confidence
			counts_set: matched_count = a_matched_count and anchor_count = a_anchor_count
			rate_set: rate_wps = a_rate_wps
			position_set: sample_pos = a_sample_pos
		end

feature -- Access

	word_index: INTEGER
			-- Word the reader is on (0 = before the first word).

	confidence: REAL_64
			-- 0..1.

	matched_count: INTEGER
			-- Heard words matched to script words in the scored window.

	anchor_count: INTEGER
			-- Matched words that are not stop words (only these may move position).

	rate_wps: REAL_64
			-- Measured speaking rate, words per second.

	sample_pos: INTEGER_64
			-- Sample-clock position the estimate refers to.

feature -- Status

	is_anchored: BOOLEAN
			-- Did at least one non-stop word match?
		do
			Result := anchor_count > 0
		end

invariant
	index_non_negative: word_index >= 0
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	counts_ordered: anchor_count >= 0 and anchor_count <= matched_count
	rate_non_negative: rate_wps >= 0
	position_non_negative: sample_pos >= 0

end
