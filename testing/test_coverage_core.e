note
	description: "[
		Phase 5 coverage: following, alignment, the speech pipeline, assembly, outputs and
		the script model. Every exported feature the earlier tests did not exercise,
		checked against its contract and its documented behavior.
	]"
	author: "Larry Rix"

class
	TEST_COVERAGE_CORE

inherit
	PT_TEST_SET

feature -- Time and timeline

	test_time_span_queries
		local
			s: PT_TIME_SPAN
		do
			s := span (1.0, 3.0)
			assert_true ("duration", s.duration = 2.0)
			assert_true ("midpoint", s.midpoint = 2.0)
			assert_true ("ends included", s.contains (1.0) and s.contains (3.0))
			assert_false ("outside", s.contains (3.5))
			assert_true ("overlap", s.overlaps (span (2.0, 4.0)))
			assert_false ("touching is not overlapping", s.overlaps (span (3.0, 5.0)))
			assert_refused ("reversed refused", agent span (2.0, 1.0))
			assert_refused ("negative refused", agent span (-1.0, 0.0))
		end

	test_word_timeline_queries
		local
			t: PT_WORD_TIMELINE
		do
			create t.make
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (1), span (1.0, 1.2), 0.9, 1))
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (2), span (1.3, 1.5), 0.9, 1))
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (1), span (5.0, 5.2), 0.8, 2))
			assert_true ("second occurrence", t.occurrence (2).word ~ id (2))
			assert_true ("last start", t.last_start = 5.0)
			assert_true ("found in attempt 2", attached t.occurrence_in (id (1), 2) as al_o and then al_o.span.t0 = 5.0)
			assert_false ("word 2 not in attempt 2", t.has_in (id (2), 2))
			assert_integers_equal ("model", 3, t.occurrences_model.count)
			assert_refused ("earlier occurrence refused", agent t.extend (create {PT_WORD_OCCURRENCE}.make (id (3), span (2.0, 2.1), 0.9, 2)))
		end

feature -- Equivalences and matcher

	test_equivalence_tables
		local
			e: PT_EQUIVALENCES
		do
			create e
			assert_true ("homophone class", e.homophone_class ({STRING_32} "there") > 0
				and e.homophone_class ({STRING_32} "there") = e.homophone_class ({STRING_32} "their"))
			assert_integers_equal ("no class", 0, e.homophone_class ({STRING_32} "zebra"))
			assert_true ("to / too", e.same_homophone_class ({STRING_32} "to", {STRING_32} "too"))
			assert_true ("e.g. spoken", across e.spoken_forms ({STRING_32} "eg") as ic some ic.same_string ({STRING_32} "for example") end)
			assert_true ("is spoken form", e.is_spoken_form ({STRING_32} "for example", {STRING_32} "eg"))
			assert_true ("no forms for a plain word", e.spoken_forms ({STRING_32} "camera").is_empty)
			assert_integers_equal ("number word", 20, e.number_value ({STRING_32} "twenty"))
			assert_integers_equal ("digits", 7, e.number_value ({STRING_32} "7"))
			assert_integers_equal ("not a number", -1, e.number_value ({STRING_32} "camera"))
			assert_true ("joined", e.joined ({STRING_32} "post-condition").same_string ({STRING_32} "postcondition")
				and e.joined ({STRING_32} "post condition").same_string ({STRING_32} "postcondition"))
			assert_true ("sound-alike keys", e.phonetic_key ({STRING_32} "color").same_string (e.phonetic_key ({STRING_32} "colour")))
			assert_integers_equal ("short keys ignored", 3, e.Min_phonetic_length)
		end

	test_matcher_queries
		local
			m: PT_WORD_MATCHER
		do
			create m
			assert_integers_equal ("one edit", 1, m.distance ({STRING_32} "kitten", {STRING_32} "sitten"))
			assert_integers_equal ("bounded", m.Max_distance + 1, m.distance ({STRING_32} "a", {STRING_32} "abcdef"))
			assert_integers_equal ("short words exact", 0, m.allowed_distance (4))
			assert_integers_equal ("medium words one edit", 1, m.allowed_distance (6))
			assert_integers_equal ("long words two edits", 2, m.allowed_distance (9))
			assert_true ("plural is a stem variant", m.is_stem_variant ({STRING_32} "words", {STRING_32} "word"))
			assert_false ("equal is not a variant", m.is_stem_variant ({STRING_32} "word", {STRING_32} "word"))
		end

