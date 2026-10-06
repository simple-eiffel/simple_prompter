note
	description: "[
		Take Studio actions (reached as {PT_ACTION}.Again etc.). Every control
		surface (hotkeys, mouse on the pill, clicker or pedal keys) maps to these;
		voice commands are deferred (spec F-02).
	]"
	author: "Larry Rix"

class
	PT_ACTION

feature -- Constants

	Play: INTEGER = 1
			-- Practice: count in without recording; no journal.
	Record: INTEGER = 2
	Again: INTEGER = 3
	Hold: INTEGER = 4
	Go: INTEGER = 5
	Back: INTEGER = 6
	Forward: INTEGER = 7
	Back_paragraph: INTEGER = 8
	Forward_paragraph: INTEGER = 9
	Pick_word: INTEGER = 10
			-- Via PT_TAKE_CONTROLLER.pick_word (needs an index).
	Edit_open: INTEGER = 11
	Edit_commit: INTEGER = 12
			-- Via PT_TAKE_CONTROLLER.commit_edit (needs text).
	Edit_cancel: INTEGER = 13
	Star: INTEGER = 14
	Reject: INTEGER = 15
	Marker: INTEGER = 16
			-- Via PT_TAKE_CONTROLLER.add_marker (optional text).
	Skip: INTEGER = 17
	Wrap: INTEGER = 18
			-- Recording: stop and analyze.
	Stop: INTEGER = 19
			-- Practice: back to idle.
	Abort: INTEGER = 20
			-- Recording: stop, keep files, no analysis.
	Count_in_done: INTEGER = 21
	Analysis_done: INTEGER = 22

end
