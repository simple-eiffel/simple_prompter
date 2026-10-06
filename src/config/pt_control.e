note
	description: "[
		Logical controls: what a key means before the take state is known (reached as
		{PT_CONTROL}.Clicker_back etc.). PT_CONTROL_RESOLVER turns a control plus the
		current state into a PT_ACTION, so one clicker button can mean Again while
		reading and Back while held (review H5).
	]"
	author: "Larry Rix"

class
	PT_CONTROL

feature -- Constants

	Hold_toggle: INTEGER = 1
			-- Hold while reading or counting in; Go while held.
	Again: INTEGER = 2
	Go: INTEGER = 3
	Back: INTEGER = 4
	Forward: INTEGER = 5
	Back_paragraph: INTEGER = 6
	Forward_paragraph: INTEGER = 7
	Edit: INTEGER = 8
	Star: INTEGER = 9
	Reject: INTEGER = 10
	Marker: INTEGER = 11
	Skip: INTEGER = 12
	Wrap: INTEGER = 13
			-- Wrap while recording; Stop in practice.
	Play_stop: INTEGER = 14
			-- Play from idle; Stop in practice.
	Abort: INTEGER = 15
	Clicker_back: INTEGER = 16
			-- Again while reading or counting in; Back while held.
	Clicker_forward: INTEGER = 17
			-- Go while held.
	Clicker_hold: INTEGER = 18
			-- Same as Hold_toggle.
	Hide: INTEGER = 19
			-- App-level (no take action).
	Click_through: INTEGER = 20
			-- App-level (no take action).

end
