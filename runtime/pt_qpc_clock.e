note
	description: "The real clock: QueryPerformanceCounter milliseconds through SHELL_DESKTOP.now_ms."
	author: "Larry Rix"

class
	PT_QPC_CLOCK

inherit
	PT_CLOCK

create
	make

feature {NONE} -- Initialization

	make
		do
			create desktop
		end

feature -- Access

	now_ms: REAL_64
			-- Milliseconds since boot, from the performance counter.
		do
			Result := desktop.now_ms.max (0.0)
		end

feature {NONE} -- Implementation

	desktop: SHELL_DESKTOP

end
