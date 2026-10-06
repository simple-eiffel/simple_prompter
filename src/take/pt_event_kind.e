note
	description: "Take Studio journal event kinds (reached as {PT_EVENT_KIND}.Flub etc.)."
	author: "Larry Rix"

class
	PT_EVENT_KIND

feature -- Constants

	Session_start: INTEGER = 1
	Resume: INTEGER = 2
	Hold: INTEGER = 3
	Flub: INTEGER = 4
	Rewind_to: INTEGER = 5
	Count_in: INTEGER = 6
	Edit: INTEGER = 7
	Star: INTEGER = 8
	Reject: INTEGER = 9
	Marker: INTEGER = 10
	Skip: INTEGER = 11
	Align: INTEGER = 12
	Wrap: INTEGER = 13
	Abort: INTEGER = 14

feature -- Names

	name (a_kind: INTEGER): STRING_8
			-- JSONL "t" value for `a_kind'.
		require
			known: a_kind >= Session_start and a_kind <= Abort
		do
			inspect a_kind
			when Session_start then Result := "session_start"
			when Resume then Result := "resume"
			when Hold then Result := "hold"
			when Flub then Result := "flub"
			when Rewind_to then Result := "rewind_to"
			when Count_in then Result := "count_in"
			when Edit then Result := "edit"
			when Star then Result := "star"
			when Reject then Result := "reject"
			when Marker then Result := "marker"
			when Skip then Result := "skip"
			when Align then Result := "align"
			when Wrap then Result := "wrap"
			when Abort then Result := "abort"
			end
		ensure
			named: not Result.is_empty
		end

end
