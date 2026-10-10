note
	description: "[
		Phase 4 acceptance tests named in tasks.md (new tests beyond the Phase 1 skeleton):
		parser on read_test_01.md, live-edit edges, restart stepping, controller journal,
		journal persistence, VAD-map gaps, star attribution, solver rules, snapper, analyzer
		success path, captions, chapters, analysis codec, settings round trip.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_ACCEPTANCE

inherit
	PT_TEST_SET

feature -- T2 parser

	test_read_test_parses_into_sections_and_sentences
		local
			r: PT_SCRIPT_REVISION
		do
			r := read_test
			assert_integers_equal ("two headings", 2, r.section_count)
			assert_true ("first heading word is optional", r.word (r.section (1).first_word).is_heading)
			assert_true ("Dr. Meyer in one sentence", r.passage_of (index_of (r, {STRING_32} "dr")) = r.passage_of (index_of (r, {STRING_32} "meyer")))
			assert_true ("e.g. does not end a sentence", r.passage_of (index_of (r, {STRING_32} "eg")) = r.passage_of (index_of (r, {STRING_32} "postcondition")))
			assert_true ("cue words are not required", r.spoken_ids_model.count < r.word_count)
		end

feature -- T3 live edits

	test_edit_insert_strike_and_edges
		local
			h: PT_SCRIPT_HISTORY
			r: PT_SCRIPT_REVISION
		do
			r := revision_of (<<{STRING_32} "One two three.", {STRING_32} "Four five six.">>)
			h := history_of (r)
			h.apply_edit (1, 1, {STRING_32} "Uno")
			assert_true ("first word replaced, second kept", h.current_revision.word (2).id ~ r.word (2).id)
			h.apply_edit (6, 6, {STRING_32} "seven.")
			assert_true ("last word replaced", h.current_revision.word (6).text.same_string ({STRING_32} "seven."))
			h.apply_edit (4, 3, {STRING_32} "Hello.")
			assert_integers_equal ("insert adds a word", 7, h.current_revision.word_count)
			h.apply_edit (4, 4, {STRING_32} "")
			assert_integers_equal ("strike removes it", 6, h.current_revision.word_count)
			assert_integers_equal ("five revisions", 5, h.revision_count)
		end

feature -- T9 restart stepping

	test_step_back_and_forward_edges
		local
			p: PT_RESTART_POLICY
			r: PT_SCRIPT_REVISION
		do
			create p
			r := moody
			assert_integers_equal ("back from the first word stays", 1, p.step_back (r, 1, p.Unit_passage))
			assert_integers_equal ("back from mid-sentence goes to its start", r.passage (3).first_word,
				p.step_back (r, r.passage (3).first_word + 2, p.Unit_passage))
			assert_integers_equal ("forward to the next sentence", r.passage (4).first_word,
				p.step_forward (r, r.passage (3).first_word, p.Unit_passage))
			assert_integers_equal ("forward in the last sentence stays", r.passage (7).first_word,
				p.step_forward (r, r.passage (7).first_word, p.Unit_passage))
		end

feature -- T10 controller journal

	test_cough_session_journal
		local
			c: PT_TAKE_CONTROLLER
		do
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Count_in_done)
			c.follower.set_caret (12)
			c.perform ({PT_ACTION}.Again)
			c.perform ({PT_ACTION}.Count_in_done)
			c.perform ({PT_ACTION}.Wrap)
			assert_integers_equal ("one flub", 1, c.journal.count_of ({PT_EVENT_KIND}.Flub))
			assert_integers_equal ("two resumes", 2, c.journal.count_of ({PT_EVENT_KIND}.Resume))
			assert_integers_equal ("one wrap", 1, c.journal.count_of ({PT_EVENT_KIND}.Wrap))
			assert_false ("recording ended", c.is_recording)
		end

