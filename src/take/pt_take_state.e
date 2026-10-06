note
	description: "Take Studio states (reached as {PT_TAKE_STATE}.Reading etc.)."
	author: "Larry Rix"

class
	PT_TAKE_STATE

feature -- Constants

	Idle: INTEGER = 1
	Count_in: INTEGER = 2
	Reading: INTEGER = 3
	Held: INTEGER = 4
	Editing: INTEGER = 5
	Analyzing: INTEGER = 6
	Wrapped: INTEGER = 7

end
