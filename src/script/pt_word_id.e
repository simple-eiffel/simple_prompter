note
	description: "[
		Stable identity of a script word across revisions. Untouched words keep
		their id when the script is edited; edited words get fresh ids.
		The default value 0 means "no word".
	]"
	author: "Larry Rix"

expanded class
	PT_WORD_ID

inherit
	ANY
		redefine
			default_create
		end

	HASHABLE
		redefine
			default_create
		end

create
	default_create, make

feature {NONE} -- Initialization

	default_create
			-- The "no word" id.
		do
			value := 0
		ensure then
			none: value = 0
		end

	make (a_value: INTEGER_64)
			-- Identity `a_value'.
		require
			positive: a_value > 0
		do
			value := a_value
		ensure
			set: value = a_value
		end

feature -- Access

	value: INTEGER_64
			-- Raw identity.

	hash_code: INTEGER
			-- Hash of `value' (equal ids hash alike, so MML sets of ids find duplicates by bucket).
		do
			Result := value.hash_code
		end

feature -- Status

	is_none: BOOLEAN
			-- Is this the "no word" id?
		do
			Result := value = 0
		ensure
			definition: Result = (value = 0)
		end

invariant
	non_negative: value >= 0

end