feature -- T11 journal persistence

	test_journal_writes_and_replays
		local
			j, k: PT_JOURNAL
			l_path: STRING_32
			l_lines: LIST [STRING_32]
			l_utf8: ARRAYED_LIST [STRING_8]
			l_ok: BOOLEAN
		do
			l_path := temp_path ({STRING_32} "journal.jsonl")
			create j.make_on_file (l_path)
			j.append (create {PT_TAKE_EVENT}.make_resume (1.0, id (5), 1))
			j.append (create {PT_TAKE_EVENT}.make_flub (2.5, id (9), "clicker"))
			assert_integers_equal ("two lines written", 2, j.lines_written)
			l_ok := (create {SIMPLE_FILE}.make (l_path)).append_line ({STRING_32} "{%"t%":%"hol")
			l_lines := file_text (l_path).split ('%N')
			create l_utf8.make (l_lines.count)
			across l_lines as ic loop
				l_utf8.extend ((create {SIMPLE_ENCODING}.make).utf_32_to_utf_8 (ic))
			end
			create k.make_in_memory
			k.replay_from (l_utf8)
			assert_integers_equal ("two events back", 2, k.count)
			assert_integers_equal ("torn line skipped", 1, k.skipped_lines)
			assert_reals_equal ("flub time", 2.5, k.event (2).rt, 0.0005)
		end

feature -- T13 VAD gaps

	test_silence_around_the_instructed_pause
		local
			m: PT_SPEECH_MAP
		do
			m := larry_map
			if attached m.silence_around (20.0) as al_gap then
				assert_reals_equal ("gap start", 19.17, al_gap.t0, 0.001)
				assert_reals_equal ("gap end", 22.85, al_gap.t1, 0.001)
			else
				assert_true ("20 s is silent", False)
			end
		end

feature -- T14 star attribution

	test_star_marks_exactly_one_attempt
		local
			b: PT_ATTEMPT_BUILDER
			j: PT_JOURNAL
			r: PT_SCRIPT_REVISION
		do
			r := moody
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_resume (1.0, r.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_hold (2.0, "user"))
			j.append (create {PT_TAKE_EVENT}.make_resume (3.0, r.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_hold (4.0, "user"))
			j.append (create {PT_TAKE_EVENT}.make_star (4.5, "user"))
			create b.make
			b.build (j, history_of (r), 5.0)
			assert_false ("first not starred", b.last_attempts [1].is_starred)
			assert_true ("second starred", b.last_attempts [2].is_starred)
		end

feature -- T15 solver rules

	test_starred_older_take_wins
		local
			s: PT_TAKE_SOLVER
			r: PT_SCRIPT_REVISION
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
		do
			r := revision_of (<<{STRING_32} "One two three.">>)
			create l_attempts.make (2)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (1.0, 3.0), r.word (1).id, 1, 1, 3, True, False))
			l_attempts.extend (create {PT_ATTEMPT}.make (2, span (4.0, 6.0), r.word (1).id, 1, 1, 3, False, False))
			create s.make (1.0, 0.1, 0.5)
			s.solve (history_of (r), l_attempts, create {PT_WORD_TIMELINE}.make)
			assert_integers_equal ("starred take 1", 1, s.last_result.cut (1).attempt)
		end

	test_edited_passage_needs_the_newer_take
		local
			s: PT_TAKE_SOLVER
			r: PT_SCRIPT_REVISION
			h: PT_SCRIPT_HISTORY
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
		do
			r := revision_of (<<{STRING_32} "Your script stays in the notch.">>)
			h := history_of (r)
			h.apply_edit (6, 6, {STRING_32} "webcam.")
			create l_attempts.make (2)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (1.0, 3.0), r.word (1).id, 1, 1, 6, False, False))
			l_attempts.extend (create {PT_ATTEMPT}.make (2, span (5.0, 7.0), h.current_revision.word (1).id, 2, 1, 6, False, False))
			create s.make (1.0, 0.1, 0.5)
			s.solve (h, l_attempts, create {PT_WORD_TIMELINE}.make)
			assert_integers_equal ("take from revision 2", 2, s.last_result.cut (1).attempt)
		end

	test_missing_passage_is_reported
		local
			s: PT_TAKE_SOLVER
			r: PT_SCRIPT_REVISION
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
		do
			r := revision_of (<<{STRING_32} "One two three.", {STRING_32} "Four five six.">>)
			create l_attempts.make (1)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (1.0, 3.0), r.word (1).id, 1, 1, 3, False, False))
			create s.make (1.0, 0.1, 0.5)
			s.solve (history_of (r), l_attempts, create {PT_WORD_TIMELINE}.make)
			assert_false ("incomplete", s.is_complete)
			assert_integers_equal ("three words missing", 3, s.missing_words.count)
		end

