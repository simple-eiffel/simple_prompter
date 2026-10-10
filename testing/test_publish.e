note
	description: "[
		0.5.0 Publish step, the pure parts: the script's prose, captions of what was said,
		chapters, the finishing ffmpeg plan, the local AI's suggestions and the copy for
		YouTube, Facebook and X.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	TEST_PUBLISH

inherit
	PT_TEST_SET

feature -- Script text

	test_script_text_keeps_prose_only
		local
			s: PT_SCRIPT_TEXT
		do
			create s.make (script_markdown)
			assert_true ("title", s.title.same_string ({STRING_32} "Worthless Servant!"))
			assert_integers_equal ("three paragraphs, cues left out", 3, s.paragraphs.count)
			assert_true ("first paragraph", s.paragraphs.first.starts_with ({STRING_32} "Worthless servant!"))
			assert_integers_equal ("two sentences in the first", 2, s.sentences_of (s.paragraphs.first).count)
			assert_true ("a quote's end ends a sentence", s.ends_sentence ({STRING_32} "him.%""))
			assert_false ("a comma does not", s.ends_sentence ({STRING_32} "him,"))
		end

feature -- Spoken captions

	test_spoken_captions_follow_what_was_said
		local
			c: PT_SPOKEN_CAPTIONS
			l_all: STRING_32
		do
			create c.make
			c.build (heard_reel, speech, create {PT_SCRIPT_TEXT}.make (script_markdown), 0.85, 20.0)
			create l_all.make (200)
			across c.last_cues as ic loop
				l_all.append (ic.text + {STRING_32} "|")
			end
			assert_integers_equal ("three captions", 3, c.last_cues.count)
			assert_true ("opening line kept", c.last_cues [1].text.same_string ({STRING_32} "Worthless servant!"))
			assert_true ("the repeat is gone, the script's wording kept", c.last_cues [2].text.same_string ({STRING_32} "The servant has done his work."))
			assert_true ("12 read as the script's twelve", c.last_cues [3].text.same_string ({STRING_32} "Now go back to Luke chapter twelve."))
			assert_false ("nothing invented in the silence", l_all.has_substring ({STRING_32} "Thank"))
			assert_integers_equal ("six words left out", 6, c.dropped_count)
			assert_true ("moved to the output timeline", (c.last_cues [1].t0 - 0.25).abs < 0.001)
		end

	test_spoken_captions_split_long_sentences
		local
			c: PT_SPOKEN_CAPTIONS
			l_words: ARRAYED_LIST [PT_HEARD_WORD]
			l_map: PT_SPEECH_MAP
			i: INTEGER
		do
			create l_words.make (24)
			across ({STRING_32} "While the disciples are saying to him that he ought to eat something, Jesus lifts their eyes from the lunch to the road ahead of them.").split (' ') as ic loop
				l_words.extend (create {PT_HEARD_WORD}.make (ic, ic.as_lower, 1.0 + i * 0.3, 1.25 + i * 0.3, 0.9))
				i := i + 1
			end
			create l_map.make (30.0)
			l_map.extend_span (span (0.9, 1.4 + i * 0.3))
			create c.make
			c.build (l_words, l_map, create {PT_SCRIPT_TEXT}.make ({STRING_32} "# T"), 0.0, 30.0)
			assert_integers_equal ("two captions", 2, c.last_cues.count)
			assert_true ("split after the comma", c.last_cues [1].text.ends_with ({STRING_32} "something,"))
			assert_true ("two lines each", c.last_cues [1].text.has ('%N') and c.last_cues [2].text.has ('%N'))
			assert_true ("in order", c.last_cues [1].t1 <= c.last_cues [2].t0)
		end

	test_number_words
		local
			c: PT_SPOKEN_CAPTIONS
		do
			create c.make
			assert_true ("34", c.number_words (34).same_string ({STRING_32} "thirtyfour"))
			assert_true ("17", c.number_words (17).same_string ({STRING_32} "seventeen"))
			assert_true ("heard 4 is four", c.same_word ({STRING_32} "4", {STRING_32} "four"))
			assert_false ("4 is not five", c.same_word ({STRING_32} "4", {STRING_32} "five"))
		end

feature -- Chapters

	test_chapters_are_spaced_and_start_at_zero
		local
			p: PT_CHAPTER_PICKER
			l_cues: ARRAYED_LIST [PT_CAPTION_CUE]
		do
			create l_cues.make (4)
			l_cues.extend (cue (0.3, 3.0, "Worthless servant! That's what Jesus told you"))
			l_cues.extend (cue (8.0, 12.0, "Start with the first one."))
			l_cues.extend (cue (30.0, 34.0, "That was every household%Nservant's life."))
			l_cues.extend (cue (45.0, 49.0, "chapter 4, Jesus is tired."))
			l_cues.extend (cue (60.0, 64.0, "Now go back to Luke chapter twelve."))
			create p.make
			p.pick (create {PT_SCRIPT_TEXT}.make (chapter_script), l_cues, 80.0)
			assert_integers_equal ("four chapters (one too close)", 4, p.chapters.count)
			assert_true ("a dropped word and a digit still match", p.text.has_substring ({STRING_32} "0:45 John chapter four"))
			assert_true ("first at 0:00", p.text.starts_with ({STRING_32} "0:00 Worthless servant!"))
			assert_true ("line breaks in a caption still match", p.text.has_substring ({STRING_32} "0:30 That was every household servant's life"))
			assert_true ("1:00", p.text.has_substring ({STRING_32} "1:00 Now go back to Luke chapter twelve"))
			p.set_labels (create {ARRAYED_LIST [STRING_32]}.make_from_array (<<{STRING_32} "A", {STRING_32} "B", {STRING_32} "C", {STRING_32} "D">>))
			assert_true ("labels replaced", p.text.same_string ({STRING_32} "0:00 A%N0:30 B%N0:45 C%N1:00 D%N"))
		end

feature -- Finish plan

	test_finish_plan_with_and_without_thumbnail
		local
			f: PT_FINISH_PLAN
			l_args: ARRAYED_LIST [STRING_32]
		do
			create f.make (1.35, 162.37, 163.18)
			assert_true ("seconds format", f.seconds (1.35).same_string ({STRING_32} "1.350"))
			assert_true ("held", (f.length - (163.18 - 1.35 + 0.8)).abs < 0.0001)
			assert_true ("fade after the last word", f.fade_start >= 162.37 - 1.35)
			l_args := f.arguments ({STRING_32} "C:\take\out\final (before cleanup).mp4", {STRING_32} "C:\take\out\final.mp4", {STRING_32} "C:\take\out\thumbnail.jpg")
			assert_true ("two inputs", includes (l_args, {STRING_32} "C:\take\out\thumbnail.jpg"))
			assert_true ("dissolve", f.filter (True).has_substring ({STRING_32} "alpha=1"))
			assert_true ("loudness", f.filter (True).has_substring ({STRING_32} "loudnorm=I=-14"))
			assert_true ("fade to black", f.filter (False).has_substring ({STRING_32} "fade=t=out:st="))
			l_args := f.arguments ({STRING_32} "a.mp4", {STRING_32} "b.mp4", Void)
			assert_false ("one input", includes (l_args, {STRING_32} "-loop"))
			assert_true ("audio extract", includes (f.extract_arguments ({STRING_32} "a.mp4", {STRING_32} "a.f32"), {STRING_32} "f32le"))
		end

feature -- Suggestions and copy

	test_suggestions_from_json
		local
			s: PT_PUBLISH_SUGGESTIONS
		do
			create s.make_from_json ({STRING_32} "{%"title%": %" Not Forgotten %", %"hashtags%": [%"#Jesus%", %"Luke 17%", %"%"], %"chapters%": [%"One%", %"Two%"], %"x_line%": %"Owed nothing.%"}")
			assert_true ("title trimmed", s.title.same_string ({STRING_32} "Not Forgotten"))
			assert_integers_equal ("two hashtags kept", 2, s.hashtags.count)
			assert_true ("spaces out, # in", s.hashtags [2].same_string ({STRING_32} "#Luke17"))
			assert_integers_equal ("two chapter names", 2, s.chapter_labels.count)
			assert_true ("no description", s.description.is_empty)
			create s.make_from_json ({STRING_32} "not json")
			assert_false ("nothing from junk", s.has_any)
		end

	test_copy_without_the_ai
		local
			c: PT_PUBLISH_COPY
			p: PT_CHAPTER_PICKER
			s: PT_SCRIPT_TEXT
		do
			create s.make (script_markdown)
			create p.make
			p.pick (s, create {ARRAYED_LIST [PT_CAPTION_CUE]}.make (0), 60.0)
			create c.make (s, p, create {PT_PUBLISH_SUGGESTIONS}.make_empty, {STRING_32} "larryrix.substack.com", {STRING_32} "#Jesus #Faith #BibleStudy")
			assert_true ("title from the script", c.youtube_text.starts_with ({STRING_32} "TITLE%NWorthless Servant!%N"))
			assert_true ("chapters listed", c.youtube_text.has_substring ({STRING_32} "CHAPTERS%N0:00 "))
			assert_true ("default hashtags", c.youtube_text.has_substring ({STRING_32} "#Jesus #Faith #BibleStudy"))
			assert_true ("facebook opens with the script", c.facebook_text.has_substring ({STRING_32} "FB REEL DESCRIPTION%NWorthless servant!"))
			assert_true ("facebook link", c.facebook_text.has_substring ({STRING_32} "More at larryrix.substack.com"))
			assert_true ("x is the opening", c.x_text.starts_with ({STRING_32} "Worthless servant! The servant has done his work."))
			assert_true ("x fits", c.x_text.count <= c.Max_x + 1)
		end

feature -- Settings

	test_publish_settings_round_trip
		local
			s: PT_SETTINGS
			l_path: STRING_32
			l_ok: BOOLEAN
		do
			l_path := {STRING_32} "testing\out\publish_settings.toml"
			l_ok := (create {SIMPLE_FILE}.make (l_path)).set_content ("[prompter]%Npublish_link = %"larryrix.substack.com%"%Nuse_ollama = false%Nollama_model = %"qwen%"%N")
			create s.make_with_file (l_path)
			assert_true ("link read", s.publish_link.same_string ({STRING_32} "larryrix.substack.com"))
			assert_false ("AI off", s.uses_ollama)
			assert_true ("default hashtags", s.publish_hashtags.same_string (s.Default_hashtags))
			assert_true ("default url", s.ollama_url.same_string (s.Default_ollama_url))
			s.set_shows_tooltips (True)
			create s.make_with_file (l_path)
			assert_true ("model kept by a save", s.ollama_model.same_string ({STRING_32} "qwen"))
			assert_false ("still off", s.uses_ollama)
			l_ok := (create {SIMPLE_FILE}.make (l_path)).delete
		end

feature -- Opening line (snapper, 0.5.0)

	test_snapper_keeps_an_unmatched_opening_line
			-- Reel 4: "Worthless servant!" (2.1-3.4) went unmatched; the first matched word starts
			-- at 4.4. The first cut must start before the opening line, not after it.
		local
			l: PT_CUT_LIST
			n: PT_SILENCE_SNAPPER
			m: PT_SPEECH_MAP
		do
			create m.make (10.0)
			m.extend_span (span (2.1, 3.4))
			m.extend_span (span (4.3, 6.0))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (4.4, 5.9), <<id (1)>>, 1, 1, 1, False))
			create n.make (0.12, 0.20)
			n.snap (l, m, create {PT_WORD_TIMELINE}.make)
			assert_true ("starts before the opening line", n.last_result.cut (1).span.t0 <= 2.1)
			assert_true ("but not far before it", n.last_result.cut (1).span.t0 >= 1.9)
		end

	test_snapper_leaves_far_speech_out
			-- Speech more than a second of silence before the first matched word is not the opening.
		local
			l: PT_CUT_LIST
			n: PT_SILENCE_SNAPPER
			m: PT_SPEECH_MAP
		do
			create m.make (10.0)
			m.extend_span (span (0.5, 1.0))
			m.extend_span (span (4.3, 6.0))
			create l.make
			l.extend (create {PT_CUT}.make (0, span (4.4, 5.9), <<id (1)>>, 1, 1, 1, False))
			create n.make (0.12, 0.20)
			n.snap (l, m, create {PT_WORD_TIMELINE}.make)
			assert_true ("the stray word stays out", n.last_result.cut (1).span.t0 > 1.0)
		end

feature {NONE} -- Fixtures

	script_markdown: STRING_32
		do
			Result := {STRING_32} "# Worthless Servant!%N%N[CUE: straight into the lens]%N%NWorthless servant! The servant has done his work.%N%N[CUE: slower]%N%NNow go back to Luke chapter twelve.%N%NHe is not forgotten.%N"
		end

	chapter_script: STRING_32
		do
			Result := {STRING_32} "# T%N%NWorthless servant! That's what Jesus told you.%N%NStart with the first one.%N%NThat was every household servant's life.%N%NJohn chapter four. Jesus is tired.%N%NNow go back to Luke chapter twelve.%N"
		end

	heard_reel: ARRAYED_LIST [PT_HEARD_WORD]
			-- "Worthless servant! The servant has done the servant has done his work. Now go back to
			-- Luke chapter 12." and an invented "Thank you." in the silence after.
		do
			create Result.make (24)
			add_words (Result, <<"Worthless", "servant!">>, 1.1)
			add_words (Result, <<"The", "servant", "has", "done", "the", "servant", "has", "done", "his", "work.">>, 2.4)
			add_words (Result, <<"Now", "go", "back", "to", "Luke", "chapter", "12.">>, 5.1)
			add_words (Result, <<"Thank", "you.">>, 12.0)
		end

	speech: PT_SPEECH_MAP
		do
			create Result.make (20.0)
			Result.extend_span (span (1.0, 4.9))
			Result.extend_span (span (5.0, 9.0))
		end

	add_words (a_list: ARRAYED_LIST [PT_HEARD_WORD]; a_words: ARRAY [STRING_32]; a_from: REAL_64)
			-- `a_words' a quarter second apart from `a_from'.
		local
			l_t: REAL_64
		do
			l_t := a_from
			across a_words as ic loop
				a_list.extend (create {PT_HEARD_WORD}.make (ic, ic.as_lower, l_t, l_t + 0.2, 0.9))
				l_t := l_t + 0.25
			end
		end

	includes (a_list: LIST [STRING_32]; a_text: STRING_32): BOOLEAN
			-- Does `a_list' hold a string equal to `a_text' (`has' compares identity)?
		do
			Result := across a_list as ic some ic.same_string (a_text) end
		end

	cue (a_t0, a_t1: REAL_64; a_text: STRING_32): PT_CAPTION_CUE
		do
			create Result.make (a_t0, a_t1, a_text, create {ARRAYED_LIST [PT_WORD_ID]}.make (0))
		end

end
