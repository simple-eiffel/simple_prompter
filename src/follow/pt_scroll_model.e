note
	description: "[
		The continuous display position: the follower's target smoothed by a
		critically damped spring, mapped to a vertical pixel offset by the layout.
		Driven by elapsed time from a monotone clock, never by tick counts, so
		timer jitter does not show (spec D-008).
	]"
	author: "Larry Rix"

class
	PT_SCROLL_MODEL

create
	make

feature {NONE} -- Initialization

	make (a_follower: PT_FOLLOWER; a_layout: PT_LAYOUT; a_spring: PT_SPRING)
			-- Scroll driven by `a_follower', mapped by `a_layout', smoothed by `a_spring'.
		do
			follower := a_follower
			layout := a_layout
			spring := a_spring
		ensure
			follower_set: follower = a_follower
			layout_set: layout = a_layout
			spring_set: spring = a_spring
			at_start: position = 0 and last_ms = 0 and not is_started
		end

feature -- Access

	follower: PT_FOLLOWER
	layout: PT_LAYOUT
	spring: PT_SPRING

	position: REAL_64
			-- Smoothed fractional word position.

	last_ms: REAL_64
			-- Clock time of the last `tick'.

	y_offset: REAL_64
			-- Vertical pixel offset for the renderer.
		require
			laid_out: position <= layout.word_count
		do
			Result := layout.y_of (position)
		ensure
			non_negative: Result >= 0
		end

feature -- Status

	is_started: BOOLEAN
			-- Has the first tick set the time base?

feature -- Element change

	tick (a_now_ms: REAL_64)
			-- Advance the follower and the smoothing to clock time `a_now_ms'.
		require
			not_backward: is_started implies a_now_ms >= last_ms
		local
			l_dt: REAL_64
		do
			if is_started then
				l_dt := (a_now_ms - last_ms) / 1000.0
			end
			follower.advance (l_dt)
			if follower.target < position then
					-- A restart moved the target back: snap, never rewind visibly (review H2).
				jump_to (follower.target)
			else
				spring.step (follower.target, l_dt)
				position := spring.value.max (position).min (follower.target)
			end
			last_ms := a_now_ms
			is_started := True
		ensure
			time_kept: last_ms = a_now_ms
			started: is_started
			snaps_back: follower.target < old position implies position = follower.target
			forward_otherwise: follower.target >= old position implies
					(position >= old position - 1.0e-9 and position <= follower.target + 1.0e-9)
			bounded: position >= 0 and position <= follower.word_count
		end

	jump_to (a_position: REAL_64)
			-- Snap to `a_position' with no smoothing (after a caret change).
		require
			in_range: a_position >= 0 and a_position <= follower.word_count
		do
			position := a_position
			spring.reset (a_position)
		ensure
			placed: position = a_position
		end

invariant
	position_non_negative: position >= 0
	time_non_negative: last_ms >= 0

end
