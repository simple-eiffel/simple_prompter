note
	description: "[
		Immutable Take Studio journal entry stamped in recording time (rt, seconds
		on the raw recording's audio timeline). One class with a kind code and
		optional fields, built by one creation procedure per kind (spec 03 A-109).
	]"
	author: "Larry Rix"

class
	PT_TAKE_EVENT

create
	make_session_start, make_resume, make_hold, make_flub, make_rewind_to, make_count_in,
	make_edit, make_star, make_reject, make_marker, make_skip, make_align, make_wrap, make_abort

feature {NONE} -- Initialization

	make_session_start (a_rt: REAL_64; a_revision: INTEGER; a_mode: READABLE_STRING_32)
			-- Session begins with script revision `a_revision' in follow mode `a_mode'.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_revision >= 1
		do
			init (a_rt, {PT_EVENT_KIND}.Session_start, "system")
			to_rev := a_revision
			text := a_mode.to_string_32
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Session_start
			rt_set: rt = a_rt
			revision_set: to_rev = a_revision
		end

	make_resume (a_rt: REAL_64; a_caret: PT_WORD_ID; a_revision: INTEGER)
			-- Reading resumes at `a_caret' under revision `a_revision'.
		require
			rt_ok: a_rt >= 0
			real_caret: not a_caret.is_none
			revision_ok: a_revision >= 1
		do
			init (a_rt, {PT_EVENT_KIND}.Resume, "system")
			caret := a_caret
			to_rev := a_revision
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Resume
			rt_set: rt = a_rt
			caret_set: caret ~ a_caret
			revision_set: to_rev = a_revision
		end

	make_hold (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Hold, a_by)
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Hold
			rt_set: rt = a_rt
		end

	make_flub (a_rt: REAL_64; a_word: PT_WORD_ID; a_by: READABLE_STRING_8)
			-- Reader flubbed at `a_word'.
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Flub, a_by)
			word := a_word
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Flub
			rt_set: rt = a_rt
			word_set: word ~ a_word
		end

	make_rewind_to (a_rt: REAL_64; a_caret: PT_WORD_ID; a_reason: READABLE_STRING_32)
			-- Caret placed at `a_caret' for a restart (`a_reason': again_default, browse, pick).
		require
			rt_ok: a_rt >= 0
			real_caret: not a_caret.is_none
		do
			init (a_rt, {PT_EVENT_KIND}.Rewind_to, "system")
			caret := a_caret
			text := a_reason.to_string_32
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Rewind_to
			caret_set: caret ~ a_caret
		end

	make_count_in (a_rt: REAL_64; a_seconds: REAL_64)
		require
			rt_ok: a_rt >= 0
			seconds_ok: a_seconds >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Count_in, "system")
			seconds := a_seconds
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Count_in
			seconds_set: seconds = a_seconds
		end

	make_edit (a_rt: REAL_64; a_from_rev: INTEGER; a_first, a_last: PT_WORD_ID;
			a_old, a_new: READABLE_STRING_32; a_new_ids: ITERABLE [PT_WORD_ID])
			-- Script edit creating revision `a_from_rev' + 1.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_from_rev >= 1
		local
			l_ids: ARRAYED_LIST [PT_WORD_ID]
		do
			init (a_rt, {PT_EVENT_KIND}.Edit, "user")
			from_rev := a_from_rev
			to_rev := a_from_rev + 1
			range_first := a_first
			range_last := a_last
			old_text := a_old.to_string_32
			new_text := a_new.to_string_32
			create l_ids.make (4)
			across a_new_ids as ic loop
				l_ids.extend (ic)
			end
			new_ids := l_ids
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Edit
			next_revision: to_rev = a_from_rev + 1
			old_kept: attached old_text as al_old and then al_old.same_string (a_old)
		end

	make_star (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Star, a_by)
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Star
		end

	make_reject (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Reject, a_by)
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Reject
		end

	make_marker (a_rt: REAL_64; a_text: READABLE_STRING_32; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Marker, a_by)
			text := a_text.to_string_32
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Marker
		end

	make_skip (a_rt: REAL_64; a_from_rev: INTEGER; a_first, a_last: PT_WORD_ID)
			-- Words `a_first'..`a_last' struck from revision `a_from_rev'.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_from_rev >= 1
		do
			init (a_rt, {PT_EVENT_KIND}.Skip, "user")
			from_rev := a_from_rev
			to_rev := a_from_rev + 1
			range_first := a_first
			range_last := a_last
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Skip
			next_revision: to_rev = a_from_rev + 1
		end

	make_align (a_rt: REAL_64; a_word: PT_WORD_ID; a_confidence: REAL_64)
			-- Sampled live alignment (recovery and fallback only; analysis recomputes).
		require
			rt_ok: a_rt >= 0
			confidence_range: a_confidence >= 0.0 and a_confidence <= 1.0
		do
			init (a_rt, {PT_EVENT_KIND}.Align, "system")
			word := a_word
			confidence := a_confidence
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Align
			confidence_set: confidence = a_confidence
		end

	make_wrap (a_rt: REAL_64; a_by: READABLE_STRING_8)
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Wrap, a_by)
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Wrap
		end

	make_abort (a_rt: REAL_64; a_reason: READABLE_STRING_32)
		require
			rt_ok: a_rt >= 0
		do
			init (a_rt, {PT_EVENT_KIND}.Abort, "system")
			text := a_reason.to_string_32
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Abort
		end

feature -- Access

	kind: INTEGER
	rt: REAL_64
			-- Recording time, seconds.
	word: PT_WORD_ID
	caret: PT_WORD_ID
	from_rev, to_rev: INTEGER
	range_first, range_last: PT_WORD_ID
	old_text, new_text: detachable STRING_32
	new_ids: detachable ARRAYED_LIST [PT_WORD_ID]
	text: detachable STRING_32
			-- Note text, follow mode name, rewind reason, abort reason.
	by: STRING_8
			-- "hotkey", "mouse", "clicker", "user", "system".
	confidence: REAL_64
	seconds: REAL_64
			-- Count-in length.

feature {NONE} -- Implementation

	init (a_rt: REAL_64; a_kind: INTEGER; a_by: READABLE_STRING_8)
			-- Common fields.
		require
			rt_ok: a_rt >= 0
		do
			rt := a_rt
			kind := a_kind
			create by.make_from_string (a_by)
		ensure
			rt_set: rt = a_rt
			kind_set: kind = a_kind
		end

invariant
	kind_known: kind >= {PT_EVENT_KIND}.Session_start and kind <= {PT_EVENT_KIND}.Abort
	rt_non_negative: rt >= 0
	edit_complete: kind = {PT_EVENT_KIND}.Edit implies
			(attached old_text and attached new_text and to_rev = from_rev + 1)
	resume_has_caret: kind = {PT_EVENT_KIND}.Resume implies not caret.is_none
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	seconds_non_negative: seconds >= 0

end