feature -- Live aligner and followers

	test_aligner_reanchor_and_constants
		local
			a: PT_ALIGNER
		do
			create a.make (moody, create {PT_WORD_MATCHER})
			assert_integers_equal ("small jump needs one anchor", 1, a.required_anchors (a.Small_jump))
			assert_true ("big jump needs more", a.required_anchors (40) >= 2 and a.required_anchors (40) <= 3)
			a.reanchor (5, 1_600)
			assert_true ("stamped", a.reanchored_at = 1_600 and a.position = 5 and a.last_alignment.word_index = 5)
			a.update (heard (0, <<{STRING_32} "moody", {STRING_32} "is", {STRING_32} "a", {STRING_32} "notch", {STRING_32} "teleprompter">>))
			assert_integers_equal ("stale window ignored", 5, a.position)
			assert_true ("search windows ordered", a.Normal_ahead < a.Window_ahead and a.Window_back >= 0)
			assert_true ("lost after some misses", a.Lost_after >= 1 and a.Recent_heard >= 6)
			assert_true ("backward needs evidence", a.Backward_evidence >= 2)
			assert_refused ("jump 0 refused", agent a.required_anchors (0))
		end

	test_alignment_record
		local
			a: PT_ALIGNMENT
		do
			create a.make (5, 0.7, 4, 2, 2.5, 100)
			assert_true ("fields", a.word_index = 5 and a.confidence = 0.7 and a.matched_count = 4 and a.anchor_count = 2
				and a.rate_wps = 2.5 and a.sample_pos = 100)
			assert_true ("anchored", a.is_anchored)
			create a.make (0, 1.0, 3, 0, 0.0, 0)
			assert_false ("stop words alone do not anchor", a.is_anchored)
		end

	test_constant_follower_speed
		local
			f: PT_CONSTANT_FOLLOWER
		do
			create f.make (100, 120)
			assert_true ("two words a second", f.words_per_second = 2.0)
			f.release
			f.advance (1.0)
			f.set_wpm (60)
			assert_true ("speed changed", f.words_per_second = 1.0)
			assert_true ("target kept", (f.target - 2.0).abs < 1.0e-9)
			assert_true ("range", f.Min_wpm = 40 and f.Max_wpm = 400)
			assert_refused ("too slow refused", agent f.set_wpm (30))
		end

	test_voice_gated_ramps
		local
			g: PT_VOICE_GATED_FOLLOWER
		do
			create g.make (100, 120)
			g.release
			g.on_voice (frame (0, True))
			assert_true ("speaking", g.is_speaking)
			g.advance (0.05)
			assert_false ("still ramping up", g.ramp_finished)
			g.advance (1.0)
			assert_true ("full speed", g.ramp_finished and g.velocity = g.words_per_second)
			g.on_voice (frame (512, False))
			g.advance (1.0)
			assert_true ("stopped in silence", g.ramp_finished and g.velocity = 0)
			assert_true ("ramps", g.Ramp_up_s = 0.15 and g.Ramp_down_s = 0.20 and g.Min_wpm = 40 and g.Max_wpm = 400)
		end

	test_tracking_follower_steers_and_coasts
		local
			t: PT_TRACKING_FOLLOWER
		do
			create t.make (100, 120)
			assert_true ("fallback rate", t.fallback_rate = 2.0)
			t.release
			t.on_voice (frame (0, True))
			t.on_alignment (create {PT_ALIGNMENT}.make (10, 0.9, 5, 3, 3.0, 0))
			assert_integers_equal ("aligned word", 10, t.aligned_word)
			assert_true ("measured rate", t.measured_rate = 3.0)
			assert_true ("fresh anchor", t.seconds_since_anchor = 0 and t.has_alignment)
			t.advance (0.5)
			assert_true ("steering", t.velocity > 0 and t.seconds_since_anchor = 0.5)
			t.advance (2.0)
			t.advance (0.1)
			assert_true ("coasted to a stop", t.velocity = 0)
			t.set_caret (20)
			assert_false ("restart forgets the alignment", t.has_alignment)
			assert_true ("constants", t.Coast_limit = 1.5 and t.Min_rate = 1.0 and t.Max_rate_factor = 3.0 and t.Steer_gain = 1.5)
		end

	test_layout_lines_and_scroll
		local
			l: PT_LAYOUT
			ln: PT_LINE
			s: PT_SCROLL_MODEL
			f: PT_CONSTANT_FOLLOWER
		do
			create l.make
			l.build (moody, create {PT_FIXED_MEASURE}.make (10.0, 30.0), 300.0)
			assert_true ("width and pitch", l.width = 300.0 and l.line_height = 30.0)
			assert_integers_equal ("first word on line 1", 1, l.line_of (1))
			assert_true ("last word on its line", l.line (l.line_of (l.word_count)).contains (l.word_count))
			assert_true ("lines go down", l.line (2).y > l.line (1).y)
			assert_integers_equal ("line starts", l.line_count, l.line_starts_model.count)
			assert_true ("offset at the start", l.y_of (0) >= 0)
			create ln.make (3, 7, 120.0, 60.0)
			assert_true ("line fields", ln.word_count = 5 and ln.width = 120.0 and ln.y = 60.0 and ln.contains (5) and not ln.contains (8))
			create f.make (l.word_count, 120)
			create s.make (f, l, create {PT_SPRING}.make (10.0))
			s.tick (0)
			f.release
			s.tick (2_000)
			assert_true ("scrolled", s.position > 0 and s.y_offset >= 0)
		end

	test_spring_rate_and_reset
		local
			s: PT_SPRING
		do
			create s.make (8.0)
			assert_true ("omega", s.omega = 8.0)
			s.step (10.0, 0.05)
			assert_true ("moving toward the target", s.rate > 0 and s.value > 0)
			s.reset (3.0)
			assert_true ("placed at rest", s.value = 3.0 and s.rate = 0)
		end

