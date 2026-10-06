note
	description: "[
		The Take Studio state machine as data: the single place where allowed
		(state, action) pairs and their next states are decided (spec 07 section
		2.6). Recording-only actions (Star, Reject, Marker, Wrap, Abort) and the
		practice-only action Stop are filtered by `is_allowed'.
	]"
	author: "Larry Rix"

class
	PT_TRANSITIONS

create
	make

feature {NONE} -- Initialization

	make
			-- Fill the table.
		local
			s: PT_TAKE_STATE
			a: PT_ACTION
		do
			create s
			create a
			create table.make_filled (0, State_count, Action_count)
				-- Idle
			put (s.Idle, a.Play, s.Count_in)
			put (s.Idle, a.Record, s.Count_in)
				-- Count_in
			put (s.Count_in, a.Again, s.Count_in)
			put (s.Count_in, a.Hold, s.Held)
			put (s.Count_in, a.Wrap, s.Analyzing)
			put (s.Count_in, a.Stop, s.Idle)
			put (s.Count_in, a.Abort, s.Wrapped)
			put (s.Count_in, a.Count_in_done, s.Reading)
				-- Reading
			put (s.Reading, a.Again, s.Count_in)
			put (s.Reading, a.Hold, s.Held)
			put (s.Reading, a.Star, s.Reading)
			put (s.Reading, a.Reject, s.Reading)
			put (s.Reading, a.Marker, s.Reading)
			put (s.Reading, a.Wrap, s.Analyzing)
			put (s.Reading, a.Stop, s.Idle)
			put (s.Reading, a.Abort, s.Wrapped)
				-- Held
			put (s.Held, a.Again, s.Count_in)
			put (s.Held, a.Go, s.Count_in)
			put (s.Held, a.Back, s.Held)
			put (s.Held, a.Forward, s.Held)
			put (s.Held, a.Back_paragraph, s.Held)
			put (s.Held, a.Forward_paragraph, s.Held)
			put (s.Held, a.Pick_word, s.Held)
			put (s.Held, a.Edit_open, s.Editing)
			put (s.Held, a.Star, s.Held)
			put (s.Held, a.Reject, s.Held)
			put (s.Held, a.Marker, s.Held)
			put (s.Held, a.Skip, s.Held)
			put (s.Held, a.Wrap, s.Analyzing)
			put (s.Held, a.Stop, s.Idle)
			put (s.Held, a.Abort, s.Wrapped)
				-- Editing
			put (s.Editing, a.Edit_commit, s.Held)
			put (s.Editing, a.Edit_cancel, s.Held)
				-- Analyzing
			put (s.Analyzing, a.Analysis_done, s.Wrapped)
		ensure
			sized: table.height = State_count and table.width = Action_count
		end

feature -- Constants

	State_count: INTEGER = 7
	Action_count: INTEGER = 22

feature -- Queries

	table_entry (a_state, a_action: INTEGER): INTEGER
			-- Next state for (`a_state', `a_action'), 0 if the pair is not listed.
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		do
			Result := table.item (a_state, a_action)
		ensure
			zero_or_state: Result = 0 or (Result >= {PT_TAKE_STATE}.Idle and Result <= {PT_TAKE_STATE}.Wrapped)
		end

	is_recording_only (a_action: INTEGER): BOOLEAN
			-- Is `a_action' meaningful only while recording?
		do
			Result := a_action = {PT_ACTION}.Star or a_action = {PT_ACTION}.Reject or
				a_action = {PT_ACTION}.Marker or a_action = {PT_ACTION}.Wrap or a_action = {PT_ACTION}.Abort
		end

	is_practice_only (a_action: INTEGER): BOOLEAN
			-- Is `a_action' meaningful only while not recording?
		do
			Result := a_action = {PT_ACTION}.Stop
		end

	is_allowed (a_state, a_action: INTEGER; a_recording: BOOLEAN): BOOLEAN
			-- May `a_action' be performed in `a_state'?
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		do
			Result := table_entry (a_state, a_action) /= 0 and
				not (is_recording_only (a_action) and not a_recording) and
				not (is_practice_only (a_action) and a_recording)
		ensure
			listed: Result implies table_entry (a_state, a_action) /= 0
			recording_only: (is_recording_only (a_action) and not a_recording) implies not Result
			practice_only: (is_practice_only (a_action) and a_recording) implies not Result
		end

	next_state (a_state, a_action: INTEGER): INTEGER
			-- State after `a_action' in `a_state'.
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
			listed: table_entry (a_state, a_action) /= 0
		do
			Result := table_entry (a_state, a_action)
		ensure
			known: Result >= {PT_TAKE_STATE}.Idle and Result <= {PT_TAKE_STATE}.Wrapped
		end

feature {NONE} -- Implementation

	table: ARRAY2 [INTEGER]
			-- table (state, action) = next state, 0 = not allowed.

	put (a_state, a_action, a_next: INTEGER)
			-- List the pair.
		do
			table.put (a_next, a_state, a_action)
		end

invariant
	sized: table.height = State_count and table.width = Action_count

end
