note
	description: "[
		Captions for the final video, free: the text is the final script revision
		(so live edits are honored), timed by word alignment mapped through the
		cut list into output time (FR-T14).
	]"
	author: "Larry Rix"

class
	PT_CAPTION_BUILDER

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_cues.make (0)
			create timecode
		ensure
			empty: last_cues.is_empty
		end

feature -- Constants

	Max_cue_chars: INTEGER = 84
			-- Two lines of 42.
	Max_cue_seconds: REAL_64 = 6.0

feature -- Access

	last_cues: ARRAYED_LIST [PT_CAPTION_CUE]
	timecode: PT_TIMECODE

feature -- Basic operations

	build (a_final: PT_SCRIPT_REVISION; a_cuts: PT_CUT_LIST; a_timeline: PT_WORD_TIMELINE)
			-- Cues covering the words of `a_cuts'.
		local
			l_ids: ARRAYED_LIST [PT_WORD_ID]
			l_text: STRING_32
			l_cue_t0, l_cue_t1, l_w0, l_w1, l_floor: REAL_64
			l_cut: PT_CUT
			l_word: PT_WORD
			c, w, l_index, l_passage, l_last_passage: INTEGER
		do
			create last_cues.make (16)
			create l_ids.make (12)
			create l_text.make (Max_cue_chars)
			from c := 1 until c > a_cuts.count loop
				l_cut := a_cuts.cut (c)
				from w := 1 until w > l_cut.word_ids.count loop
					l_index := a_final.index_of (l_cut.word_ids [w])
					if l_index > 0 then
						l_word := a_final.word (l_index)
						word_times (a_cuts, c, w, a_timeline)
						l_w0 := last_t0.max (l_floor)
						l_w1 := last_t1.max (l_w0)
						l_passage := l_word.passage_index
						if not l_ids.is_empty and then (l_passage /= l_last_passage
							or l_text.count + 1 + l_word.text.count > Max_cue_chars or l_w1 - l_cue_t0 > Max_cue_seconds) then
							flush_cue (l_cue_t0, l_cue_t1, l_text, l_ids, a_cuts.output_duration)
							l_floor := last_cues.last.t1
							l_w0 := l_w0.max (l_floor)
							l_w1 := l_w1.max (l_w0)
							create l_ids.make (12)
							create l_text.make (Max_cue_chars)
						end
						if l_ids.is_empty then
							l_cue_t0 := l_w0
						else
							l_text.append_character (' ')
						end
						l_text.append (l_word.text)
						l_ids.extend (l_word.id)
						l_cue_t1 := l_w1
						l_last_passage := l_passage
					end
					w := w + 1
				end
				c := c + 1
			end
			if not l_ids.is_empty then
				flush_cue (l_cue_t0, l_cue_t1, l_text, l_ids, a_cuts.output_duration)
			end
		ensure
			ordered_non_overlapping: across 2 |..| last_cues.count as i all last_cues [i].t0 >= last_cues [i - 1].t1 end
			text_is_final_script: (concatenated_ids (last_cues) |=| a_cuts.words_model)
			within_output: across last_cues as ic all ic.t1 <= a_cuts.output_duration + 0.001 end
			cue_limits: across last_cues as ic all ic.text.count <= Max_cue_chars and ic.t1 - ic.t0 <= Max_cue_seconds end
		end

feature -- Rendering

	srt_text (a_cues: LIST [PT_CAPTION_CUE]): STRING_8
			-- SubRip document (UTF-8).
		local
			l_utf: UTF_CONVERTER
			l_n: INTEGER
		do
			create Result.make (a_cues.count * 64)
			across a_cues as ic loop
				l_n := l_n + 1
				Result.append (l_n.out + "%N" + timecode.srt (ic.t0) + " --> " + timecode.srt (ic.t1) + "%N")
				Result.append (l_utf.string_32_to_utf_8_string_8 (ic.text) + "%N%N")
			end
		ensure
			numbered: a_cues.is_empty or else Result.starts_with ("1%N")
		end

	vtt_text (a_cues: LIST [PT_CAPTION_CUE]): STRING_8
			-- WebVTT document (UTF-8).
		do
			create Result.make_from_string ("WEBVTT%N%N")
			across a_cues as ic loop
				Result.append (timecode.vtt (ic.t0) + " --> " + timecode.vtt (ic.t1) + "%N")
				Result.append (utf8 (ic.text) + "%N%N")
			end
		ensure
			header: Result.starts_with ("WEBVTT")
		end

feature {NONE} -- Implementation

	utf8 (a_text: READABLE_STRING_32): STRING_8
		local
			l_utf: UTF_CONVERTER
		do
			Result := l_utf.string_32_to_utf_8_string_8 (a_text)
		end

	last_t0, last_t1: REAL_64
			-- Output times computed by `word_times'.

	word_times (a_cuts: PT_CUT_LIST; a_cut, a_word: INTEGER; a_timeline: PT_WORD_TIMELINE)
			-- Output-time span of word `a_word' of cut `a_cut': from its occurrence when heard inside
			-- the cut, else proportionally inside the cut.
		local
			l_cut: PT_CUT
			l_start, l_share: REAL_64
		do
			l_cut := a_cuts.cut (a_cut)
			l_start := a_cuts.to_output_time (l_cut.src, l_cut.span.t0)
			l_share := l_cut.span.duration / l_cut.word_ids.count.max (1)
			last_t0 := l_start + (a_word - 1) * l_share
			last_t1 := last_t0 + l_share
			if attached a_timeline.occurrence_in (l_cut.word_ids [a_word], l_cut.attempt) as al_occ
				and then a_cuts.is_kept (l_cut.src, al_occ.span.t0) and then a_cuts.is_kept (l_cut.src, al_occ.span.t1) then
				last_t0 := a_cuts.to_output_time (l_cut.src, al_occ.span.t0)
				last_t1 := a_cuts.to_output_time (l_cut.src, al_occ.span.t1)
			end
		end

	flush_cue (a_t0, a_t1: REAL_64; a_text: STRING_32; a_ids: ARRAYED_LIST [PT_WORD_ID]; a_output: REAL_64)
			-- Close a cue; keep it positive-length, inside the video, and no longer than Max_cue_seconds.
		local
			l_t0, l_t1: REAL_64
		do
			l_t0 := a_t0.min ((a_output - 0.04).max (0))
			l_t1 := a_t1.max (l_t0 + 0.04).min (l_t0 + Max_cue_seconds).min (a_output + 0.0009).max (l_t0 + 0.0001)
			last_cues.extend (create {PT_CAPTION_CUE}.make (l_t0, l_t1, a_text, a_ids))
		end

feature -- Contract helpers

	concatenated_ids (a_cues: LIST [PT_CAPTION_CUE]): MML_SEQUENCE [PT_WORD_ID]
			-- All cue word ids, in order.
		do
			create Result
			across a_cues as ic loop
				across ic.word_ids as ic_id loop
					Result := Result & ic_id
				end
			end
		end

end
