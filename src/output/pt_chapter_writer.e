note
	description: "[
		YouTube chapter list from the final script's sections (Markdown headings)
		plus Marker events, mapped into output time. YouTube requires the first
		chapter at 0:00.
	]"
	author: "Larry Rix"

class
	PT_CHAPTER_WRITER

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

	text (a_final: PT_SCRIPT_REVISION; a_cuts: PT_CUT_LIST; a_timeline: PT_WORD_TIMELINE; a_journal: PT_JOURNAL): STRING_32
			-- One "M:SS Title" line per chapter.
		local
			l_times: ARRAYED_LIST [REAL_64]
			l_titles: ARRAYED_LIST [STRING_32]
			s, w, l_c, k: INTEGER
			l_found: BOOLEAN
			l_time: REAL_64
		do
			create Result.make (128)
			create l_times.make (8)
			create l_titles.make (8)
			from s := 1 until s > a_final.section_count loop
					-- Time of the first kept word at or after the heading (headings are optional words).
				l_found := False
				from w := a_final.section (s).first_word until l_found or w > a_final.word_count loop
					from l_c := 1 until l_found or l_c > a_cuts.count loop
						k := a_cuts.cut (l_c).word_ids.index_of (a_final.word (w).id, 1)
						if k > 0 then
							l_found := True
							l_time := a_cuts.to_output_time (a_cuts.cut (l_c).src, a_cuts.cut (l_c).span.t0)
							if attached a_timeline.occurrence_in (a_final.word (w).id, a_cuts.cut (l_c).attempt) as al_occ
								and then a_cuts.is_kept (a_cuts.cut (l_c).src, al_occ.span.t0) then
								l_time := a_cuts.to_output_time (a_cuts.cut (l_c).src, al_occ.span.t0)
							end
						end
						l_c := l_c + 1
					end
					w := w + 1
				end
				if l_found then
					insert_sorted (l_times, l_titles, l_time, a_final.section (s).heading)
				end
				s := s + 1
			end
			from s := 1 until s > a_journal.count loop
				if a_journal.event (s).kind = {PT_EVENT_KIND}.Marker and then a_cuts.is_kept (0, a_journal.event (s).rt)
					and then attached a_journal.event (s).text as al_text and then not al_text.is_empty then
					insert_sorted (l_times, l_titles, a_cuts.to_output_time (0, a_journal.event (s).rt), al_text)
				end
				s := s + 1
			end
			if not l_times.is_empty then
				l_times [1] := 0.0
			end
			from s := 1 until s > l_times.count loop
				Result.append_string_general (timecode.chapter (l_times [s]))
				Result.append_character (' ')
				Result.append (l_titles [s])
				Result.append_character ('%N')
				s := s + 1
			end
		ensure
			starts_at_zero: (a_final.section_count > 0 and a_cuts.count > 0) implies Result.starts_with ({STRING_32} "0:00 ")
		end

feature {NONE} -- Implementation

	insert_sorted (a_times: ARRAYED_LIST [REAL_64]; a_titles: ARRAYED_LIST [STRING_32]; a_time: REAL_64; a_title: READABLE_STRING_32)
			-- Insert keeping `a_times' ascending.
		local
			i: INTEGER
		do
			from i := 1 until i > a_times.count or else a_times [i] > a_time loop
				i := i + 1
			end
			if i > a_times.count then
				a_times.extend (a_time)
				a_titles.extend (a_title.to_string_32)
			else
				a_times.go_i_th (i)
				a_times.put_left (a_time)
				a_titles.go_i_th (i)
				a_titles.put_left (a_title.to_string_32)
			end
		end

end