feature -- Speech pipeline

	test_pipeline_threshold_decoding_and_frames
		local
			p: PT_SPEECH_PIPELINE
			d: PT_SCRIPTED_DECODER
		do
			create d.make
			d.script_window (0, <<{STRING_32} "This", {STRING_32} "is">>)
			assert_integers_equal ("scripted", 1, d.scripted_count)
			create p.make (create {PT_SCRIPTED_VAD}.make (<<1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0>>), d)
			assert_true ("decoding on at start", p.is_decoding_enabled)
			assert_true ("default threshold", p.threshold = p.Default_threshold)
			p.set_threshold (0.7)
			assert_true ("threshold set", p.threshold = 0.7)
			p.disable_decoding
			assert_false ("decoding off", p.is_decoding_enabled)
			p.push (silence (4_000), 4_000)
			assert_integers_equal ("no decode when disabled", 0, p.pending_heard_count)
			assert_true ("in speech", p.is_in_speech and p.last_push_had_speech)
			assert_true ("first frame at 0 s", p.pending_frame (1).seconds = 0)
			p.enable_decoding
			p.push (silence (4_000), 4_000)
			assert_integers_equal ("decoded at the step", 1, p.pending_heard_count)
			assert_true ("window end", p.pending_heard (1).window_end = p.pending_heard (1).window_start + p.pending_heard (1).window_samples)
			assert_integers_equal ("normalized model", p.pending_heard (1).count, p.pending_heard (1).normalized_model.count)
			assert_true ("constants", p.Sample_rate = 16_000 and p.Frame_samples = 512 and p.Step_samples = 4_000
				and p.Window_samples = 48_000 and p.Hangover_frames = 8 and {PT_VAD}.Frame_samples = p.Frame_samples)
			assert_refused ("threshold 1 refused", agent p.set_threshold (1.0))
		end

	test_speech_codec_heard_round_trip
		local
			c: PT_SPEECH_CODEC
		do
			create c.make
			c.decode (c.encode_heard (heard (16_000, <<{STRING_32} "one", {STRING_32} "two">>)))
			assert_true ("heard back", attached c.last_heard as al_h and then (al_h.count = 2 and al_h.window_start = 16_000
				and al_h.word (2).normalized.same_string ({STRING_32} "two") and al_h.word (1).probability = 0.9))
			assert_true ("not a frame", c.last_frame = Void)
			c.decode ("garbage")
			assert_true ("bad record clears both", c.last_frame = Void and c.last_heard = Void)
		end

	test_voice_frame_seconds_and_fakes
		local
			v: PT_SCRIPTED_VAD
			k: PT_FAKE_CLOCK
			l_pipeline: PT_SPEECH_PIPELINE
		do
			assert_true ("frame seconds", frame (16_000, True).seconds = 1.0)
			assert_true ("frame probability", frame (16_000, True).speech_probability = 0.95 and frame (0, False).speech_probability = 0.02)
			create v.make (<<0.1, 0.9>>)
			assert_integers_equal ("scripted probabilities", 2, v.probabilities.count)
			v.analyze (silence (512), 0, 512)
			assert_true ("analyzed", v.last_probability = 0.9)
			v.reset
			assert_true ("reset clears", v.last_probability = 0.0 and v.reset_count = 1)
			create l_pipeline.make (v, create {PT_SCRIPTED_DECODER}.make)
			assert_integers_equal ("a new pipeline resets its detector", 2, v.reset_count)
			create k.make
			k.set (250.0)
			assert_true ("fake clock set", k.now_ms = 250.0)
		end

