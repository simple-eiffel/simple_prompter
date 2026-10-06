note
	description: "[
		Outcome of the analysis pass, written by the worker exe to
		analysis/*.json and read by the Edit Floor. Success XOR error.
	]"
	author: "Larry Rix"

class
	PT_ANALYSIS

create
	make, make_failed

feature {NONE} -- Initialization

	make (a_map: PT_SPEECH_MAP; a_timeline: PT_WORD_TIMELINE; a_attempts: LIST [PT_ATTEMPT];
			a_cuts: PT_CUT_LIST; a_flags: LIST [PT_FLAG]; a_decisions: LIST [STRING_32])
			-- Successful analysis.
		do
			speech_map := a_map
			timeline := a_timeline
			create attempts.make_from_iterable (a_attempts)
			cuts := a_cuts
			create flags.make_from_iterable (a_flags)
			create decisions.make_from_iterable (a_decisions)
			is_success := True
		ensure
			success: is_success and error = Void
			cuts_set: cuts = a_cuts
		end

	make_failed (a_error: READABLE_STRING_32)
			-- Failed analysis (the Edit Floor falls back to live marks).
		require
			reason_present: not a_error.is_empty
		do
			error := a_error.to_string_32
			create speech_map.make (0)
			create timeline.make
			create attempts.make (0)
			create cuts.make
			create flags.make (0)
			create decisions.make (0)
		ensure
			failed: not is_success and attached error
		end

feature -- Access

	speech_map: PT_SPEECH_MAP
	timeline: PT_WORD_TIMELINE
	attempts: ARRAYED_LIST [PT_ATTEMPT]
	cuts: PT_CUT_LIST
	flags: ARRAYED_LIST [PT_FLAG]
	decisions: ARRAYED_LIST [STRING_32]
	error: detachable STRING_32

feature -- Status

	is_success: BOOLEAN

invariant
	success_xor_error: is_success xor attached error

end
