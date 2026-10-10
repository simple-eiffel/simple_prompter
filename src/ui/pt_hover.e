note
	description: "[
		What the pointer rests on, and when its tooltip shows (0.4.0): one model for
		every surface - the transport bar, the pill's rails, each callout. A target is
		a nonzero code chosen by the surface; resting on one for `Tooltip_delay_ms'
		shows its tooltip, unless tooltips are turned off (Settings: Show tooltips).
		Leaving the surface forgets the target.
	]"
	author: "Larry Rix"

class
	PT_HOVER

create
	make

feature {NONE} -- Initialization

	make
		do
			create tooltip.make_empty
			is_enabled := True
		ensure
			enabled: is_enabled
			nothing_hovered: hovered = 0 and not is_tooltip_shown
		end

feature -- Constants

	Tooltip_delay_ms: REAL_64 = 450.0
			-- How long the pointer rests on a target before its tooltip shows.

feature -- Access

	is_enabled: BOOLEAN
			-- Are tooltips shown at all?

	is_pointer_in: BOOLEAN
			-- Is the pointer over the surface?

	hovered: INTEGER
			-- The target under the pointer (0: none).

	hover_started_ms: REAL_64
			-- When the pointer arrived on `hovered'.

	tooltip: STRING_32
			-- What `hovered' does (set with the target).

	is_tooltip_shown: BOOLEAN
			-- Is the tooltip for `hovered' showing?

	signature: INTEGER
			-- Changes whenever what is drawn for the hover changes.
		do
			Result := hovered * 4 + (if is_pointer_in then 1 else 0 end) + (if is_tooltip_shown then 2 else 0 end)
		end

feature -- Element change

	set_enabled (a_on: BOOLEAN)
			-- Show tooltips, or never.
		do
			is_enabled := a_on
			if not a_on then
				is_tooltip_shown := False
			end
		ensure
			set: is_enabled = a_on
			off_hides: not a_on implies not is_tooltip_shown
		end

	set_pointer_in (a_on: BOOLEAN)
			-- The pointer is over the surface, or has left it (then nothing is hovered).
		do
			is_pointer_in := a_on
			if not a_on then
				hovered := 0
				tooltip.wipe_out
				is_tooltip_shown := False
			end
		ensure
			set: is_pointer_in = a_on
			left_forgets: not a_on implies (hovered = 0 and not is_tooltip_shown)
		end

	set_hovered (a_target: INTEGER; a_tooltip: READABLE_STRING_32; a_now_ms: REAL_64)
			-- The pointer is on `a_target' (0: on nothing) at `a_now_ms'; a new target restarts the delay.
		require
			tooltip_for_a_target: a_target = 0 implies a_tooltip.is_empty
		do
			if a_target /= hovered then
				hovered := a_target
				hover_started_ms := a_now_ms
				is_tooltip_shown := False
			end
			tooltip := a_tooltip.to_string_32
		ensure
			set: hovered = a_target
			new_target_waits: a_target /= old hovered implies (not is_tooltip_shown and hover_started_ms = a_now_ms)
		end

	update (a_now_ms: REAL_64)
			-- Show the tooltip once the pointer has rested on its target long enough.
		do
			is_tooltip_shown := is_enabled and hovered /= 0 and is_pointer_in and not tooltip.is_empty
				and a_now_ms - hover_started_ms >= Tooltip_delay_ms
		ensure
			needs_a_target: is_tooltip_shown implies hovered /= 0
			only_when_enabled: is_tooltip_shown implies is_enabled
		end

invariant
	tooltip_needs_target: is_tooltip_shown implies hovered /= 0

end
