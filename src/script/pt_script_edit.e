note
	description: "[
		A requested script change: replace words `first'..`last' of revision
		`from_revision' with `new_text'. `first' = `last' + 1 inserts; an empty
		`new_text' deletes (strike).
	]"
	author: "Larry Rix"

class
	PT_SCRIPT_EDIT

create
	make

feature {NONE} -- Initialization

	make (a_from_revision, a_first, a_last: INTEGER; a_new_text: READABLE_STRING_GENERAL)
			-- Edit of revision `a_from_revision', words `a_first'..`a_last'.
		require
			revision_positive: a_from_revision >= 1
			first_positive: a_first >= 1
			range_ordered: a_first <= a_last + 1
		do
			from_revision := a_from_revision
			first := a_first
			last := a_last
			create new_text.make_from_string_general (a_new_text)
		ensure
			revision_set: from_revision = a_from_revision
			range_set: first = a_first and last = a_last
			text_set: new_text.same_string_general (a_new_text)
		end

feature -- Access

	from_revision: INTEGER
	first, last: INTEGER
	new_text: STRING_32

feature -- Status

	is_insertion: BOOLEAN
			-- Does this edit insert without replacing?
		do
			Result := first = last + 1
		end

	is_strike: BOOLEAN
			-- Does this edit delete words?
		do
			Result := new_text.is_empty
		end

invariant
	revision_positive: from_revision >= 1
	first_positive: first >= 1
	range_ordered: first <= last + 1

end
