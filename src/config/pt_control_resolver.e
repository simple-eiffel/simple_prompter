note
	description: "[
		Single place where a logical control becomes a Take Studio action, depending
		on the state and on recording vs practice. Only allowed actions are returned
		(0 = nothing to do, or an app-level control such as Hide).
	]"
	author: "Larry Rix"

class
	PT_CONTROL_RESOLVER

create
	make

feature {NONE} -- Initialization

	make
		do
			create transitions.make
		end

feature -- Access

	transitions: PT_TRANSITIONS

feature -- Queries

	action_for (a_control, a_state: INTEGER; a_recording: BOOLEAN): INTEGER
			-- Action for `a_control' in `a_state', or 0.
		require
			control_known: a_control >= {PT_CONTROL}.Hold_toggle and a_control <= {PT_CONTROL}.Click_through
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
		local
			l_candidate: INTEGER
		do
			l_candidate := candidate (a_control, a_state, a_recording)
			if l_candidate /= 0 and then transitions.is_allowed (a_state, l_candidate, a_recording) then
				Result := l_candidate
			end
		ensure
			allowed_or_none: Result /= 0 implies transitions.is_allowed (a_state, Result, a_recording)
			app_level_none: (a_control = {PT_CONTROL}.Hide or a_control = {PT_CONTROL}.Click_through) implies Result = 0
			clicker_back_reading: (a_control = {PT_CONTROL}.Clicker_back and a_state = {PT_TAKE_STATE}.Reading) implies Result = {PT_ACTION}.Again
			clicker_back_held: (a_control = {PT_CONTROL}.Clicker_back and a_state = {PT_TAKE_STATE}.Held) implies Result = {PT_ACTION}.Back
			hold_toggle_held: (a_control = {PT_CONTROL}.Hold_toggle and a_state = {PT_TAKE_STATE}.Held) implies Result = {PT_ACTION}.Go
		end

feature {NONE} -- Implementation

	candidate (a_control, a_state: INTEGER; a_recording: BOOLEAN): INTEGER
			-- Unfiltered mapping.
		local
			l_held: BOOLEAN
		do
			l_held := a_state = {PT_TAKE_STATE}.Held
			inspect a_control
			when {PT_CONTROL}.Hold_toggle, {PT_CONTROL}.Clicker_hold then
				if l_held then Result := {PT_ACTION}.Go else Result := {PT_ACTION}.Hold end
			when {PT_CONTROL}.Clicker_back then
				if l_held then Result := {PT_ACTION}.Back else Result := {PT_ACTION}.Again end
			when {PT_CONTROL}.Clicker_forward then
				Result := {PT_ACTION}.Go
			when {PT_CONTROL}.Again then Result := {PT_ACTION}.Again
			when {PT_CONTROL}.Go then Result := {PT_ACTION}.Go
			when {PT_CONTROL}.Back then Result := {PT_ACTION}.Back
			when {PT_CONTROL}.Forward then Result := {PT_ACTION}.Forward
			when {PT_CONTROL}.Back_paragraph then Result := {PT_ACTION}.Back_paragraph
			when {PT_CONTROL}.Forward_paragraph then Result := {PT_ACTION}.Forward_paragraph
			when {PT_CONTROL}.Edit then Result := {PT_ACTION}.Edit_open
			when {PT_CONTROL}.Star then Result := {PT_ACTION}.Star
			when {PT_CONTROL}.Reject then Result := {PT_ACTION}.Reject
			when {PT_CONTROL}.Marker then Result := {PT_ACTION}.Marker
			when {PT_CONTROL}.Skip then Result := {PT_ACTION}.Skip
			when {PT_CONTROL}.Wrap then
				if a_recording then Result := {PT_ACTION}.Wrap else Result := {PT_ACTION}.Stop end
			when {PT_CONTROL}.Play_stop then
				if a_state = {PT_TAKE_STATE}.Idle then Result := {PT_ACTION}.Play else Result := {PT_ACTION}.Stop end
			when {PT_CONTROL}.Abort then Result := {PT_ACTION}.Abort
			else
				-- Hide, Click_through: app-level.
			end
		end

end
