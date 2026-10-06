note
	description: "[
		Key combos -> logical controls for every control surface (keyboard hotkeys,
		clicker and pedal keys). One control may have several keys; one key has exactly
		one control (rebinding replaces it). Bare (modifier-less) clicker keys are live
		only while recording and are released when recording ends (DR-014, FR-T04).
		PT_CONTROL_RESOLVER turns a control into an action for the current state.
	]"
	author: "Larry Rix"

class
	PT_KEYMAP

create
	make, make_default

feature {NONE} -- Initialization

	make
			-- No bindings.
		do
			create bindings.make (32)
		ensure
			empty: binding_count = 0
			not_recording: not is_recording and not bare_keys_active
		end

	make_default
			-- Ctrl+Alt hotkeys of spec 07 section 2.14 (no bare keys; see `bind_clicker_defaults').
		local
			l_ca: NATURAL_32
		do
			make
			l_ca := {PT_KEY_BINDING}.Mod_control | {PT_KEY_BINDING}.Mod_alt
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Hold_toggle, l_ca, Vk_space, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Again, l_ca, Vk_back, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Go, l_ca, Vk_return, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Back, l_ca, Vk_left, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Forward, l_ca, Vk_right, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Edit, l_ca, Vk_e, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Star, l_ca, Vk_s, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Reject, l_ca, Vk_x, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Marker, l_ca, Vk_n, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Wrap, l_ca, Vk_end, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Play_stop, l_ca, Vk_p, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Hide, l_ca, Vk_h, False))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Click_through, l_ca, Vk_i, False))
		ensure
			hold_bound: has_control ({PT_CONTROL}.Hold_toggle)
			again_bound: has_control ({PT_CONTROL}.Again)
			wrap_bound: has_control ({PT_CONTROL}.Wrap)
			no_bare_defaults: across bindings as ic all not ic.is_bare end
		end

feature -- Constants (Win32 virtual keys)

	Vk_back: INTEGER = 0x08
	Vk_return: INTEGER = 0x0D
	Vk_space: INTEGER = 0x20
	Vk_prior: INTEGER = 0x21
			-- PageUp (clicker Back).
	Vk_next: INTEGER = 0x22
			-- PageDown (clicker Forward).
	Vk_end: INTEGER = 0x23
	Vk_left: INTEGER = 0x25
	Vk_right: INTEGER = 0x27
	Vk_b: INTEGER = 0x42
	Vk_e: INTEGER = 0x45
	Vk_h: INTEGER = 0x48
	Vk_i: INTEGER = 0x49
	Vk_n: INTEGER = 0x4E
	Vk_p: INTEGER = 0x50
	Vk_s: INTEGER = 0x53
	Vk_x: INTEGER = 0x58
	Vk_oem_period: INTEGER = 0xBE

feature -- Access

	binding_count: INTEGER
		do
			Result := bindings.count
		end

	has_control (a_control: INTEGER): BOOLEAN
			-- Is some key bound to `a_control'?
		do
			Result := across bindings as ic some ic.control = a_control end
		end

	keys_for (a_control: INTEGER): INTEGER
			-- Number of keys bound to `a_control'.
		do
			across bindings as ic loop
				if ic.control = a_control then
					Result := Result + 1
				end
			end
		end

	control_for (a_modifiers: NATURAL_32; a_vkey: INTEGER): INTEGER
			-- Control bound to the key press, 0 if none (bare keys only while active).
		local
			l_code: INTEGER_64
		do
			l_code := a_modifiers.to_integer_64 * 65_536 + a_vkey
			if attached bindings.item (l_code) as al_b and then (not al_b.is_bare or bare_keys_active) then
				Result := al_b.control
			end
		ensure
			bare_ignored_unless_active: (a_modifiers = 0 and not bare_keys_active) implies Result = 0
		end

	all_bindings: ARRAYED_LIST [PT_KEY_BINDING]
			-- Every binding (a fresh list), for registering them with the system.
		do
			create Result.make (binding_count)
			across bindings as ic loop
				Result.extend (ic)
			end
		ensure
			complete: Result.count = binding_count
		end

feature -- Status

	is_recording: BOOLEAN
	bare_keys_active: BOOLEAN

feature -- Model

	combos_model: MML_SET [INTEGER_64]
			-- Bound key combos.
		do
			create Result
			across bindings as ic loop
				Result := Result & ic.key_code
			end
		ensure
			same_count: Result.count = binding_count
		end

feature -- Element change

	bind (a_binding: PT_KEY_BINDING)
			-- Bind (or rebind) the combo of `a_binding'.
		do
			bindings.force (a_binding, a_binding.key_code)
		ensure
			bound: attached bindings.item (a_binding.key_code) as al_b and then al_b = a_binding
			others_kept: ((combos_model / a_binding.key_code) |=| (old combos_model / a_binding.key_code))
		end

	bind_clicker_defaults
			-- Bare clicker keys, live only while recording: PageUp = Clicker_back,
			-- PageDown = Clicker_forward, B and "." = Clicker_hold.
		do
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Clicker_back, 0, Vk_prior, True))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Clicker_forward, 0, Vk_next, True))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Clicker_hold, 0, Vk_b, True))
			bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Clicker_hold, 0, Vk_oem_period, True))
		ensure
			two_hold_keys: keys_for ({PT_CONTROL}.Clicker_hold) >= 2
		end

	set_recording (a_recording: BOOLEAN)
			-- Recording started or ended; ending releases bare keys.
		do
			is_recording := a_recording
			if not a_recording then
				bare_keys_active := False
			end
		ensure
			set: is_recording = a_recording
			released: not a_recording implies not bare_keys_active
		end

	activate_bare_keys
		require
			recording: is_recording
		do
			bare_keys_active := True
		ensure
			active: bare_keys_active
		end

	deactivate_bare_keys
		do
			bare_keys_active := False
		ensure
			inactive: not bare_keys_active
		end

feature {NONE} -- Implementation

	bindings: HASH_TABLE [PT_KEY_BINDING, INTEGER_64]
			-- By combo code.

invariant
	bare_only_when_recording: bare_keys_active implies is_recording

end