feature -- T16 snapper

	test_snapper_places_cuts_in_silence
		local
			l: PT_CUT_LIST
			n: PT_SILENCE_SNAPPER
		do
			create l.make
				-- Speech 22.85-24.41 in larry_read_01 (VAD), with silence before (from 19.17) and after (to 25.15).
			l.extend (create {PT_CUT}.make (0, span (22.86, 24.40), <<id (1)>>, 1, 1, 1, False))
			create n.make (0.12, 0.20)
			n.snap (l, larry_map, create {PT_WORD_TIMELINE}.make)
			assert_false ("not tight", n.last_result.cut (1).is_tight)
			assert_true ("starts in silence", larry_map.is_silent_at (n.last_result.cut (1).span.t0))
		end

feature -- T19 analyzer success path

	test_analyzer_success_path
		local
			a: PT_SESSION_ANALYZER
			r: PT_SCRIPT_REVISION
			j: PT_JOURNAL
			m: PT_SPEECH_MAP
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
		do
			r := revision_of (<<{STRING_32} "One two three.">>)
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_resume (0.5, r.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_wrap (4.0, "user"))
			create m.make (5.0)
			m.extend_span (span (1.0, 3.0))
			create l_words.make (3)
			l_words.extend (create {PT_HEARD_WORD}.make ({STRING_32} "one", {STRING_32} "one", 1.0, 1.5, 0.9))
			l_words.extend (create {PT_HEARD_WORD}.make ({STRING_32} "two", {STRING_32} "two", 1.6, 2.1, 0.9))
			l_words.extend (create {PT_HEARD_WORD}.make ({STRING_32} "three", {STRING_32} "three", 2.2, 2.9, 0.9))
			create a.make (create {PT_SCRIPTED_TRANSCRIBER}.make (m, create {PT_HEARD_WORDS}.make (0, 80_000, l_words)),
				create {PT_ATTEMPT_BUILDER}.make, create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
				create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
				create {PT_FLAGGER}.make (2.0))
			a.analyze ({STRING_32} "raw.mkv", 5.0, j, history_of (r))
			assert_true ("success", a.last_analysis.is_success)
			assert_integers_equal ("one cut", 1, a.last_analysis.cuts.count)
			assert_integers_equal ("three words heard", 3, a.last_analysis.timeline.count)
		end

feature -- T20 captions and chapters

	test_captions_respect_limits
		local
			b: PT_CAPTION_BUILDER
			l: PT_CUT_LIST
			r: PT_SCRIPT_REVISION
		do
			r := moody
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 30.0), ids_of (r), 1, r.word_count, 1, False))
			create b.make
			b.build (r, l, create {PT_WORD_TIMELINE}.make)
			assert_greater_than ("several cues", b.last_cues.count, 3)
			assert_true ("srt numbered", b.srt_text (b.last_cues).starts_with ("1%N"))
		end

	test_chapters_start_at_zero
		local
			w: PT_CHAPTER_WRITER
			l: PT_CUT_LIST
			r: PT_SCRIPT_REVISION
			t: STRING_32
		do
			r := read_test
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.0, 140.0), ids_of (r), 1, r.word_count, 1, False))
			create w.make
			t := w.text (r, l, create {PT_WORD_TIMELINE}.make, create {PT_JOURNAL}.make_in_memory)
			assert_true ("first chapter at 0:00", t.starts_with ({STRING_32} "0:00 Simple Prompter Read Test One"))
			assert_true ("closing chapter listed", t.has_substring ({STRING_32} "Closing"))
		end