feature -- Assembly

	test_cut_and_cut_list_queries
		local
			c, c2: PT_CUT
			l: PT_CUT_LIST
		do
			create c.make (0, span (1.0, 3.0), <<id (1), id (2)>>, 1, 2, 1, False)
			assert_true ("fields", c.src = 0 and c.word_ids.count = 2 and c.first_word_index = 1 and c.last_word_index = 2)
			assert_true ("first and last words", c.first_word ~ id (1) and c.last_word ~ id (2))
			c2 := c.with_span (span (0.8, 3.2), True)
			assert_true ("re-spanned", c2.word_ids ~ c.word_ids and c2.is_tight and c2.attempt = c.attempt and c2.span.t0 = 0.8)
			create l.make
			l.extend (c)
			l.extend (create {PT_CUT}.make (0, span (5.0, 6.0), <<id (3)>>, 3, 3, 1, False))
			assert_true ("kept duration", (l.source_kept_duration (0) - 3.0).abs < 1.0e-9)
			assert_true ("span total", (l.span_total (l.cuts_model) - 3.0).abs < 1.0e-9)
			assert_true ("floor is the rest", (l.list_total (l.floor_spans (0, 8.0)) - 5.0).abs < 1.0e-6)
			assert_true ("output time", (l.to_output_time (0, 5.5) - 2.5).abs < 1.0e-9)
			assert_false ("gap not kept", l.is_kept (0, 4.0))
			assert_refused ("script disorder refused", agent l.extend (create {PT_CUT}.make (0, span (7.0, 8.0), <<id (1)>>, 1, 1, 1, False)))
		end

	test_attempt_and_builder
		local
			a: PT_ATTEMPT
			b: PT_ATTEMPT_BUILDER
			j: PT_JOURNAL
			r: PT_SCRIPT_REVISION
		do
			create a.make (1, span (0.0, 5.0), id (1), 1, 2, 4, False, True)
			assert_true ("range", a.first_index = 2 and a.last_index = 4 and a.word_count = 3)
			assert_true ("rejected", a.is_rejected and not a.is_starred)
			r := revision_of (<<{STRING_32} "One two three.">>)
			create j.make_in_memory
			j.append (create {PT_TAKE_EVENT}.make_resume (0.5, r.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_star (2.0, "hotkey"))
			j.append (create {PT_TAKE_EVENT}.make_resume (3.0, r.word (1).id, 1))
			j.append (create {PT_TAKE_EVENT}.make_wrap (5.0, "user"))
			create b.make
			b.build (j, history_of (r), 5.0)
			assert_integers_equal ("two attempts", 2, b.last_attempts.count)
			assert_integers_equal ("one starred", 1, b.starred_count)
		end

	test_take_solver_queries
		local
			s: PT_TAKE_SOLVER
			r: PT_SCRIPT_REVISION
			h: PT_SCRIPT_HISTORY
			l_attempts: ARRAYED_LIST [PT_ATTEMPT]
			t: PT_WORD_TIMELINE
			i: INTEGER
		do
			create s.make (1.0, 0.1, 0.5)
			assert_true ("costs", s.splice_cost = 1.0 and s.age_penalty = 0.1 and s.min_confidence = 0.5)
			r := revision_of (<<{STRING_32} "One two.", {STRING_32} "Three four.">>)
			h := history_of (r)
			assert_true ("passage starts", s.is_passage_start (r, 1) and s.is_passage_start (r, 3) and not s.is_passage_start (r, 2))
			create l_attempts.make (1)
			l_attempts.extend (create {PT_ATTEMPT}.make (1, span (0.0, 10.0), r.word (1).id, 1, 1, 4, False, False))
			create t.make
			from i := 1 until i > 4 loop
				t.extend (create {PT_WORD_OCCURRENCE}.make (r.word (i).id, span (i.to_double, i + 0.5), 0.9, 1))
				i := i + 1
			end
			s.solve (h, l_attempts, t)
			assert_true ("complete", s.is_complete and s.missing_words.is_empty)
			assert_true ("decisions logged", s.decisions.count >= 1)
			assert_true ("current take", s.is_current_take (s.last_result.cut (1), h, l_attempts))
			assert_false ("no star to supersede it", s.superseded_by_star (s.last_result.cut (1), l_attempts))
		end

	test_flagger_low_confidence_restart_and_pause
		local
			f: PT_FLAGGER
			m: PT_SPEECH_MAP
			t: PT_WORD_TIMELINE
			l: PT_CUT_LIST
		do
			create m.make (20.0)
			m.extend_span (span (1.0, 3.0))
			m.extend_span (span (6.0, 8.0))
			create t.make
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (1), span (1.0, 1.4), 0.2, 1))
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (2), span (1.5, 1.9), 0.9, 1))
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (2), span (6.5, 6.9), 0.9, 1))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.5, 9.0), <<id (1), id (2)>>, 1, 2, 1, False))
			create f.make (2.0)
			f.flag (l, create {ARRAYED_LIST [PT_WORD_ID]}.make (0), t, m)
			assert_integers_equal ("low confidence", 1, f.count_of ({PT_FLAG_KIND}.Low_confidence))
			assert_integers_equal ("unmarked restart", 1, f.count_of ({PT_FLAG_KIND}.Unmarked_restart))
			assert_integers_equal ("long pause kept", 1, f.count_of ({PT_FLAG_KIND}.Long_pause))
			assert_integers_equal ("nothing missing", 0, f.count_of ({PT_FLAG_KIND}.Missing))
			assert_integers_equal ("no tight cuts", 0, f.tight_count (l))
			assert_true ("settings", f.long_pause_s = 2.0 and f.Low_confidence_level = 0.35)
			assert_true ("messages", across f.last_flags as ic all not ic.message.is_empty end)
			assert_true ("kinds 1..6", {PT_FLAG_KIND}.Misread = 1 and {PT_FLAG_KIND}.Low_confidence = 2
				and {PT_FLAG_KIND}.Unmarked_restart = 3 and {PT_FLAG_KIND}.Tight_splice = 4
				and {PT_FLAG_KIND}.Missing = 5 and {PT_FLAG_KIND}.Long_pause = 6)
		end

	test_snapper_pads_and_words_inside
		local
			s: PT_SILENCE_SNAPPER
			t: PT_WORD_TIMELINE
			c: PT_CUT
		do
			create s.make (0.12, 0.2)
			assert_true ("pads", s.head_pad = 0.12 and s.tail_pad = 0.2)
			assert_true ("limits", s.Probe = 0.02 and s.Max_lead = 0.6 and s.Max_tail = 0.8)
			create t.make
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (1), span (1.0, 1.4), 0.9, 1))
			create c.make (0, span (0.8, 2.0), <<id (1)>>, 1, 1, 1, False)
			assert_true ("word inside", s.words_inside (c, t))
			create c.make (0, span (1.2, 2.0), <<id (1)>>, 1, 1, 1, False)
			assert_false ("word clipped", s.words_inside (c, t))
		end

	test_analysis_records
		local
			an: PT_SESSION_ANALYZER
			tr: PT_SCRIPTED_TRANSCRIBER
			r: PT_SCRIPT_REVISION
			j: PT_JOURNAL
			m: PT_SPEECH_MAP
			a: PT_ANALYSIS
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
		do
			create a.make_failed ({STRING_32} "no GPU")
			assert_true ("failed analysis", not a.is_success and attached a.error as al_e and then al_e.same_string ({STRING_32} "no GPU"))
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
			create tr.make (m, create {PT_HEARD_WORDS}.make (0, 80_000, l_words))
			create an.make (tr, create {PT_ATTEMPT_BUILDER}.make, create {PT_ATTEMPT_ALIGNER}.make (create {PT_WORD_MATCHER}),
				create {PT_TAKE_SOLVER}.make (1.0, 0.1, 0.5), create {PT_SILENCE_SNAPPER}.make (0.12, 0.20),
				create {PT_FLAGGER}.make (2.0))
			assert_true ("transcriber", an.transcriber = tr)
			an.analyze ({STRING_32} "raw.mkv", 5.0, j, history_of (r))
			assert_true ("speech map", an.last_analysis.speech_map.duration = 5.0)
			assert_true ("decisions", an.last_analysis.decisions.count >= 1)
			assert_true ("no flags on a clean read", an.last_analysis.flags.is_empty)
			assert_true ("no error", an.last_analysis.error = Void)
		end

	test_snapper_steps_over_vad_margins
			-- Whisper word times usually sit inside the VAD speech span (breath, hangover): the cut
			-- edges must still land in the silence just outside it, not be marked tight.
		local
			s: PT_SILENCE_SNAPPER
			m: PT_SPEECH_MAP
			t: PT_WORD_TIMELINE
			l: PT_CUT_LIST
		do
			create m.make (10.0)
			m.extend_span (span (1.0, 3.0))
			create t.make
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (1), span (1.2, 1.6), 0.9, 1))
			t.extend (create {PT_WORD_OCCURRENCE}.make (id (2), span (2.2, 2.8), 0.9, 1))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (1.2, 2.8), <<id (1), id (2)>>, 1, 2, 1, False))
			create s.make (0.12, 0.2)
			s.snap (l, m, t)
			assert_false ("not tight", s.last_result.cut (1).is_tight)
			assert_true ("starts in silence", m.is_silent_at (s.last_result.cut (1).span.t0) and s.last_result.cut (1).span.t0 >= 1.2 - s.Max_lead)
			assert_true ("ends in silence", m.is_silent_at (s.last_result.cut (1).span.t1) and s.last_result.cut (1).span.t1 <= 2.8 + s.Max_tail)
			create m.make (10.0)
			m.extend_span (span (1.0, 6.0))
			s.snap (l, m, t)
			assert_true ("speech running past the tail limit is tight", s.last_result.cut (1).is_tight)
		end

	test_silence_searches_and_speech_map
		local
			s: PT_SILENCE_SNAPPER
			m: PT_SPEECH_MAP
		do
			create s.make (0.12, 0.2)
			create m.make (10.0)
			m.extend_span (span (1.0, 3.0))
			assert_integers_equal ("one speech span", 1, m.span_count)
			assert_integers_equal ("spans model", 1, m.spans_model.count)
			assert_true ("silence after the speech", attached s.silence_after (m, 2.9) as al_a and then al_a.t0 = 3.0)
			assert_true ("silence before the speech", attached s.silence_before (m, 1.1) as al_b and then al_b.t1 = 1.0)
			create m.make (10.0)
			m.extend_span (span (1.0, 8.0))
			assert_true ("speech past the tail limit", s.silence_after (m, 2.9) = Void)
			assert_true ("speech before the lead limit", s.silence_before (m, 5.0) = Void)
		end

