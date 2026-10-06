note
	description: "[
		The Take Studio state machine (spec F-01 section 4.1). Maps actions from
		any control surface to state changes, journal events (while recording)
		and follower effects. Transitions come only from PT_TRANSITIONS (single
		choice); the event mapping lives only in `perform' (spec 07 section 2.12).
		Never blocks: the only I/O is the journal's per-event flush.
	]"
	author: "Larry Rix"

class
	PT_TAKE_CONTROLLER

create
	make

feature {NONE} -- Initialization

	make (a_history: PT_SCRIPT_HISTORY; a_journal: PT_JOURNAL; a_recording_clock: PT_RECORDING_CLOCK;
			a_clock: PT_CLOCK; a_follower: PT_FOLLOWER; a_policy: PT_RESTART_POLICY)
			-- Idle controller over `a_history'.
		require
			has_revision: a_history.revision_count >= 1
			follower_sized: a_follower.word_count = a_history.current_revision.word_count
		do
			history := a_history
			journal := a_journal
			recording_clock := a_recording_clock
			clock := a_clock
			follower := a_follower
			policy := a_policy
			create transitions.make
			state := {PT_TAKE_STATE}.Idle
			count_in_seconds := Default_count_in
			alignment_confidence := 1.0
			if a_history.current_revision.word_count > 0 then
				caret := 1
				last_confident_word := 1
			end
		ensure
			idle: state = {PT_TAKE_STATE}.Idle
			not_recording: not is_recording
			caret_at_start: caret = a_history.current_revision.word_count.min (1)
			history_set: history = a_history
			journal_set: journal = a_journal
			follower_set: follower = a_follower
		end

feature -- Constants

	Default_count_in: REAL_64 = 2.0
			-- Seconds.

