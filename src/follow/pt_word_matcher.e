note
	description: "[
		Decides whether a heard (normalized) word matches a script word: exact,
		a stem/plural/tense variant, or within a bounded Levenshtein distance
		that grows with word length, or an equivalence (PT_EQUIVALENCES: homophones,
		spoken abbreviations, number words, compounds, phonetics). Cue words never match;
		heading words match but are optional.
	]"
	author: "Larry Rix"

class
	PT_WORD_MATCHER

inherit
	ANY
		redefine
			default_create
		end

create
	default_create

feature {NONE} -- Initialization

	default_create
			-- Matcher with the standard equivalence tables.
		do
			create equivalences
		end

feature -- Access

	equivalences: PT_EQUIVALENCES
			-- Homophones, spoken abbreviations, number words, compounds, phonetics (review H7).

feature -- Constants

	Max_distance: INTEGER = 2
			-- Largest edit distance ever tolerated.

feature -- Queries

	distance (a, b: READABLE_STRING_32): INTEGER
			-- Bounded Levenshtein distance; computation stops at `Max_distance' + 1.
		local
			l_prev, l_curr, l_swap: SPECIAL [INTEGER]
			i, j, l_cost, l_row_min: INTEGER
			l_done: BOOLEAN
		do
			if a.same_string (b) then
				Result := 0
			elseif (a.count - b.count).abs > Max_distance then
				Result := Max_distance + 1
			else
				create l_prev.make_filled (0, b.count + 1)
				create l_curr.make_filled (0, b.count + 1)
				from j := 0 until j > b.count loop
					l_prev [j] := j
					j := j + 1
				end
				from i := 1 until l_done or i > a.count loop
					l_curr [0] := i
					l_row_min := i
					from j := 1 until j > b.count loop
						if a [i] = b [j] then
							l_cost := 0
						else
							l_cost := 1
						end
						l_curr [j] := (l_prev [j] + 1).min (l_curr [j - 1] + 1).min (l_prev [j - 1] + l_cost)
						l_row_min := l_row_min.min (l_curr [j])
						j := j + 1
					end
					if l_row_min > Max_distance then
						l_done := True
					end
					l_swap := l_prev
					l_prev := l_curr
					l_curr := l_swap
					i := i + 1
				end
				if l_done then
					Result := Max_distance + 1
				else
					Result := l_prev [b.count].min (Max_distance + 1).max (1)
				end
			end
		ensure
			non_negative: Result >= 0
			zero_iff_equal: (Result = 0) = a.same_string (b)
			bounded: Result <= Max_distance + 1
		end

	allowed_distance (a_length: INTEGER): INTEGER
			-- Edit distance tolerated for a script word of `a_length' characters.
		require
			non_negative: a_length >= 0
		do
			if a_length >= 8 then
				Result := 2
			elseif a_length >= 5 then
				Result := 1
			end
		ensure
			short_strict: a_length <= 4 implies Result = 0
			medium: (a_length >= 5 and a_length <= 7) implies Result = 1
			long: a_length >= 8 implies Result = 2
			within_max: Result <= Max_distance
		end

	is_stem_variant (a_heard, a_script: READABLE_STRING_32): BOOLEAN
			-- Do `a_heard' and `a_script' differ only by a common English suffix (s, es, ed, ing)?
		local
			l_long, l_short: READABLE_STRING_32
		do
			if not a_heard.same_string (a_script) then
				if a_heard.count >= a_script.count then
					l_long := a_heard
					l_short := a_script
				else
					l_long := a_script
					l_short := a_heard
				end
				if l_short.count >= 3 and then l_long.starts_with (l_short) then
					Result := across << {STRING_32} "s", {STRING_32} "es", {STRING_32} "ed", {STRING_32} "d", {STRING_32} "ing" >> as ic some
							l_long.count = l_short.count + ic.count and then l_long.ends_with (ic) end
				end
			end
		ensure
			equal_is_not_variant: a_heard.same_string (a_script) implies not Result
		end

	matches (a_heard: READABLE_STRING_32; a_script: PT_WORD): BOOLEAN
			-- Does heard word `a_heard' match script word `a_script'?
		local
			l_allowed: INTEGER
		do
			if not a_script.is_cue then
				l_allowed := allowed_distance (a_script.normalized.count)
				Result := equivalences.are_equivalent (a_heard, a_script.normalized)
					or else (a_heard.count >= 3 and then a_heard [1] = a_script.normalized [1]
						and then is_stem_variant (a_heard, a_script.normalized))
					or else (l_allowed > 0 and then not a_heard.has (' ')
						and then (a_heard.count - a_script.normalized.count).abs <= l_allowed
						and then distance (a_heard, a_script.normalized) <= l_allowed)
			end
		ensure
			exact_matches: (a_heard.same_string (a_script.normalized) and not a_script.is_cue) implies Result
			equivalent_matches: (not a_script.is_cue and equivalences.are_equivalent (a_heard, a_script.normalized)) implies Result
			cue_never: a_script.is_cue implies not Result
			tolerance: Result implies (distance (a_heard, a_script.normalized) <= allowed_distance (a_script.normalized.count)
					or is_stem_variant (a_heard, a_script.normalized)
					or equivalences.are_equivalent (a_heard, a_script.normalized))
		end

end