feature -- Outputs

	test_captions_vtt_and_cue_words
		local
			b: PT_CAPTION_BUILDER
			r: PT_SCRIPT_REVISION
			l: PT_CUT_LIST
			t: PT_WORD_TIMELINE
			i: INTEGER
		do
			r := revision_of (<<{STRING_32} "One two three.">>)
			create t.make
			from i := 1 until i > 3 loop
				t.extend (create {PT_WORD_OCCURRENCE}.make (r.word (i).id, span (i.to_double, i + 0.4), 0.9, 1))
				i := i + 1
			end
			create l.make
			l.extend (create {PT_CUT}.make (0, span (0.8, 3.6), <<r.word (1).id, r.word (2).id, r.word (3).id>>, 1, 3, 1, False))
			create b.make
			b.build (r, l, t)
			assert_true ("vtt header", b.vtt_text (b.last_cues).starts_with ("WEBVTT"))
			assert_integers_equal ("ids carried", 3, b.concatenated_ids (b.last_cues).count)
			assert_integers_equal ("cue words", 3, b.last_cues.first.word_ids.count)
			assert_true ("limits", b.Max_cue_chars = 84 and b.Max_cue_seconds = 6.0)
			assert_true ("vtt time", b.timecode.vtt (1.5).same_string ("00:00:01.500"))
		end

	test_edl_helpers
		local
			e: PT_EDL_WRITER
			l: PT_CUT_LIST
		do
			create e.make
			assert_true ("event numbers", e.event_number (7).same_string ("007") and e.event_number (123).same_string ("123"))
			assert_true ("short reel padded", e.reel_field ("AX").count = 8 and e.reel_field ("AX").starts_with ("AX"))
			assert_true ("long reel cut", e.reel_field ("TOOLONGREELNAME").same_string ("TOOLONGR"))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (1.0, 3.0), <<id (1)>>, 1, 1, 1, False))
			l.extend (create {PT_CUT}.make (0, span (5.0, 6.0), <<id (2)>>, 2, 2, 1, False))
			assert_true ("second cut starts after the first", (e.record_in (l, 2) - 2.0).abs < 1.0e-9)
			assert_true ("edl time", e.timecode.edl (1.5, 30).same_string ("00:00:01:15"))
		end

	test_cut_codec_errors_and_objects
		local
			c: PT_CUT_CODEC
			l: PT_CUT_LIST
		do
			create c.make
			c.decode ("not json")
			assert_true ("error", attached c.last_error and not c.has_cuts)
			create l.make
			l.extend (create {PT_CUT}.make (0, span (1.0, 3.0), <<id (1)>>, 1, 1, 1, False))
			create c.make
			c.read_cuts (c.cuts_object (l))
			assert_true ("object round trip", c.has_cuts and c.last_cuts.count = 1 and c.last_cuts.cut (1).span.t1 = 3.0)
		end

	test_render_plan_fields
		local
			p: PT_RENDER_PLAN
			l: PT_CUT_LIST
		do
			create p.make ({STRING_32} "ffmpeg.exe", 0, True)
			assert_true ("fields", p.fade_ms = 0 and p.is_punch_in)
			assert_true ("three decimals", p.seconds (4.2).same_string ("4.200"))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (1.0, 3.0), <<id (1)>>, 1, 1, 1, False))
			l.extend (create {PT_CUT}.make (0, span (5.0, 6.0), <<id (2)>>, 2, 2, 1, False))
			assert_integers_equal ("no fades when fade is 0", 0, p.occurrences (p.filter_script (l), "afade="))
			assert_integers_equal ("occurrences", 2, p.occurrences ("aXbXc", "X"))
			assert_refused ("fade above 200 ms refused", agent new_render_plan (250))
		end

	test_review_srt_helpers
		local
			w: PT_REVIEW_SRT_WRITER
			r: PT_SCRIPT_REVISION
		do
			create w.make
			assert_true ("shown marks", w.is_shown ({PT_EVENT_KIND}.Flub) and w.is_shown ({PT_EVENT_KIND}.Marker)
				and w.is_shown ({PT_EVENT_KIND}.Wrap))
			assert_false ("hidden events", w.is_shown ({PT_EVENT_KIND}.Align) or w.is_shown ({PT_EVENT_KIND}.Resume)
				or w.is_shown ({PT_EVENT_KIND}.Session_start) or w.is_shown ({PT_EVENT_KIND}.Count_in))
			assert_false ("separator neutralized", w.safe ({STRING_32} "a --> b").has_substring (" --> "))
			r := revision_of (<<{STRING_32} "One two three.">>)
			assert_true ("word text", w.word_text (r.word (2).id, history_of (r)).same_string ({STRING_32} "two"))
			assert_true ("cue length", w.Cue_seconds = 2.0)
			assert_true ("srt time", w.timecode.srt (0).same_string ("00:00:00,000"))
		end

	test_chapter_and_timecode_helpers
		local
			c: PT_CHAPTER_WRITER
			q: PT_CAPTION_CUE
		do
			create c.make
			assert_true ("chapter time", c.timecode.chapter (65.0).same_string ("1:05"))
			assert_true ("digits", c.timecode.is_digits ("0123") and not c.timecode.is_digits ("12a"))
			create q.make (0.0, 1.0, {STRING_32} "hi", <<id (1)>>)
			assert_integers_equal ("cue word ids", 1, q.word_ids.count)
		end