feature -- Access

	history: PT_SCRIPT_HISTORY
	journal: PT_JOURNAL
	recording_clock: PT_RECORDING_CLOCK
	clock: PT_CLOCK
	follower: PT_FOLLOWER
	policy: PT_RESTART_POLICY
	transitions: PT_TRANSITIONS

	state: INTEGER
			-- Current {PT_TAKE_STATE}.

	caret: INTEGER
			-- Restart word (0 only when the script is empty).

	count_in_seconds: REAL_64
			-- Count-in length.

	edit_first, edit_last: INTEGER
			-- Word range opened by Edit_open (the caret's passage).

	last_again_target: INTEGER
			-- Caret chosen by the most recent Again (review M7: computed only for Again).

	alignment_confidence: REAL_64
			-- Confidence of the latest sampled alignment.

	last_confident_word: INTEGER
			-- Latest word aligned with confidence >= Confident_level.

	Confident_level: REAL_64 = 0.6

	revision: PT_SCRIPT_REVISION
			-- Current script revision.
		do
			Result := history.current_revision
		end

	current_rt: REAL_64
			-- Recording time now.
		do
			Result := recording_clock.rt_at (clock.now_ms.max (recording_clock.observed_at_ms))
		ensure
			non_negative: Result >= 0
		end

	reader_position: INTEGER
			-- Word the follower is on (1..word_count; 0 for an empty script).
		do
			if revision.word_count > 0 then
				Result := (follower.target.floor + 1).min (revision.word_count).max (1)
			end
		ensure
			in_script: Result >= 0 and Result <= revision.word_count
		end

	again_target: INTEGER
			-- Caret Again would choose now (0 for an empty script).
		do
			if revision.word_count > 0 then
				Result := policy.again_caret (revision, reader_position,
					alignment_confidence >= Confident_level, last_confident_word.min (reader_position).max (1))
			end
		ensure
			in_script: Result >= 0 and Result <= revision.word_count
		end

feature -- Status

	is_recording: BOOLEAN
			-- Is a recording session rolling (journal active)?

	is_allowed (a_action: INTEGER): BOOLEAN
			-- May `a_action' be performed now?
		require
			known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		do
			Result := transitions.is_allowed (state, a_action, is_recording) and
				(revision.word_count > 0 or not (a_action = {PT_ACTION}.Play or a_action = {PT_ACTION}.Record))
		ensure
			table_rules: Result implies transitions.is_allowed (state, a_action, is_recording)
			nothing_to_read: (revision.word_count = 0 and (a_action = {PT_ACTION}.Play or a_action = {PT_ACTION}.Record)) implies not Result
		end

	needs_argument (a_action: INTEGER): BOOLEAN
			-- Must `a_action' go through its own command (pick_word, commit_edit, add_marker)?
		do
			Result := a_action = {PT_ACTION}.Pick_word or a_action = {PT_ACTION}.Edit_commit or a_action = {PT_ACTION}.Marker
		end

	is_browse (a_action: INTEGER): BOOLEAN
			-- Does `a_action' only move the caret?
		do
			Result := a_action = {PT_ACTION}.Back or a_action = {PT_ACTION}.Forward or
				a_action = {PT_ACTION}.Back_paragraph or a_action = {PT_ACTION}.Forward_paragraph
		end

feature -- Commands

	perform (a_action: INTEGER)
			-- Carry out `a_action' (events and follower effects per spec 07 section 2.12).
		require
			known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
			no_argument: not needs_argument (a_action)
			allowed: is_allowed (a_action)
		local
			l_from, l_reader, l_first, l_last, l_from_rev: INTEGER
			l_first_id, l_last_id: PT_WORD_ID
		do
			l_from := state
			if a_action = {PT_ACTION}.Record then
				is_recording := True
			end
			inspect a_action
			when {PT_ACTION}.Play, {PT_ACTION}.Record then
				follower.hold
				follower.set_caret (caret - 1)
				log (create {PT_TAKE_EVENT}.make_session_start (stamp, revision.number, {STRING_32} "follow"))
				log (create {PT_TAKE_EVENT}.make_count_in (stamp, count_in_seconds))
			when {PT_ACTION}.Again then
				l_reader := reader_position
				last_again_target := again_target
				if l_reader >= 1 then
					log (create {PT_TAKE_EVENT}.make_flub (stamp, revision.word (l_reader).id, "user"))
				end
				caret := last_again_target
				log (create {PT_TAKE_EVENT}.make_rewind_to (stamp, revision.word (caret).id, {STRING_32} "again_default"))
				log (create {PT_TAKE_EVENT}.make_count_in (stamp, count_in_seconds))
				follower.hold
				follower.set_caret (caret - 1)
			when {PT_ACTION}.Hold then
				follower.hold
				log (create {PT_TAKE_EVENT}.make_hold (stamp, "user"))
			when {PT_ACTION}.Go then
				follower.hold
				follower.set_caret (caret - 1)
				log (create {PT_TAKE_EVENT}.make_count_in (stamp, count_in_seconds))
			when {PT_ACTION}.Count_in_done then
				follower.set_caret (caret - 1)
				follower.release
				log (create {PT_TAKE_EVENT}.make_resume (stamp, revision.word (caret).id, revision.number))
			when {PT_ACTION}.Back then
				caret := policy.step_back (revision, caret, policy.Unit_passage)
			when {PT_ACTION}.Forward then
				caret := policy.step_forward (revision, caret, policy.Unit_passage)
			when {PT_ACTION}.Back_paragraph then
				caret := policy.step_back (revision, caret, policy.Unit_paragraph)
			when {PT_ACTION}.Forward_paragraph then
				caret := policy.step_forward (revision, caret, policy.Unit_paragraph)
			when {PT_ACTION}.Edit_open then
				edit_first := revision.passage (revision.passage_of (caret)).first_word
				edit_last := revision.passage (revision.passage_of (caret)).last_word
			when {PT_ACTION}.Star then
				log (create {PT_TAKE_EVENT}.make_star (stamp, "user"))
			when {PT_ACTION}.Reject then
				log (create {PT_TAKE_EVENT}.make_reject (stamp, "user"))
			when {PT_ACTION}.Skip then
				l_first := revision.passage (revision.passage_of (caret)).first_word
				l_last := revision.passage (revision.passage_of (caret)).last_word
				l_first_id := revision.word (l_first).id
				l_last_id := revision.word (l_last).id
				l_from_rev := revision.number
				history.apply_edit (l_first, l_last, {STRING_32} "")
				log (create {PT_TAKE_EVENT}.make_skip (stamp, l_from_rev, l_first_id, l_last_id))
				after_revision (l_first)
			when {PT_ACTION}.Wrap then
				follower.hold
				log (create {PT_TAKE_EVENT}.make_wrap (stamp, "user"))
			when {PT_ACTION}.Abort then
				follower.hold
				log (create {PT_TAKE_EVENT}.make_abort (stamp, {STRING_32} "user"))
			when {PT_ACTION}.Stop then
				follower.hold
			else
				-- Edit_cancel, Analysis_done: state change only.
			end
			if a_action = {PT_ACTION}.Wrap or a_action = {PT_ACTION}.Abort then
				is_recording := False
			end
			state := transitions.next_state (l_from, a_action)
		ensure
			transitioned: state = transitions.next_state (old state, a_action)
			recording_starts: a_action = {PT_ACTION}.Record implies is_recording
			recording_ends: (a_action = {PT_ACTION}.Wrap or a_action = {PT_ACTION}.Abort) implies not is_recording
			journal_monotone: journal.count >= old journal.count
			practice_not_journaled: (not old is_recording and a_action /= {PT_ACTION}.Record) implies journal.count = old journal.count
			again_caret: a_action = {PT_ACTION}.Again implies (caret = last_again_target and last_again_target >= 1)
			browse_not_journaled: is_browse (a_action) implies journal.count = old journal.count
			resumes_at_caret: a_action = {PT_ACTION}.Count_in_done implies follower.target = (caret - 1).to_double
			frozen_unless_reading: (state = {PT_TAKE_STATE}.Count_in or state = {PT_TAKE_STATE}.Held) implies follower.is_held
			reading_runs: state = {PT_TAKE_STATE}.Reading implies not follower.is_held
			skip_revises: a_action = {PT_ACTION}.Skip implies history.revision_count = old history.revision_count + 1
		end

	pick_word (a_index: INTEGER)
			-- Put the caret on word `a_index' (mouse click or badge digit while held).
		require
			held: state = {PT_TAKE_STATE}.Held
			valid: a_index >= 1 and a_index <= revision.word_count
		do
			caret := a_index
		ensure
			placed: caret = a_index
			not_journaled: journal.count = old journal.count
			still_held: state = {PT_TAKE_STATE}.Held
		end

	commit_edit (a_new_text: READABLE_STRING_32)
			-- Replace words `edit_first'..`edit_last' with `a_new_text' (revision n+1).
		require
			editing: state = {PT_TAKE_STATE}.Editing
		local
			l_from_rev, l_middle, i: INTEGER
			l_first_id, l_last_id: PT_WORD_ID
			l_old_text: STRING_32
			l_new_ids: ARRAYED_LIST [PT_WORD_ID]
			l_old_count: INTEGER
		do
			l_from_rev := revision.number
			l_old_count := revision.word_count
			if edit_first >= 1 and edit_first <= revision.word_count then
				l_first_id := revision.word (edit_first).id
			end
			if edit_last >= 1 and edit_last <= revision.word_count then
				l_last_id := revision.word (edit_last).id
			end
			l_old_text := revision.text_of_range (edit_first, edit_last)
			history.apply_edit (edit_first, edit_last, a_new_text)
			create l_new_ids.make (4)
			l_middle := revision.word_count - l_old_count + (edit_last - edit_first + 1)
			from i := edit_first until i > edit_first + l_middle - 1 or i > revision.word_count loop
				l_new_ids.extend (revision.word (i).id)
				i := i + 1
			end
			log (create {PT_TAKE_EVENT}.make_edit (stamp, l_from_rev, l_first_id, l_last_id, l_old_text, a_new_text, l_new_ids))
			after_revision (edit_first)
			state := {PT_TAKE_STATE}.Held
		ensure
			new_revision: history.revision_count = old history.revision_count + 1
			back_to_held: state = {PT_TAKE_STATE}.Held
			journaled_when_recording: is_recording implies journal.count = old journal.count + 1
			follower_resized: follower.word_count = revision.word_count
			caret_at_edit: revision.word_count > 0 implies caret = policy.passage_start (revision,
					(old edit_first).max (1).min (revision.word_count))
		end

	add_marker (a_text: READABLE_STRING_32)
			-- Drop a marker (chapter or reminder) now.
		require
			allowed: is_allowed ({PT_ACTION}.Marker)
		do
			journal.append (create {PT_TAKE_EVENT}.make_marker (stamp, a_text, "user"))
		ensure
			journaled: journal.count = old journal.count + 1
			state_kept: state = old state
		end

	sample_alignment (a_alignment: PT_ALIGNMENT)
			-- Record the live aligner estimate (confidence, last confident word; Align events <= 4/s while recording).
		do
			alignment_confidence := a_alignment.confidence
			if a_alignment.confidence >= Confident_level and a_alignment.word_index >= 1
				and a_alignment.word_index <= revision.word_count then
				last_confident_word := a_alignment.word_index
			end
			if is_recording and a_alignment.word_index >= 1 and a_alignment.word_index <= revision.word_count
				and stamp - last_align_rt >= Align_interval then
				last_align_rt := stamp
				journal.append (create {PT_TAKE_EVENT}.make_align (last_align_rt, revision.word (a_alignment.word_index).id, a_alignment.confidence))
			end
		ensure
			confidence_taken: alignment_confidence = a_alignment.confidence
			at_most_one_event: journal.count <= old journal.count + 1
			not_journaled_in_practice: not is_recording implies journal.count = old journal.count
		end

	set_count_in (a_seconds: REAL_64)
		require
			range: a_seconds >= 0 and a_seconds <= 5
		do
			count_in_seconds := a_seconds
		ensure
			set: count_in_seconds = a_seconds
		end

feature {NONE} -- Implementation

	Align_interval: REAL_64 = 0.25
			-- At most four Align events per second.

	last_align_rt: REAL_64
			-- Recording time of the last Align event.

	stamp: REAL_64
			-- Recording time for a new event: never earlier than the journal's last event
			-- (interpolation can run ahead of the next file observation).
		do
			Result := current_rt.max (journal.last_rt)
		ensure
			ordered: Result >= journal.last_rt
		end

	log (a_event: PT_TAKE_EVENT)
			-- Append `a_event' while recording; practice keeps no journal.
		require
			ordered: a_event.rt >= journal.last_rt
		do
			if is_recording then
				journal.append (a_event)
			end
		ensure
			practice_unchanged: not is_recording implies journal.count = old journal.count
		end

	after_revision (a_edit_first: INTEGER)
			-- The script was revised at `a_edit_first': resize the follower, clamp positions, caret to the passage start.
		do
			follower.rescale (revision.word_count)
			last_confident_word := last_confident_word.min (revision.word_count)
			last_again_target := last_again_target.min (revision.word_count)
			if revision.word_count > 0 then
				caret := policy.passage_start (revision, a_edit_first.max (1).min (revision.word_count))
			else
				caret := 0
			end
		end

invariant
	state_known: state >= {PT_TAKE_STATE}.Idle and state <= {PT_TAKE_STATE}.Wrapped
	caret_valid: revision.word_count > 0 implies (caret >= 1 and caret <= revision.word_count)
	caret_zero_when_empty: revision.word_count = 0 implies caret = 0
	confidence_range: alignment_confidence >= 0.0 and alignment_confidence <= 1.0
	count_in_range: count_in_seconds >= 0 and count_in_seconds <= 5
	last_confident_in_script: last_confident_word >= 0 and last_confident_word <= revision.word_count
	again_target_in_script: last_again_target >= 0 and last_again_target <= revision.word_count

end