feature -- T21 analysis codec

	test_analysis_codec_round_trip
		local
			k: PT_ANALYSIS_CODEC
			m: PT_SPEECH_MAP
			l: PT_CUT_LIST
			a: PT_ANALYSIS
		do
			create m.make (10.0)
			m.extend_span (span (1.0, 4.0))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.8, 4.2), <<id (1), id (2)>>, 1, 2, 1, False))
			create a.make (m, create {PT_WORD_TIMELINE}.make, create {ARRAYED_LIST [PT_ATTEMPT]}.make (0), l,
				create {ARRAYED_LIST [PT_FLAG]}.make (0), create {ARRAYED_LIST [STRING_32]}.make (0))
			create k.make
			k.decode (k.encode (a))
			assert_true ("success back", k.last_analysis.is_success)
			assert_integers_equal ("one cut back", 1, k.last_analysis.cuts.count)
			k.decode (k.encode (create {PT_ANALYSIS}.make_failed ({STRING_32} "model missing")))
			assert_false ("failure back", k.last_analysis.is_success)
		end

feature -- T23 settings

	test_settings_round_trip
		local
			s, t: PT_SETTINGS
			l_path: STRING_32
		do
			l_path := temp_path ({STRING_32} "settings.toml")
			create s.make_with_file (l_path)
			s.set_font_size (44)
			s.set_speed_wpm (150)
			s.set_devices ({STRING_32} "FHD Camera", {STRING_32} "Microphone (High Definition Audio Device)")
			s.set_video_delay (110)
			create t.make_with_file (l_path)
			assert_integers_equal ("picture delay back", 110, t.video_delay_ms)
			assert_integers_equal ("font back", 44, t.font_size)
			assert_integers_equal ("speed back", 150, t.speed_wpm)
			assert_true ("microphone back", t.microphone_name.same_string ({STRING_32} "Microphone (High Definition Audio Device)"))
		end

feature -- Sync (0.3.6)

	test_take_sync_is_kept_beside_the_take
		local
			s, t: PT_TAKE_SYNC
			l_path: STRING_32
			l_ok: BOOLEAN
		do
			l_path := temp_path ({STRING_32} "sync.toml")
			l_ok := (create {SIMPLE_FILE}.make (l_path)).delete
			create s.make (l_path, 110)
			assert_integers_equal ("starts from the last choice", 110, s.delay_ms)
			assert_false ("not the take's own yet", s.is_stored)
			s.step (1)
			assert_integers_equal ("nudged", 120, s.delay_ms)
			create t.make (l_path, 0)
			assert_integers_equal ("the take's own value wins", 120, t.delay_ms)
			assert_true ("stored", t.is_stored)
			t.set_measured (80)
			create s.make (l_path, 0)
			assert_true ("measured kept", s.is_measured and s.delay_ms = 80)
			s.step (-100)
			assert_integers_equal ("kept in range", {PT_TAKE_SYNC}.Min_ms, s.delay_ms)
			assert_false ("by hand now", s.is_measured)
			assert_true ("text", s.text.same_string ({STRING_32} "-500 ms"))
		end

	test_sync_measure_finds_a_clap_and_the_hands
			-- A clap sounds at 1.000 s; the hands close from 0.95 s and meet on the last moving frame
			-- (1.100 s); new frames every 1/30 s in a 60 a second stream: 1.100 - 1/60 - 1.000 = 83 ms.
		local
			m: PT_SYNC_MEASURE
			l_sound: SPECIAL [REAL_32]
			l_frames: SPECIAL [NATURAL_8]
			i, j, v: INTEGER
			t: REAL_64
		do
			create l_sound.make_filled (0.001, 3 * 16_000)
			from i := 16_000 until i >= 16_000 + 80 loop
				l_sound [i] := (0.8 * (1 - (i - 16_000) / 80)).truncated_to_real
				i := i + 1
			end
			create m.make
			m.find_claps (l_sound, l_sound.count)
			assert_integers_equal ("one clap", 1, m.claps.count)
			assert_true ("at 1.000 s", (m.claps.first - 1.0).abs < 0.002)
			create l_frames.make_filled (0, 72 * 4)
			v := 100
			from i := 0 until i >= 72 loop
				t := 0.7 + i / 60
				if i \\ 2 = 0 then
					v := v + (if t >= 0.95 and t <= 1.1 then 20 else 1 end)
				end
				from j := 0 until j >= 4 loop
					l_frames [i * 4 + j] := v.to_natural_8
					j := j + 1
				end
				i := i + 1
			end
			m.add_clap_frames (1.0, 0.7, l_frames, 4, 72)
			assert_integers_equal ("one delay", 1, m.delays.count)
			assert_integers_equal ("83 ms", 83, m.delays.first)
			assert_integers_equal ("to the nearest 10", 80, m.delay_ms)
			create l_frames.make_filled (90, 72 * 4)
			m.add_clap_frames (1.0, 0.7, l_frames, 4, 72)
			assert_integers_equal ("a still picture adds nothing", 1, m.delays.count)
		end

	test_sync_measure_ignores_soft_sounds
		local
			m: PT_SYNC_MEASURE
			l_sound: SPECIAL [REAL_32]
			i: INTEGER
		do
			create l_sound.make_filled (0.0, 16_000)
			from i := 0 until i >= l_sound.count loop
				l_sound [i] := (0.05 * ((i \\ 40) / 40 - 0.5)).truncated_to_real
				i := i + 1
			end
			create m.make
			m.find_claps (l_sound, l_sound.count)
			assert_true ("nothing loud enough", m.claps.is_empty)
			assert_false ("nothing found", m.is_found)
		end

