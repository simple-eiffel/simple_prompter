note
	description: "[
		Key combo -> logical control (PT_CONTROL). Modifiers use the Win32 MOD_* bits.
		A binding without modifiers is allowed only as a clicker/pedal key that is live
		while recording (the modifier-less hotkey gotcha: a bare global hotkey hijacks
		the key desktop-wide).
	]"
	author: "Larry Rix"

class
	PT_KEY_BINDING

create
	make

feature {NONE} -- Initialization

	make (a_control: INTEGER; a_modifiers: NATURAL_32; a_vkey: INTEGER; a_bare_while_recording: BOOLEAN)
		require
			control_known: a_control >= {PT_CONTROL}.Hold_toggle and a_control <= {PT_CONTROL}.Click_through
			modifiers_known: a_modifiers <= All_modifiers
			vkey_range: a_vkey > 0 and a_vkey <= 254
			interlock: a_modifiers /= 0 or a_bare_while_recording
		do
			control := a_control
			modifiers := a_modifiers
			vkey := a_vkey
			is_bare_while_recording := a_bare_while_recording
		ensure
			control_set: control = a_control
			key_set: modifiers = a_modifiers and vkey = a_vkey
			bare_set: is_bare_while_recording = a_bare_while_recording
		end

feature -- Constants

	Mod_alt: NATURAL_32 = 0x1
	Mod_control: NATURAL_32 = 0x2
	Mod_shift: NATURAL_32 = 0x4
	Mod_win: NATURAL_32 = 0x8
	All_modifiers: NATURAL_32 = 0xF

feature -- Access

	control: INTEGER
	modifiers: NATURAL_32
	vkey: INTEGER

	key_code: INTEGER_64
			-- Unique code of the combo.
		do
			Result := combo_code (modifiers, vkey)
		end

	combo_code (a_modifiers: NATURAL_32; a_vkey: INTEGER): INTEGER_64
			-- Code of combo (`a_modifiers', `a_vkey').
		do
			Result := a_modifiers.to_integer_64 * 65_536 + a_vkey
		ensure
			distinct_vkeys: Result \\ 65_536 = a_vkey
		end

feature -- Status

	is_bare_while_recording: BOOLEAN

	is_bare: BOOLEAN
		do
			Result := modifiers = 0
		end

invariant
	control_known: control >= {PT_CONTROL}.Hold_toggle and control <= {PT_CONTROL}.Click_through
	interlock: modifiers /= 0 or is_bare_while_recording
	vkey_range: vkey > 0 and vkey <= 254

end
