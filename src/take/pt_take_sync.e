note
	description: "[
		A take's picture-to-sound sync (0.3.6): how far the picture runs behind the
		sound, in milliseconds (negative: the picture runs ahead). The raw recording
		is never changed; previews and the final render move the picture by this
		much (PT_RENDER_PLAN), so a wrong value is fixed by changing it and
		rendering again. Kept beside the take as sync.toml. A take without one
		starts from the last value chosen (PT_SETTINGS.video_delay_ms), and every
		change here becomes that starting value for the next take.
	]"
	author: "Larry Rix"

class
	PT_TAKE_SYNC

create
	make

feature {NONE} -- Initialization

	make (a_path: READABLE_STRING_32; a_default_ms: INTEGER)
			-- The sync kept at `a_path', or `a_default_ms' when there is none yet.
		require
			path_present: not a_path.is_empty
			default_in_range: is_in_range (a_default_ms)
		do
			path := a_path.to_string_32
			delay_ms := a_default_ms
			load
		ensure
			path_set: path.same_string (a_path)
			in_range: is_in_range (delay_ms)
		end

feature -- Constants

	Min_ms: INTEGER = -500
	Max_ms: INTEGER = 1000
	Step_ms: INTEGER = 10

feature -- Access

	path: STRING_32
			-- sync.toml in the session folder.

	delay_ms: INTEGER
			-- How far the picture runs behind the sound.

	is_measured: BOOLEAN
			-- Was `delay_ms' set by Measure (and not changed by hand since)?

	is_stored: BOOLEAN
			-- Is `delay_ms' this take's own (read from or written to `path')?

feature -- Status

	is_in_range (a_ms: INTEGER): BOOLEAN
		do
			Result := a_ms >= Min_ms and a_ms <= Max_ms
		end

feature -- Element change

	set_delay (a_ms: INTEGER)
			-- Use `a_ms' for this take, chosen by hand.
		require
			in_range: is_in_range (a_ms)
		do
			delay_ms := a_ms
			is_measured := False
			save
		ensure
			set: delay_ms = a_ms
			by_hand: not is_measured
		end

	step (a_steps: INTEGER)
			-- Change by `a_steps' x `Step_ms', kept in range.
		do
			set_delay ((delay_ms + a_steps * Step_ms).max (Min_ms).min (Max_ms))
		ensure
			in_range: is_in_range (delay_ms)
		end

	set_measured (a_ms: INTEGER)
			-- Use `a_ms', found by Measure.
		require
			in_range: is_in_range (a_ms)
		do
			delay_ms := a_ms
			is_measured := True
			save
		ensure
			set: delay_ms = a_ms
			measured: is_measured
		end

feature -- Formatting

	text: STRING_32
			-- "110 ms", "-40 ms".
		do
			Result := delay_ms.out.to_string_32 + {STRING_32} " ms"
		end

feature {NONE} -- Storage

	load
			-- Read `path' when it holds a sensible value.
		local
			l_raw: STRING_8
		do
			if (create {SIMPLE_FILE}.make (path)).exists then
				create l_raw.make (64)
				across (create {SIMPLE_FILE}.make (path)).binary_content as ic loop
					l_raw.append_character (ic.to_character_8)
				end
				if attached (create {SIMPLE_TOML}).parse ((create {SIMPLE_ENCODING}.make).utf_8_to_utf_32 (l_raw)) as al_root
					and then attached al_root.table_item ("sync") as t and then t.has ("delay_ms")
					and then t.integer_item ("delay_ms") >= Min_ms and then t.integer_item ("delay_ms") <= Max_ms then
					delay_ms := t.integer_item ("delay_ms").to_integer_32
					is_measured := t.has ("measured") and then t.boolean_item ("measured")
					is_stored := True
				end
			end
		end

	save
			-- Write `delay_ms' to `path'.
		local
			l_table, l_root: TOML_TABLE
			l_ok: BOOLEAN
		do
			create l_table.make
			l_table := l_table.with_integer ("delay_ms", delay_ms).with_boolean ("measured", is_measured)
			create l_root.make
			l_root := l_root.with_table ("sync", l_table)
			l_ok := (create {SIMPLE_FILE}.make (path)).set_content ((create {SIMPLE_TOML}).serialize (l_root))
			is_stored := True
		ensure
			stored: is_stored
		end

invariant
	in_range: is_in_range (delay_ms)

end