feature -- Script model

	test_script_edit_kinds
		local
			e: PT_SCRIPT_EDIT
		do
			create e.make (1, 3, 2, {STRING_32} "new words")
			assert_true ("insertion", e.is_insertion and not e.is_strike)
			assert_true ("fields", e.from_revision = 1 and e.new_text.same_string ({STRING_32} "new words"))
			create e.make (2, 2, 4, {STRING_32} "")
			assert_true ("strike", e.is_strike and not e.is_insertion)
		end

	test_restart_policy_units
		local
			p: PT_RESTART_POLICY
			r: PT_SCRIPT_REVISION
			l_caret: INTEGER
		do
			create p
			r := moody
			l_caret := r.passage (3).first_word + 2
			assert_integers_equal ("passage start", r.passage (3).first_word, p.passage_start (r, l_caret))
			assert_true ("back one paragraph moves back", p.step_back (r, l_caret, p.Unit_paragraph) < l_caret)
			assert_true ("units", p.Early_words = 2 and p.Unit_passage /= p.Unit_paragraph)
			assert_refused ("unknown unit refused", agent p.step_back (r, l_caret, 9))
		end

	test_script_parser_classification
		local
			p: PT_SCRIPT_PARSER
		do
			create p.make
			assert_false ("nothing parsed", p.has_parsed)
			assert_true ("sentence ends", p.ends_sentence ({STRING_32} "end.") and p.ends_sentence ({STRING_32} "go!"))
			assert_false ("titles do not end sentences", p.ends_sentence ({STRING_32} "Dr.") or p.ends_sentence ({STRING_32} "e.g."))
			assert_false ("plain word", p.ends_sentence ({STRING_32} "word"))
			assert_true ("abbreviations", p.is_abbreviation ({STRING_32} "e.g.") and p.is_abbreviation ({STRING_32} "U.S."))
			assert_true ("known titles", p.Abbreviations.count > 0)
			assert_false ("blank has no words", p.has_words ({STRING_32} "   "))
			assert_true ("text has words", p.has_words ({STRING_32} " x "))
		end

	test_revision_and_structure_queries
		local
			p: PT_SCRIPT_PARSER
			r: PT_SCRIPT_REVISION
			l_words: ARRAYED_LIST [PT_WORD]
			l_passages: ARRAYED_LIST [PT_PASSAGE]
			q: PT_PASSAGE
		do
			create p.make
			p.parse ({STRING_32} "My Title", {STRING_32} "# Heading%N%NThe one two. Three four.%N%N[CUE: smile]%N%NFive.", 1, create {PT_ID_SOURCE}.make)
			r := p.last_revision
			assert_true ("title", r.title.same_string ({STRING_32} "My Title"))
			assert_true ("source", r.source_text.has_substring ({STRING_32} "Three four."))
			assert_integers_equal ("passage bounds", r.passage_count, r.passage_bounds_model.count)
			assert_true ("structure", r.word (2).char_start >= 1 and r.word (2).char_end >= r.word (2).char_start
				and r.word (2).passage_index >= 1 and r.word (2).paragraph_index >= 1 and r.word (2).section_index >= 0)
			assert_true ("the is a stop word", r.word (index_named (r, {STRING_32} "the")).is_stop_word)
			assert_true ("cue word", r.word (index_named (r, {STRING_32} "smile")).is_cue)
			create l_words.make (2)
			l_words.extend (create {PT_WORD}.make (id (1), {STRING_32} "a", {STRING_32} "a", 1, 1, 1, 1, 0, False, False, False))
			l_words.extend (create {PT_WORD}.make (id (1), {STRING_32} "b", {STRING_32} "b", 3, 3, 1, 1, 0, False, False, False))
			assert_false ("duplicate ids", r.ids_are_unique (l_words))
			create l_passages.make (1)
			l_passages.extend (create {PT_PASSAGE}.make (1, 1, 2, 1, 0))
			assert_false ("passages must cover every word", r.passages_partition (3, l_passages))
			create q.make (2, 5, 9, 1, 1)
			assert_true ("passage fields", q.paragraph_index = 1 and q.section_index = 1 and q.word_count = 5
				and q.contains (7) and not q.contains (10))
		end

	test_history_ids_and_journal_status
		local
			h: PT_SCRIPT_HISTORY
			s: PT_ID_SOURCE
			j: PT_JOURNAL
		do
			h := history_of (moody)
			assert_integers_equal ("one revision", 1, h.revisions_model.count)
			h.apply_edit (1, 1, {STRING_32} "That")
			assert_integers_equal ("two revisions", 2, h.revisions_model.count)
			create s.make_after (10)
			s.issue
			assert_true ("ids continue", s.last_issued = 11)
			create j.make_in_memory
			assert_true ("open, in memory", j.is_open and not j.is_persistent and j.events_model.count = 0)
			j.codec.decode ("{bad")
			assert_true ("codec error", j.codec.has_error and attached j.codec.last_error)
		end

	test_event_names_and_edit_fields
		local
			k: PT_EVENT_KIND
			c: PT_TAKE_CONTROLLER
			l_names: ARRAYED_LIST [STRING_8]
			l_kind: INTEGER
		do
			create k
			create l_names.make (14)
			from l_kind := k.Session_start until l_kind > k.Abort loop
				assert_false ("named", k.name (l_kind).is_empty)
				assert_false ("distinct", across l_names as ic some ic.same_string (k.name (l_kind)) end)
				l_names.extend (k.name (l_kind))
				l_kind := l_kind + 1
			end
			c := controller_for (moody)
			c.perform ({PT_ACTION}.Record)
			c.perform ({PT_ACTION}.Hold)
			c.perform ({PT_ACTION}.Edit_open)
			c.commit_edit ({STRING_32} "This is Moody again.")
			assert_integers_equal ("edit journaled", k.Edit, c.journal.last_event.kind)
			assert_true ("revisions", c.journal.last_event.from_rev = 1 and c.journal.last_event.to_rev = 2)
			assert_false ("range", c.journal.last_event.range_first.is_none or c.journal.last_event.range_last.is_none)
			assert_true ("texts", attached c.journal.last_event.old_text and attached c.journal.last_event.new_text)
			assert_true ("new ids", attached c.journal.last_event.new_ids as al_ids and then al_ids.count = 4)
			assert_true ("count-in seconds", (create {PT_TAKE_EVENT}.make_count_in (1.0, 2.5)).seconds = 2.5)
		end

	test_fixed_measure_and_heard_word
		local
			m: PT_FIXED_MEASURE
		do
			create m.make (10.0, 30.0)
			assert_true ("measure", m.char_width = 10.0 and m.space_advance = 10.0 and m.line_height = 30.0 and m.advance ({STRING_32} "abc") = 30.0)
			assert_true ("probability", (create {PT_HEARD_WORD}.make ({STRING_32} "x", {STRING_32} "x", 0.0, 0.1, 0.75)).probability = 0.75)
		end

feature {NONE} -- Helpers

	index_named (a_revision: PT_SCRIPT_REVISION; a_normalized: READABLE_STRING_32): INTEGER
			-- First word whose normal form is `a_normalized'.
		local
			l_i: INTEGER
		do
			from l_i := 1 until Result > 0 or l_i > a_revision.word_count loop
				if a_revision.word (l_i).normalized.same_string (a_normalized) then
					Result := l_i
				end
				l_i := l_i + 1
			end
		end

	new_render_plan (a_fade: INTEGER)
		local
			p: PT_RENDER_PLAN
		do
			create p.make ({STRING_32} "ffmpeg.exe", a_fade, False)
		end

end
