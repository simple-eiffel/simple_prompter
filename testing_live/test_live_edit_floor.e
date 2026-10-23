note
	description: "[
		The Last take panel is painted on two surfaces: its callout beside the pill, and the
		control window (hidden in pill mode, but still repainted when its status changes).
		A click on one surface must be tested against the buttons painted on that surface,
		not against whichever surface painted last. In 0.7.1 Publish took about seven clicks
		(Larry, 2026-10-12): between the callout's paint and the click, the control window
		repainted the panel 540 points to the right, so the click missed every button.
		Here because PT_EDIT_FLOOR lives in the app cluster, which the headless tests lack.
	]"
	author: "Larry Rix"

class
	TEST_LIVE_EDIT_FLOOR

inherit
	TEST_SET_BASE

feature -- Clicks

	test_click_hits_the_surface_it_was_painted_on
		local
			l_floor: PT_EDIT_FLOOR
			l_painter: SW_PAINTER
			l_surface: CAIRO_SURFACE
			l_context: CAIRO_CONTEXT
			l_rows: ARRAYED_LIST [TUPLE [x, y, w, h: REAL_64; action, index: INTEGER]]
			l_publish: detachable TUPLE [x, y, w, h: REAL_64; action, index: INTEGER]
			l_published: CELL [BOOLEAN]
			k: REAL_64
		do
			k := 1.5
			create l_floor.make ({STRING_32} "ffmpeg.exe")
			l_floor.show (take_with_final, 0)
			create l_published.put (False)
			l_floor.set_on_publish (agent l_published.put (True))
			create l_surface.make (1600, 900)
			create l_context.make (l_surface)
			create l_painter.make (l_context, create {SW_THEME}.make_light)
				-- The callout paints (as `paint_take_callout' does), then the control window
				-- paints (as `paint_status' does), then the click lands on the callout.
			l_floor.paint (l_painter, 16 * k, 0, 500 * k, k)
			l_rows := l_floor.clickables.twin
			l_floor.paint (l_painter, 540 * k, 0, 480 * k, k)
			across l_rows as ic loop
				if l_floor.row_tip (ic.action, ic.index).starts_with ({STRING_32} "Publish") then
					l_publish := ic
				end
			end
			assert ("Publish painted on the callout", attached l_publish)
			if attached l_publish as al_button then
				l_floor.press_on (l_rows, al_button.x + al_button.w / 2, al_button.y + al_button.h / 2)
			end
			assert ("one click on the callout's Publish publishes", l_published.item)
		end

feature {NONE} -- Fixtures

	take_with_final: STRING_32
			-- A recorded, analyzed take whose out folder holds a final.mp4, so Publish may run.
		local
			p: SIMPLE_PROMPTER
			l_folder: PT_SESSION_FOLDER
			l_analysis: PT_ANALYSIS
			l_ok: BOOLEAN
		do
			if attached (create {EXECUTION_ENVIRONMENT}).temporary_directory_path as al_temp then
				Result := al_temp.extended ("simple_prompter_floor_test").name
			else
				Result := {STRING_32} "simple_prompter_floor_test"
			end
			l_ok := (create {SIMPLE_FILE}.make (Result + {STRING_32} "\journal.jsonl")).delete
			create p.make_with_settings (create {PT_SETTINGS}.make_in_memory)
			p.load_script_text ({STRING_32} "Episode", {STRING_32} "One two three. Four five six.")
			create l_folder.make (Result)
			p.start_session (l_folder)
			p.perform ({PT_ACTION}.Record)
			p.perform ({PT_ACTION}.Count_in_done)
			p.perform ({PT_ACTION}.Wrap)
			p.perform ({PT_ACTION}.Analysis_done)
			p.end_session
			create l_analysis.make (create {PT_SPEECH_MAP}.make (10.0), create {PT_WORD_TIMELINE}.make,
				create {ARRAYED_LIST [PT_ATTEMPT]}.make (0), create {PT_CUT_LIST}.make,
				create {ARRAYED_LIST [PT_FLAG]}.make (0), create {ARRAYED_LIST [STRING_32]}.make (0))
			l_ok := (create {SIMPLE_FILE}.make (l_folder.analysis_dir + {STRING_32} "\analysis.json")).set_content (
				(create {PT_ANALYSIS_CODEC}.make).encode (l_analysis))
			l_ok := (create {SIMPLE_FILE}.make (l_folder.out_dir + {STRING_32} "\final.mp4")).set_content ("stand-in")
		end

end