feature -- T12 facade from disk

	test_open_read_test_from_disk
		local
			p: SIMPLE_PROMPTER
		do
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.open_script ({STRING_32} "testing/fixtures/read_test_01.md")
			assert_true ("loaded", p.has_script)
			assert_greater_than ("words", p.history.current_revision.word_count, 250)
		end

feature {NONE} -- Fixtures

	read_test: PT_SCRIPT_REVISION
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			p.parse ({STRING_32} "read_test_01", file_text ("testing/fixtures/read_test_01.md"), 1, create {PT_ID_SOURCE}.make)
			Result := p.last_revision
		end

	larry_map: PT_SPEECH_MAP
			-- VAD speech map of larry_read_01 (144.02 s).
		local
			l_fields: LIST [STRING_32]
		do
			create Result.make (144.02)
			across file_text ("testing/fixtures/larry_read_01.vad.tsv").split ('%N') as ic loop
				l_fields := ic.split ('%T')
				if l_fields.count = 2 and then l_fields [1].is_double and then l_fields [2].is_double
					and then l_fields [1].to_double >= Result.last_end then
					Result.extend_span (create {PT_TIME_SPAN}.make (l_fields [1].to_double, l_fields [2].to_double))
				end
			end
		end

	ids_of (a_revision: PT_SCRIPT_REVISION): ARRAYED_LIST [PT_WORD_ID]
			-- Required word ids in order.
		local
			i: INTEGER
		do
			create Result.make (a_revision.word_count)
			from i := 1 until i > a_revision.word_count loop
				if a_revision.word (i).is_required then
					Result.extend (a_revision.word (i).id)
				end
				i := i + 1
			end
		end

	index_of (a_revision: PT_SCRIPT_REVISION; a_normalized: READABLE_STRING_32): INTEGER
		local
			i: INTEGER
		do
			from i := 1 until Result > 0 or i > a_revision.word_count loop
				if a_revision.word (i).normalized.same_string (a_normalized) then
					Result := i
				end
				i := i + 1
			end
		end

	temp_path (a_name: READABLE_STRING_32): STRING_32
			-- Fresh file under testing/out.
		local
			l_dir: DIRECTORY
			l_ok: BOOLEAN
		do
			create l_dir.make ("testing/out")
			if not l_dir.exists then
				l_dir.create_dir
			end
			Result := {STRING_32} "testing/out/" + a_name
			if (create {SIMPLE_FILE}.make (Result)).exists then
				l_ok := (create {SIMPLE_FILE}.make (Result)).delete
			end
		end

	file_text (a_path: READABLE_STRING_GENERAL): STRING_32
		local
			l_raw: STRING_8
		do
			create l_raw.make (4096)
			across (create {SIMPLE_FILE}.make (a_path)).binary_content as ic loop
				l_raw.append_character (ic.to_character_8)
			end
			Result := (create {SIMPLE_ENCODING}.make).utf_8_to_utf_32 (l_raw)
			Result.prune_all ('%R')
		end

end
