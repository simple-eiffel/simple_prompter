note
	description: "Config cluster: keymap (combo -> control, modifier interlock, bare clicker keys), control resolver, settings."
	author: "Larry Rix"
	testing: "covers"

class
	TEST_CONFIG

inherit
	PT_TEST_SET

feature -- Tests: keymap

	test_defaults_need_modifiers
		local
			k: PT_KEYMAP
		do
			create k.make_default
			assert_true ("hold bound", k.has_control ({PT_CONTROL}.Hold_toggle))
			assert_integers_equal ("Ctrl+Alt+Space", {PT_CONTROL}.Hold_toggle,
				k.control_for ({PT_KEY_BINDING}.Mod_control | {PT_KEY_BINDING}.Mod_alt, k.Vk_space))
		end

	test_bare_key_needs_the_recording_flag
		do
			assert_true ("bare without flag refused", raises (agent
				local l_b: PT_KEY_BINDING
				do create l_b.make ({PT_CONTROL}.Clicker_back, 0, 0x21, False) end))
		end

	test_bare_keys_only_while_recording
		local
			k: PT_KEYMAP
		do
			create k.make
			k.bind_clicker_defaults
			assert_integers_equal ("ignored before recording", 0, k.control_for (0, k.Vk_prior))
			k.set_recording (True)
			k.activate_bare_keys
			assert_integers_equal ("live while recording", {PT_CONTROL}.Clicker_back, k.control_for (0, k.Vk_prior))
			k.set_recording (False)
			assert_false ("released on stop", k.bare_keys_active)
			assert_integers_equal ("ignored again", 0, k.control_for (0, k.Vk_prior))
		end

	test_activation_refused_outside_recording
		local
			k: PT_KEYMAP
		do
			create k.make
			assert_true ("refused", raises (agent k.activate_bare_keys))
		end

	test_two_keys_for_one_control
			-- Review H5: B and "." both hold.
		local
			k: PT_KEYMAP
		do
			create k.make
			k.bind_clicker_defaults
			assert_integers_equal ("two hold keys", 2, k.keys_for ({PT_CONTROL}.Clicker_hold))
		end

	test_rebinding_a_combo_replaces_it
			-- Review M15: one control per combo.
		local
			k: PT_KEYMAP
			l_ca: NATURAL_32
		do
			create k.make_default
			l_ca := {PT_KEY_BINDING}.Mod_control | {PT_KEY_BINDING}.Mod_alt
			k.bind (create {PT_KEY_BINDING}.make ({PT_CONTROL}.Skip, l_ca, k.Vk_space, False))
			assert_integers_equal ("now Skip", {PT_CONTROL}.Skip, k.control_for (l_ca, k.Vk_space))
			assert_false ("hold lost its only key", k.has_control ({PT_CONTROL}.Hold_toggle))
		end

feature -- Tests: control resolver

	test_clicker_back_depends_on_state
			-- Review H5: Again while reading, Back while held.
		local
			r: PT_CONTROL_RESOLVER
		do
			create r.make
			assert_integers_equal ("reading", {PT_ACTION}.Again, r.action_for ({PT_CONTROL}.Clicker_back, {PT_TAKE_STATE}.Reading, True))
			assert_integers_equal ("held", {PT_ACTION}.Back, r.action_for ({PT_CONTROL}.Clicker_back, {PT_TAKE_STATE}.Held, True))
			assert_integers_equal ("idle: nothing", 0, r.action_for ({PT_CONTROL}.Clicker_back, {PT_TAKE_STATE}.Idle, False))
		end

	test_hold_toggle_and_wrap_by_mode
		local
			r: PT_CONTROL_RESOLVER
		do
			create r.make
			assert_integers_equal ("hold while reading", {PT_ACTION}.Hold, r.action_for ({PT_CONTROL}.Hold_toggle, {PT_TAKE_STATE}.Reading, False))
			assert_integers_equal ("go while held", {PT_ACTION}.Go, r.action_for ({PT_CONTROL}.Hold_toggle, {PT_TAKE_STATE}.Held, False))
			assert_integers_equal ("wrap when recording", {PT_ACTION}.Wrap, r.action_for ({PT_CONTROL}.Wrap, {PT_TAKE_STATE}.Reading, True))
			assert_integers_equal ("stop in practice", {PT_ACTION}.Stop, r.action_for ({PT_CONTROL}.Wrap, {PT_TAKE_STATE}.Reading, False))
			assert_integers_equal ("hide is app-level", 0, r.action_for ({PT_CONTROL}.Hide, {PT_TAKE_STATE}.Reading, False))
		end

feature -- Tests: settings

	test_setters_save_and_clamp_by_contract
		local
			s: PT_SETTINGS
		do
			create s.make_in_memory
			s.set_font_size (40)
			assert_integers_equal ("set", 40, s.font_size)
			assert_integers_equal ("saved once", 1, s.save_count)
			assert_true ("out of range refused", raises (agent s.set_font_size (500)))
		end

	test_default_mode_waits_for_proof
		local
			s: PT_SETTINGS
		do
			create s.make_in_memory
			assert_integers_equal ("voice-gated first", {PT_FOLLOW_MODE}.Voice_gated, s.default_mode (True))
			s.mark_tracking_proven
			assert_integers_equal ("tracking once proven", {PT_FOLLOW_MODE}.Tracking, s.default_mode (True))
			assert_integers_equal ("no GPU, no tracking", {PT_FOLLOW_MODE}.Voice_gated, s.default_mode (False))
		end

end
