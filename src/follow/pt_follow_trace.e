note
	description: "[
		The follow trace (0.5.1): what voice following did while a take was recorded, as
		journal lines the take analyzer skips. A "heard" line per decode: the words heard,
		the aligner's position before and after, the move its best match proposed, the
		anchors found and needed, whether the wide search won, and the follower's target.
		A "frame" line at most every `Frame_interval' seconds, and whenever the line on
		the reading row changes or the follower snaps: the follower's target, velocity and
		steering goal, the displayed position, its line and the target's line. Together
		they show why the text moved when the reader lost the place (Larry, 2026-10-10:
		"the text skips down about 2-3 lines").
	]"
	author: "Larry Rix"

class
	PT_FOLLOW_TRACE

create
	make

feature {NONE} -- Initialization

	make
			-- A trace with no frame written yet.
		do
			last_frame_rt := -1.0
		ensure
			fresh: last_frame_rt = -1.0 and last_line = 0 and last_flush_rt = 0
		end

feature -- Constants

	Frame_interval: REAL_64 = 0.1
			-- Seconds between frame lines while nothing changes.

	Flush_interval: REAL_64 = 1.0
			-- Seconds between writes of buffered trace lines to disk.

feature -- Access

	last_frame_rt: REAL_64
			-- Recording time of the last frame line (-1 = none).

	last_line: INTEGER
			-- Line on the reading row at the last frame line.

	last_flush_rt: REAL_64
			-- Recording time of the last flush.

feature -- Status

	wants_frame (a_rt: REAL_64; a_line: INTEGER; a_snapped: BOOLEAN): BOOLEAN
			-- Is a frame line due at `a_rt' with `a_line' on the reading row?
		do
			Result := a_snapped or a_line /= last_line or last_frame_rt < 0 or a_rt - last_frame_rt >= Frame_interval
		end

	wants_flush (a_rt: REAL_64): BOOLEAN
			-- Is a flush due at `a_rt'?
		do
			Result := a_rt - last_flush_rt >= Flush_interval or a_rt < last_flush_rt
		end

feature -- Lines

	heard_line (a_rt: REAL_64; a_heard: PT_HEARD_WORDS; a_from: INTEGER; a_aligner: PT_ALIGNER; a_follower: PT_FOLLOWER): STRING_32
			-- The line for decode `a_heard' at `a_rt', the aligner having moved from `a_from'.
		local
			o: SIMPLE_JSON_OBJECT
			l_words: STRING_32
			i: INTEGER
		do
			create l_words.make (80)
			from i := 1 until i > a_heard.count loop
				if not l_words.is_empty then
					l_words.append_character (' ')
				end
				l_words.append (a_heard.word (i).text)
				i := i + 1
			end
			o := (create {SIMPLE_JSON}).new_object
			o := o.put_string ({STRING_32} "heard", "t")
			o := o.put_real (rounded (a_rt), "rt")
			o := o.put_real (rounded (a_heard.window_start / 16_000), "w0")
			o := o.put_real (rounded (a_heard.window_end / 16_000), "w1")
			o := o.put_string (l_words, "words")
			o := o.put_string (joined (a_aligner.heard_tail), "tail")
			o := o.put_integer (a_from, "from")
			o := o.put_integer (a_aligner.position, "to")
			o := o.put_integer (a_aligner.last_proposed, "prop")
			o := o.put_integer (a_aligner.last_alignment.anchor_count, "anch")
			o := o.put_integer (a_aligner.last_needed, "need")
			o := o.put_boolean (a_aligner.last_wide, "wide")
			o := o.put_real (rounded (a_aligner.confidence), "conf")
			o := o.put_string (script_word (a_aligner.revision, a_aligner.position), "at")
			o := o.put_string (script_word (a_aligner.revision, a_aligner.last_proposed), "prop_at")
			o := o.put_real (rounded (a_follower.target), "target")
			Result := o.as_json
		ensure
			one_line: not Result.has ('%N')
		end

	frame_line (a_rt: REAL_64; a_follower: PT_FOLLOWER; a_scroll: PT_SCROLL_MODEL; a_line, a_target_line: INTEGER): STRING_32
			-- The line for the display at `a_rt': `a_line' on the reading row, the target on `a_target_line'.
		local
			o: SIMPLE_JSON_OBJECT
		do
			o := (create {SIMPLE_JSON}).new_object
			o := o.put_string ({STRING_32} "frame", "t")
			o := o.put_real (rounded (a_rt), "rt")
			o := o.put_real (rounded (a_follower.target), "target")
			o := o.put_real (rounded (a_follower.velocity), "vel")
			if attached {PT_TRACKING_FOLLOWER} a_follower as al_tracking then
				o := o.put_integer (al_tracking.aligned_word, "aligned")
				o := o.put_real (rounded (al_tracking.seconds_since_anchor), "since")
				o := o.put_real (rounded (al_tracking.measured_rate), "rate")
				o := o.put_boolean (al_tracking.last_snapped, "snap")
			end
			o := o.put_boolean (a_follower.is_speaking, "speak")
			o := o.put_boolean (a_follower.is_held, "held")
			o := o.put_real (rounded (a_scroll.position), "pos")
			o := o.put_integer (a_line, "line")
			o := o.put_integer (a_target_line, "tline")
			Result := o.as_json
		ensure
			one_line: not Result.has ('%N')
		end

feature -- Element change

	note_frame (a_rt: REAL_64; a_line: INTEGER)
			-- A frame line was written at `a_rt' with `a_line' on the reading row.
		do
			last_frame_rt := a_rt
			last_line := a_line
		ensure
			noted: last_frame_rt = a_rt and last_line = a_line
		end

	note_flush (a_rt: REAL_64)
		do
			last_flush_rt := a_rt
		ensure
			noted: last_flush_rt = a_rt
		end

feature {NONE} -- Implementation

	rounded (a_value: REAL_64): REAL_64
			-- `a_value' to three decimals.
		do
			Result := (a_value * 1000).rounded_real_64 / 1000
		end

	joined (a_words: LIST [STRING_32]): STRING_32
		do
			create Result.make (80)
			across a_words as ic loop
				if not Result.is_empty then
					Result.append_character (' ')
				end
				Result.append (ic)
			end
		end

	script_word (a_revision: PT_SCRIPT_REVISION; a_index: INTEGER): STRING_32
			-- Text of script word `a_index', empty for 0.
		do
			if a_index >= 1 and a_index <= a_revision.word_count then
				Result := a_revision.word (a_index).text.to_string_32
			else
				create Result.make_empty
			end
		end

end
