note
	description: "[
		CMX3600 edit decision list for DaVinci Resolve / Premiere: one event per
		cut, referencing the raw recording, so the edit can be finished elsewhere
		(FR-T17, CMX3600 only in v1).
	]"
	author: "Larry Rix"

class
	PT_EDL_WRITER

create
	make

feature {NONE} -- Initialization

	make
		do
			create timecode
		end

feature -- Access

	timecode: PT_TIMECODE

feature -- Rendering

	write (a_cuts: PT_CUT_LIST; a_fps: INTEGER; a_title, a_reel: READABLE_STRING_8): STRING_8
			-- EDL text.
		require
			fps_positive: a_fps > 0
			title_present: not a_title.is_empty
			reel_present: not a_reel.is_empty
		do
			create Result.make (256)
			Result.append ("TITLE: ")
			Result.append (a_title)
			Result.append ("%NFCM: NON-DROP FRAME%N%N")
			across 1 |..| a_cuts.count as ic loop
				Result.append (event_number (ic))
				Result.append ("  ")
				Result.append (reel_field (a_reel))
				Result.append (" AA/V  C        ")
				Result.append (timecode.edl (a_cuts.cut (ic).span.t0, a_fps))
				Result.append_character (' ')
				Result.append (timecode.edl (a_cuts.cut (ic).span.t1, a_fps))
				Result.append_character (' ')
				Result.append (timecode.edl (record_in (a_cuts, ic), a_fps))
				Result.append_character (' ')
				Result.append (timecode.edl (record_in (a_cuts, ic) + a_cuts.cut (ic).span.duration, a_fps))
				Result.append_character ('%N')
			end
		ensure
			header: Result.starts_with ("TITLE:")
			one_event_per_cut: event_lines (Result) = a_cuts.count
		end

	event_number (a_index: INTEGER): STRING_8
			-- Three-digit event number.
		do
			Result := a_index.out
			from until Result.count >= 3 loop
				Result.prepend_character ('0')
			end
		end

	reel_field (a_reel: READABLE_STRING_8): STRING_8
			-- Reel name padded or cut to eight characters.
		do
			create Result.make_from_string (a_reel.substring (1, a_reel.count.min (8)))
			from until Result.count >= 8 loop
				Result.append_character (' ')
			end
		end

	record_in (a_cuts: PT_CUT_LIST; a_index: INTEGER): REAL_64
			-- Output time where cut `a_index' starts.
		local
			i: INTEGER
		do
			from i := 1 until i >= a_index loop
				Result := Result + a_cuts.cut (i).span.duration
				i := i + 1
			end
		end

	event_lines (a_edl: READABLE_STRING_8): INTEGER
			-- Lines starting with a three-digit event number.
		do
			across a_edl.split ('%N') as ic loop
				if ic.count >= 3 and then (ic [1].is_digit and ic [2].is_digit and ic [3].is_digit) then
					Result := Result + 1
				end
			end
		end

end
