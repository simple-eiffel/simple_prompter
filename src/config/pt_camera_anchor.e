note
	description: "The calibrated camera lens point on one monitor (physical pixels); the pill anchors just below it."
	author: "Larry Rix"

class
	PT_CAMERA_ANCHOR

create
	make

feature {NONE} -- Initialization

	make (a_monitor_key: READABLE_STRING_32; a_x, a_y: INTEGER)
			-- Lens at (`a_x', `a_y') on the monitor identified by `a_monitor_key' (device name + resolution).
		require
			key_present: not a_monitor_key.is_empty
		do
			monitor_key := a_monitor_key.to_string_32
			x := a_x
			y := a_y
		ensure
			key_set: monitor_key.same_string (a_monitor_key)
			point_set: x = a_x and y = a_y
		end

feature -- Access

	monitor_key: STRING_32
	x, y: INTEGER

invariant
	key_present: not monitor_key.is_empty

end
