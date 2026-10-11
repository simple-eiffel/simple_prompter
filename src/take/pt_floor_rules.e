note
	description: "[
		Which Last take buttons can be used while Render, Publish or Measure runs, and why
		not (0.6.0; the table Larry approved 2026-10-11: "for buttons that should not be
		clicked while the process is progressing ... disable the other buttons").

		                  Rendering   Publishing  Measuring
		  Render          busy        off         on
		  Play final      off         off         on        (needs final.mp4)
		  Open folder     on          on          on
		  Publish         off         busy        on        (needs a render)
		  Sync - / +      off         on          off
		  Previews        on          on          on
		  Measure         on          on          busy

		Render writes final.mp4 and Publish replaces it, so neither may run with the other,
		and final.mp4 is not played while either writes it; the sync is not changed while a
		render uses it or Measure sets it. Previews read raw.mkv and run beside anything.
	]"
	author: "Larry Rix"

class
	PT_FLOOR_RULES

create
	make

feature {NONE} -- Initialization

	make (a_rendering, a_publishing, a_measuring, a_has_final, a_has_render: BOOLEAN)
			-- The rules while rendering, publishing or measuring; `a_has_final': out\final.mp4 exists;
			-- `a_has_render': a render Publish can read (final.mp4 or its kept copy).
		do
			is_rendering := a_rendering
			is_publishing := a_publishing
			is_measuring := a_measuring
			has_final := a_has_final
			has_render := a_has_render
		ensure
			set: is_rendering = a_rendering and is_publishing = a_publishing and is_measuring = a_measuring
				and has_final = a_has_final and has_render = a_has_render
		end

feature -- Buttons

	Render: INTEGER = 1
	Play_final: INTEGER = 2
	Open_folder: INTEGER = 3
	Publish: INTEGER = 4
	Sync_step: INTEGER = 5
	Preview: INTEGER = 6
	Measure: INTEGER = 7

feature -- Status

	is_rendering, is_publishing, is_measuring, has_final, has_render: BOOLEAN

	is_enabled (a_button: INTEGER): BOOLEAN
			-- Can `a_button' be used now?
		require
			known: a_button >= Render and a_button <= Measure
		do
			Result := reason (a_button).is_empty
		ensure
			definition: Result = reason (a_button).is_empty
		end

	is_busy (a_button: INTEGER): BOOLEAN
			-- Is `a_button''s own job running (its progress bar shows)?
		do
			Result := (a_button = Render and is_rendering) or (a_button = Publish and is_publishing)
				or (a_button = Measure and is_measuring)
		end

	reason (a_button: INTEGER): STRING_32
			-- Why `a_button' cannot be used now (empty when it can).
		require
			known: a_button >= Render and a_button <= Measure
		do
			create Result.make_empty
			inspect a_button
			when Render then
				if is_rendering then
					Result := {STRING_32} "rendering now"
				elseif is_publishing then
					Result := {STRING_32} "wait: publishing"
				end
			when Play_final then
				if is_rendering then
					Result := {STRING_32} "wait: rendering writes final.mp4"
				elseif is_publishing then
					Result := {STRING_32} "wait: publishing replaces final.mp4"
				elseif not has_final then
					Result := {STRING_32} "render first: there is no final.mp4 yet"
				end
			when Publish then
				if is_publishing then
					Result := {STRING_32} "publishing now"
				elseif is_rendering then
					Result := {STRING_32} "wait: rendering"
				elseif not has_render then
					Result := {STRING_32} "render first: there is no final.mp4 yet"
				end
			when Sync_step then
				if is_rendering then
					Result := {STRING_32} "wait: the render uses this sync"
				elseif is_measuring then
					Result := {STRING_32} "wait: measuring the sync"
				end
			when Measure then
				if is_measuring then
					Result := {STRING_32} "measuring now"
				end
			else
					-- Open folder and the previews: always.
			end
		end

end
