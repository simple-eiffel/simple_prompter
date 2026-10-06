note
	description: "[
		English stop words: short function words that never move the alignment
		on their own (DR-017). Membership is tested on normalized forms.
	]"
	author: "Larry Rix"

class
	PT_STOP_WORDS

feature -- Status

	has (a_normalized: READABLE_STRING_32): BOOLEAN
			-- Is `a_normalized' a stop word?
		do
			Result := cached_set.has (a_normalized.to_string_32)
		end

feature -- Access

	count: INTEGER
			-- Number of stop words.
		do
			Result := cached_set.count
		end

feature {NONE} -- Implementation

	cached_set: HASH_TABLE [BOOLEAN, STRING_32]
			-- The set, built once.
		once
			create Result.make (64)
			Result.compare_objects
			across cached_list as ic loop
				Result.put (True, ic)
			end
		ensure
			comparing_text: Result.object_comparison
		end

	cached_list: ARRAY [STRING_32]
			-- Source list (kept short on purpose: matching quality, not linguistics).
		once
			Result := <<{STRING_32} "a", {STRING_32} "an", {STRING_32} "the", {STRING_32} "and",
				{STRING_32} "or", {STRING_32} "but", {STRING_32} "of", {STRING_32} "to",
				{STRING_32} "in", {STRING_32} "on", {STRING_32} "at", {STRING_32} "for",
				{STRING_32} "by", {STRING_32} "with", {STRING_32} "as", {STRING_32} "is",
				{STRING_32} "it", {STRING_32} "its", {STRING_32} "be", {STRING_32} "was",
				{STRING_32} "are", {STRING_32} "so", {STRING_32} "if", {STRING_32} "that",
				{STRING_32} "this", {STRING_32} "you", {STRING_32} "your", {STRING_32} "i",
				{STRING_32} "we", {STRING_32} "he", {STRING_32} "she", {STRING_32} "they",
				{STRING_32} "do", {STRING_32} "not", {STRING_32} "no", {STRING_32} "can",
				{STRING_32} "will", {STRING_32} "my", {STRING_32} "me", {STRING_32} "up",
				{STRING_32} "um", {STRING_32} "uh">>
		end

invariant
	non_empty: count > 0

end
