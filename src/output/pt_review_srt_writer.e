note
	description: "[
		review.srt: the journal's marks as subtitles over raw.mkv, so the raw
		recording can be eyeballed in any player (spec F-01 section 9.4). A view,
		not the source of truth.
	]"
	author: "Larry Rix"

class
	PT_REVIEW_SRT_WRITER

create
	make

feature {NONE} -- Initialization

	make
		do
			create timecode
		end

feature -- Constants

	Cue_seconds: REAL_64 = 2.0
			-- Display length of a mark without a natural end.

feature -- Access

	timecode: PT_TIMECODE

	shown_count (a_journal: PT_JOURNAL): INTEGER
			-- Marks that become cues: flub, hold, rewind_to, edit, star, reject, marker, skip, wrap, abort.
		do
			across 1 |..| a_journal.count as i loop
				if is_shown (a_journal.event (i).kind) then
					Result := Result + 1
				end
			end
		end

	is_shown (a_kind: INTEGER): BOOLEAN
		do
			Result := a_kind /= {PT_EVENT_KIND}.Session_start and a_kind /= {PT_EVENT_KIND}.Resume and
				a_kind /= {PT_EVENT_KIND}.Count_in and a_kind /= {PT_EVENT_KIND}.Align
		end

feature -- Rendering

	text (a_journal: PT_JOURNAL; a_history: PT_SCRIPT_HISTORY): STRING_8
			-- review.srt document (UTF-8).
		local
			l_n, i: INTEGER
			l_event: PT_TAKE_EVENT
		do
			create Result.make (256)
			from i := 1 until i > a_journal.count loop
				l_event := a_journal.event (i)
				if is_shown (l_event.kind) then
					l_n := l_n + 1
					Result.append (l_n.out + "%N")
					Result.append (timecode.srt (l_event.rt) + " --> " + timecode.srt (l_event.rt + Cue_seconds) + "%N")
					Result.append (safe (description (l_event, a_history)) + "%N%N")
				end
				i := i + 1
			end
		ensure
			one_cue_per_mark: cue_count (Result) = shown_count (a_journal)
		end

	description (a_event: PT_TAKE_EVENT; a_history: PT_SCRIPT_HISTORY): STRING_32
			-- Human-readable text for a shown mark.
		do
			inspect a_event.kind
			when {PT_EVENT_KIND}.Flub then
				Result := {STRING_32} "x FLUB at '" + word_text (a_event.word, a_history) + "'"
			when {PT_EVENT_KIND}.Hold then
				Result := {STRING_32} "HOLD"
			when {PT_EVENT_KIND}.Rewind_to then
				Result := {STRING_32} "-> again from '" + word_text (a_event.caret, a_history) + "'"
			when {PT_EVENT_KIND}.Edit then
				Result := {STRING_32} "EDIT r" + a_event.from_rev.out + "->r" + a_event.to_rev.out + ": '"
				if attached a_event.old_text as al_old then
					Result.append (al_old)
				end
				Result.append ({STRING_32} "' -> '")
				if attached a_event.new_text as al_new then
					Result.append (al_new)
				end
				Result.append ({STRING_32} "'")
			when {PT_EVENT_KIND}.Star then
				Result := {STRING_32} "* STAR (keep this take)"
			when {PT_EVENT_KIND}.Reject then
				Result := {STRING_32} "REJECT (drop this take)"
			when {PT_EVENT_KIND}.Marker then
				Result := {STRING_32} "MARKER"
				if attached a_event.text as al_text and then not al_text.is_empty then
					Result.append ({STRING_32} ": " + al_text)
				end
			when {PT_EVENT_KIND}.Skip then
				Result := {STRING_32} "SKIP passage"
			when {PT_EVENT_KIND}.Wrap then
				Result := {STRING_32} "WRAP"
			when {PT_EVENT_KIND}.Abort then
				Result := {STRING_32} "ABORT"
			else
				Result := {STRING_32} "mark"
			end
		end

	word_text (a_id: PT_WORD_ID; a_history: PT_SCRIPT_HISTORY): STRING_32
			-- Text of word `a_id' in the newest revision that has it.
		local
			i: INTEGER
		do
			create Result.make_empty
			from i := a_history.revision_count until i < 1 or not Result.is_empty loop
				if a_history.revision (i).index_of (a_id) > 0 then
					Result := a_history.revision (i).word (a_history.revision (i).index_of (a_id)).text
				end
				i := i - 1
			end
		end

	safe (a_text: READABLE_STRING_32): STRING_8
			-- UTF-8 of `a_text' with cue separators and line breaks neutralized.
		local
			l_utf: UTF_CONVERTER
		do
			Result := l_utf.string_32_to_utf_8_string_8 (a_text)
			Result.replace_substring_all ("-->", "->")
			Result.replace_substring_all ("%N", " ")
			Result.replace_substring_all ("%R", " ")
		ensure
			no_separator: not Result.has_substring (" --> ")
		end

	cue_count (a_srt: READABLE_STRING_8): INTEGER
			-- Number of " --> " separators.
		local
			i: INTEGER
		do
			from i := a_srt.substring_index (" --> ", 1) until i = 0 loop
				Result := Result + 1
				i := a_srt.substring_index (" --> ", i + 5)
			end
		end

end
