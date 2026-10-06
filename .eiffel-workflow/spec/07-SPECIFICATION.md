# SPECIFICATION: simple_prompter

Date: 2026-10-05. Synthesizes 01-06 + F-01 (decided) + spikes. F-02 voice commands are deferred and not specified here.

## Overview
simple_prompter is a capture-invisible teleprompter pill that sits under the webcam and follows the
voice. It has three modes: Constant, Voice-gated (Silero VAD), and Tracking (CUDA whisper + DBC aligner).
Take Studio adds:
- continuous ffmpeg recording with marks in recording time;
- one-press retakes from any word, and live script revisions;
- a GPU analysis pass that snaps cuts into silence;
- a take solver and a minimal Edit Floor that renders the final video with captions.

Naming follows the house standard: `a_` arguments, `l_` locals, `al_` attachment locals, `ic_`/`i` loop names.

## 1. Delivery phases (class tags)

| Phase | Name | Contents (library classes unless noted) | Proof |
|-------|------|------------------------------------------|-------|
| **U-0** | Upstream | simple_text_structure extraction; simple_markdown.to_plain_text; simple_shell SHELL_PANEL/SHELL_MONITORS/SHELL_HOTKEYS; simple_speech decode params/words/VAD/stream + CUDA variant; simple_audio 16 kHz | Each library's own tests green (ec.sh test) |
| **S** | Spikes | S-1 live mic → whisper; S-2 capture-excluded SHELL_PANEL vs OBS/Teams/Snipping/Game Bar; S-3 SCOOP worker + slot at 16 ms; T-0 live dshow capture + tail latency + 30-min drift | Pasted outputs |
| **P1** | Moody on Windows | script/*, PT_CLOCK, PT_FAKE_CLOCK, PT_VOICE_FRAME, PT_FOLLOW_MODE, PT_FOLLOWER, PT_CONSTANT_FOLLOWER, PT_VOICE_GATED_FOLLOWER, PT_SPRING, PT_TEXT_MEASURE, PT_FIXED_MEASURE, PT_LINE, PT_LAYOUT, PT_SCROLL_MODEL, config/*, SIMPLE_PROMPTER (P1 features); speech: PT_AUDIO_SOURCE, PT_WASAPI_SOURCE, PT_SPEECH_WORKER (VAD only), PT_SPEECH_SLOT, PT_SPEECH_CODEC; runtime: PT_QPC_CLOCK; app: PT_APP, PT_PILL, PT_PILL_RENDERER, PT_CAIRO_MEASURE, PT_INPUT_ROUTER, PT_SETTINGS_WINDOW | Read a script on a call; invisible in share |
| **P2** | Tracking | PT_HEARD_WORD, PT_HEARD_WORDS, PT_WORD_MATCHER, PT_ALIGNMENT, PT_ALIGNER, PT_TRACKING_FOLLOWER; worker rolling whisper; prompt_text; app: PT_CALIBRATION_OVERLAY | ≤ 1 line error, 5-min read |
| **T1** | Live marking | take/* (event, journal, codec, state, action, transitions, controller, restart policy, recording clock, session folder, session); record: PT_DEVICE_CHOICE, PT_CAPTURE_PLAN, PT_PREFLIGHT, PT_RECORDER_HEALTH; speech: PT_TAIL_SOURCE; runtime: PT_RECORDER; output: PT_TIMECODE, PT_REVIEW_SRT_WRITER; app: PT_INLINE_EDITOR | Cough test in VLC with review.srt |
| **T2** | Assembly (live marks) | PT_TIME_SPAN, PT_ATTEMPT, PT_ATTEMPT_BUILDER, PT_CUT, PT_CUT_LIST, PT_TAKE_SOLVER, PT_WORD_OCCURRENCE, PT_WORD_TIMELINE (estimated from marks), PT_RENDER_PLAN, PT_CAPTION_BUILDER, PT_CHAPTER_WRITER, PT_EDL_WRITER, PT_CUT_CODEC; runtime: PT_RENDERER | First automatic final.mp4 |
| **T3** | Precision | PT_SPEECH_MAP, PT_TRANSCRIBER, PT_SCRIPTED_TRANSCRIBER, PT_ATTEMPT_ALIGNER, PT_SILENCE_SNAPPER, PT_FLAG_KIND, PT_FLAG, PT_FLAGGER, PT_ANALYSIS, PT_ANALYSIS_CODEC, PT_SESSION_ANALYZER; speech: PT_WHISPER_TRANSCRIBER; worker: PT_WORKER_APP; runtime: PT_WORKER_LAUNCHER | 10-joint listening test |
| **T4** | Edit Floor | app: PT_EDIT_FLOOR_WINDOW, PT_TAKE_CHIPS_VIEW, PT_TIMELINE_VIEW; runtime: PT_PREVIEW_PLAYER | Larry edits a real episode |

Live script edits (`PT_SCRIPT_HISTORY.apply_edit`, `PT_TAKE_CONTROLLER.commit_edit`) land in **T1** with
the controller. Stale-take rules land in T2 with the solver.

## 2. Class Specifications (full skeletons for the contract-critical core)

### 2.1 PT_WORD_ID

```eiffel
note
	description: "Stable identity of a script word across revisions. 0 = no word."
	author: "Larry Rix"

expanded class
	PT_WORD_ID

inherit
	ANY
		redefine
			default_create
		end

create
	default_create, make

feature {NONE} -- Initialization

	default_create
			-- The "no word" id.
		do
			value := 0
		ensure then
			none: value = 0
		end

	make (a_value: INTEGER_64)
			-- Identity `a_value'.
		require
			positive: a_value > 0
		do
			value := a_value
		ensure
			set: value = a_value
		end

feature -- Access

	value: INTEGER_64
			-- Raw identity.

	is_none: BOOLEAN
			-- Is this the "no word" id?
		do
			Result := value = 0
		end

invariant
	non_negative: value >= 0

end
```

### 2.2 PT_WORD

```eiffel
note
	description: "One readable token of a script revision, with stable identity."
	author: "Larry Rix"

class
	PT_WORD

create
	make

feature {NONE} -- Initialization

	make (a_id: PT_WORD_ID; a_text, a_normalized: READABLE_STRING_32;
			a_char_start, a_char_end, a_passage, a_paragraph, a_section: INTEGER;
			a_is_stop, a_is_cue: BOOLEAN)
			-- Create word `a_text' with identity `a_id'.
		require
			real_id: not a_id.is_none
			text_present: not a_text.is_empty
			span_ordered: a_char_start >= 1 and a_char_start <= a_char_end
			structure_positive: a_passage >= 1 and a_paragraph >= 1 and a_section >= 0
			normalized_shorter: a_normalized.count <= a_text.count
		do
			id := a_id
			create text.make_from_string (a_text)
			create normalized.make_from_string (a_normalized)
			char_start := a_char_start
			char_end := a_char_end
			passage_index := a_passage
			paragraph_index := a_paragraph
			section_index := a_section
			is_stop_word := a_is_stop
			is_cue := a_is_cue
		ensure
			id_set: id ~ a_id
			text_set: text.same_string (a_text)
			normalized_set: normalized.same_string (a_normalized)
			span_set: char_start = a_char_start and char_end = a_char_end
			cue_set: is_cue = a_is_cue
		end

feature -- Access

	id: PT_WORD_ID
	text: STRING_32
	normalized: STRING_32
	char_start, char_end: INTEGER
	passage_index, paragraph_index, section_index: INTEGER
	is_stop_word: BOOLEAN
	is_cue: BOOLEAN

invariant
	real_id: not id.is_none
	text_present: not text.is_empty
	span_ordered: char_start <= char_end
	normalized_not_longer: normalized.count <= text.count

end
```

### 2.3 PT_SCRIPT_REVISION (signatures + contracts)

```eiffel
class PT_SCRIPT_REVISION
create {PT_SCRIPT_PARSER, PT_SCRIPT_HISTORY} make
feature -- Access
	number: INTEGER
	title: STRING_32
	source_text: STRING_32
	word_count: INTEGER
	passage_count: INTEGER
	section_count: INTEGER
	word (a_index: INTEGER): PT_WORD                         -- 05 contracts
	passage (a_index: INTEGER): PT_PASSAGE
	section (a_index: INTEGER): PT_SECTION
	index_of (a_id: PT_WORD_ID): INTEGER                     -- O(1) via id→index table
	passage_of (a_index: INTEGER): INTEGER
	text_of_range (a_first, a_last: INTEGER): STRING_32      -- for inline editor and prompt text
feature -- Model
	ids_model: MML_SEQUENCE [PT_WORD_ID]
	spoken_ids_model: MML_SEQUENCE [PT_WORD_ID]
	passage_bounds_model: MML_SEQUENCE [INTEGER]
feature {NONE} -- Implementation
	word_list: ARRAYED_LIST [PT_WORD]
	passage_list: ARRAYED_LIST [PT_PASSAGE]
	section_list: ARRAYED_LIST [PT_SECTION]
	index_by_id: HASH_TABLE [INTEGER, INTEGER_64]
invariant
	number_positive: number >= 1
	passages_fit: passage_count <= word_count
	sections_fit: section_count <= passage_count
	empty_consistent: word_count = 0 implies passage_count = 0
	counts_match_storage: word_count = word_list.count and passage_count = passage_list.count
end
```

### 2.4 PT_SCRIPT_HISTORY (signatures; contracts in 05)

```eiffel
class PT_SCRIPT_HISTORY
create make
feature
	start (a_first: PT_SCRIPT_REVISION)
	apply_edit (a_first, a_last: INTEGER; a_new_text: READABLE_STRING_GENERAL)
		-- Algorithm (03 A-108): tokenize a_new_text with the same parser settings; LCS on normalized
		-- forms between old words a_first..a_last and new words; matched words keep ids; others get
		-- fresh ids from `ids'; words outside the range copied with ids; passages/sections re-derived
		-- from the full new text (char spans recomputed).
	revision_count: INTEGER
	current_revision: PT_SCRIPT_REVISION
	revision (a_number: INTEGER): PT_SCRIPT_REVISION
	revisions_model: MML_SEQUENCE [PT_SCRIPT_REVISION]
	ids: PT_ID_SOURCE
end
```

### 2.5 Constant holders

```eiffel
class PT_TAKE_STATE
feature -- Constants
	Idle: INTEGER = 1
	Count_in: INTEGER = 2
	Reading: INTEGER = 3
	Held: INTEGER = 4
	Editing: INTEGER = 5
	Analyzing: INTEGER = 6
	Wrapped: INTEGER = 7
end

class PT_ACTION
feature -- Constants
	Play: INTEGER = 1               -- practice: count-in without recording, no journal
	Record: INTEGER = 2
	Again: INTEGER = 3
	Hold: INTEGER = 4
	Go: INTEGER = 5
	Back: INTEGER = 6
	Forward: INTEGER = 7
	Back_paragraph: INTEGER = 8
	Forward_paragraph: INTEGER = 9
	Pick_word: INTEGER = 10         -- via pick_word (needs index)
	Edit_open: INTEGER = 11
	Edit_commit: INTEGER = 12       -- via commit_edit (needs text)
	Edit_cancel: INTEGER = 13
	Star: INTEGER = 14
	Reject: INTEGER = 15
	Note: INTEGER = 16              -- via note (optional text)
	Skip: INTEGER = 17
	Wrap: INTEGER = 18              -- recording: stop + analyze
	Stop: INTEGER = 19              -- practice: back to idle
	Abort: INTEGER = 20             -- recording: stop, keep files, no analysis
	Count_in_done: INTEGER = 21
	Analysis_done: INTEGER = 22
end

class PT_EVENT_KIND
feature -- Constants
	Session_start: INTEGER = 1
	Resume: INTEGER = 2
	Hold: INTEGER = 3
	Flub: INTEGER = 4
	Rewind_to: INTEGER = 5
	Count_in: INTEGER = 6
	Edit: INTEGER = 7
	Star: INTEGER = 8
	Reject: INTEGER = 9
	Note: INTEGER = 10
	Skip: INTEGER = 11
	Align: INTEGER = 12
	Wrap: INTEGER = 13
	Abort: INTEGER = 14
end

class PT_FOLLOW_MODE
feature -- Constants
	Constant: INTEGER = 1
	Voice_gated: INTEGER = 2
	Tracking: INTEGER = 3
end
```
05's `PT_TAKE_EVENT` invariant upper bound is therefore `{PT_EVENT_KIND}.Abort` (= 14), and 05's
`PT_TAKE_CONTROLLER.perform` range is `Play .. Analysis_done`.

### 2.6 PT_TRANSITIONS (the full table: single choice)

| From \ Action | Play | Record | Again | Hold | Go | Back / Fwd / Back_par / Fwd_par / Pick_word | Edit_open | Edit_commit / Edit_cancel | Star / Reject / Note | Skip | Wrap | Stop | Abort | Count_in_done | Analysis_done |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Idle** | Count_in | Count_in | | | | | | | | | | | | | |
| **Count_in** | | | Count_in | Held | | | | | | | Analyzing ᴿ | Idle ᴾ | Wrapped ᴿ | Reading | |
| **Reading** | | | Count_in | Held | | | | | Reading ᴿ | | Analyzing ᴿ | Idle ᴾ | Wrapped ᴿ | | |
| **Held** | | | Count_in | | Count_in | Held | Editing | | Held ᴿ | Held | Analyzing ᴿ | Idle ᴾ | Wrapped ᴿ | | |
| **Editing** | | | | | | | | Held | | | | | | | |
| **Analyzing** | | | | | | | | | | | | | | | Wrapped |
| **Wrapped** | | | | | | | | | | | | | | | |

ᴿ = allowed only while recording; ᴾ = allowed only in practice (not recording). Empty = not allowed.

```eiffel
class PT_TRANSITIONS
create make
feature
	is_allowed (a_state, a_action: INTEGER; a_recording: BOOLEAN): BOOLEAN
		require
			state_known: a_state >= {PT_TAKE_STATE}.Idle and a_state <= {PT_TAKE_STATE}.Wrapped
			action_known: a_action >= {PT_ACTION}.Play and a_action <= {PT_ACTION}.Analysis_done
		ensure
			recording_only: (a_action = {PT_ACTION}.Star or a_action = {PT_ACTION}.Reject
					or a_action = {PT_ACTION}.Note or a_action = {PT_ACTION}.Wrap
					or a_action = {PT_ACTION}.Abort) and not a_recording implies not Result
			practice_only: a_action = {PT_ACTION}.Stop and a_recording implies not Result
	next_state (a_state, a_action: INTEGER): INTEGER
		require
			listed: table_entry (a_state, a_action) /= 0
		ensure
			known: Result >= {PT_TAKE_STATE}.Idle and Result <= {PT_TAKE_STATE}.Wrapped
feature {NONE}
	table: ARRAY2 [INTEGER]        -- 7 × 22; 0 = not allowed; filled once in make from the table above
invariant
	sized: table.height = 7 and table.width = 22
end
```

### 2.7 PT_TAKE_EVENT (excerpt)

```eiffel
note
	description: "Immutable Take Studio journal entry stamped in recording time."
	author: "Larry Rix"

class
	PT_TAKE_EVENT

create
	make_session_start, make_resume, make_hold, make_flub, make_rewind_to, make_count_in,
	make_edit, make_star, make_reject, make_note, make_skip, make_align, make_wrap, make_abort

feature {NONE} -- Initialization

	make_flub (a_rt: REAL_64; a_word: PT_WORD_ID; a_by: READABLE_STRING_8)
			-- Reader flubbed at `a_word'.
		require
			rt_ok: a_rt >= 0
			source_named: not a_by.is_empty
		do
			kind := {PT_EVENT_KIND}.Flub
			rt := a_rt
			word := a_word
			create by.make_from_string (a_by)
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Flub
			rt_set: rt = a_rt
			word_set: word ~ a_word
		end

	make_resume (a_rt: REAL_64; a_caret: PT_WORD_ID; a_revision: INTEGER)
			-- Reading resumes at `a_caret' under revision `a_revision'.
		require
			rt_ok: a_rt >= 0
			real_caret: not a_caret.is_none
			revision_ok: a_revision >= 1
		do
			kind := {PT_EVENT_KIND}.Resume
			rt := a_rt
			caret := a_caret
			to_rev := a_revision
			create by.make_empty
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Resume
			caret_set: caret ~ a_caret
			revision_set: to_rev = a_revision
		end

	make_edit (a_rt: REAL_64; a_from_rev: INTEGER; a_first, a_last: PT_WORD_ID;
			a_old, a_new: READABLE_STRING_GENERAL; a_new_ids: ITERABLE [PT_WORD_ID])
			-- Script edit creating revision `a_from_rev' + 1.
		require
			rt_ok: a_rt >= 0
			revision_ok: a_from_rev >= 1
		do
			-- (body in Phase 4)
		ensure
			kind_set: kind = {PT_EVENT_KIND}.Edit
			next_revision: to_rev = a_from_rev + 1
			texts_kept: attached old_text as al_o and then al_o.same_string_general (a_old)
		end

	-- make_session_start, make_hold, make_rewind_to, make_count_in, make_star, make_reject,
	-- make_note, make_skip, make_align, make_wrap, make_abort: same shape, one per kind.

feature -- Access

	kind: INTEGER
	rt: REAL_64
	word: PT_WORD_ID
	caret: PT_WORD_ID
	from_rev, to_rev: INTEGER
	range_first, range_last: PT_WORD_ID
	old_text, new_text: detachable STRING_32
	new_ids: detachable ARRAYED_LIST [PT_WORD_ID]
	text: detachable STRING_32           -- note text, mode name, abort reason
	by: STRING_8                         -- "hotkey", "mouse", "clicker", "system"
	confidence: REAL_64                  -- align events

invariant
	kind_known: kind >= {PT_EVENT_KIND}.Session_start and kind <= {PT_EVENT_KIND}.Abort
	rt_non_negative: rt >= 0
	edit_complete: kind = {PT_EVENT_KIND}.Edit implies
			(attached old_text and attached new_text and to_rev = from_rev + 1)
	resume_has_caret: kind = {PT_EVENT_KIND}.Resume implies not caret.is_none
	confidence_range: confidence >= 0.0 and confidence <= 1.0

end
```

### 2.8 PT_JOURNAL

```eiffel
note
	description: "Append-only, rt-ordered Take Studio event log; one flushed JSONL line per event."
	author: "Larry Rix"

class
	PT_JOURNAL

create
	make_in_memory, make_on_file

feature {NONE} -- Initialization

	make_in_memory
			-- Journal without persistence (practice log off, tests).
		do
			create event_list.make (64)
			create codec.make
		ensure
			empty: count = 0
			memory_only: not is_persistent
		end

	make_on_file (a_path: READABLE_STRING_GENERAL)
			-- Journal appending to `a_path' (created if absent).
		require
			path_present: not a_path.is_empty
		do
			make_in_memory
			create path.make_from_string_general (a_path)
		ensure
			empty: count = 0
			persistent: is_persistent
		end

feature -- Access

	count: INTEGER
		do Result := event_list.count end

	event (a_index: INTEGER): PT_TAKE_EVENT
		require
			valid_index: a_index >= 1 and a_index <= count
		do
			Result := event_list [a_index]
		end

	last_event: PT_TAKE_EVENT
		require
			not_empty: count > 0
		do
			Result := event_list.last
		end

	last_rt: REAL_64
	lines_written: INTEGER
	skipped_lines: INTEGER
	is_open: BOOLEAN = True
	is_persistent: BOOLEAN
		do Result := attached path end

	count_of (a_kind: INTEGER): INTEGER
			-- Number of events of `a_kind'.
		require
			kind_known: a_kind >= {PT_EVENT_KIND}.Session_start and a_kind <= {PT_EVENT_KIND}.Abort

feature -- Model

	events_model: MML_SEQUENCE [PT_TAKE_EVENT]
			-- Mathematical model of the event sequence.
		do
			create Result
			across event_list as ic loop
				Result := Result & ic
			end
		end

feature -- Element change

	append (a_event: PT_TAKE_EVENT)
			-- Append and (if persistent) write + flush one JSONL line.
		require
			rt_ordered: a_event.rt >= last_rt
			open: is_open
		do
			event_list.extend (a_event)
			last_rt := a_event.rt
			-- persist: codec.encode (a_event); append line + flush (simple_file)
			lines_written := lines_written + 1
		ensure
			appended: (events_model |=| (old events_model & a_event))
			last_updated: last_rt = a_event.rt
			persisted: lines_written = old lines_written + 1
		end

	replay_from (a_lines: ITERABLE [READABLE_STRING_8])
			-- Rebuild from JSONL lines; a torn final line (crash) is skipped and counted.
		require
			empty: count = 0

feature {NONE} -- Implementation

	event_list: ARRAYED_LIST [PT_TAKE_EVENT]
	codec: PT_JOURNAL_CODEC
	path: detachable PATH

invariant
	last_rt_non_negative: last_rt >= 0
	empty_zero: count = 0 implies last_rt = 0
	writes_bounded: lines_written <= count

end
```

### 2.9 PT_FOLLOWER (deferred root)

```eiffel
note
	description: "Follow policy: turns voice frames and alignments into scroll target and velocity."
	author: "Larry Rix"

deferred class
	PT_FOLLOWER

feature -- Access

	target: REAL_64
			-- Display position in words (fractional).

	velocity: REAL_64
			-- Words per second.

	word_count: INTEGER
	is_held: BOOLEAN
	caret_changed: BOOLEAN
			-- Did the last command move the target by caret (the only backward path)?

	is_speaking: BOOLEAN
			-- Last voice frame said speech.

feature -- Input

	on_voice (a_frame: PT_VOICE_FRAME)
		deferred
		ensure
			position_untouched: target = old target
		end

	on_alignment (a_alignment: PT_ALIGNMENT)
		deferred
		ensure
			position_untouched: target = old target
		end

feature -- Motion

	advance (a_dt_s: REAL_64)
		require
			non_negative: a_dt_s >= 0
		deferred
		ensure
			held_frozen: is_held implies target = old target
			never_backward: target >= old target
			end_clamped: target <= word_count
			velocity_non_negative: velocity >= 0
		end

feature -- Control

	hold
		do
			is_held := True
			velocity := 0
			caret_changed := False
		ensure
			held: is_held
			stopped: velocity = 0
			target_kept: target = old target
		end

	release
		do
			is_held := False
		ensure
			running: not is_held
		end

	set_caret (a_index: INTEGER)
		require
			valid: a_index >= 0 and a_index <= word_count
		do
			target := a_index
			caret_changed := True
		ensure
			placed: target = a_index.to_double
			flagged: caret_changed
		end

invariant
	velocity_non_negative: velocity >= 0
	held_still: is_held implies velocity = 0
	target_range: target >= 0 and target <= word_count

end
```

### 2.10 PT_CONSTANT_FOLLOWER

```eiffel
class
	PT_CONSTANT_FOLLOWER

inherit
	PT_FOLLOWER

create
	make

feature {NONE} -- Initialization

	make (a_word_count: INTEGER; a_wpm: INTEGER)
		require
			words_non_negative: a_word_count >= 0
			wpm_range: a_wpm >= Min_wpm and a_wpm <= Max_wpm
		do
			word_count := a_word_count
			words_per_second := a_wpm / 60.0
			is_held := True
		ensure
			at_start: target = 0
			held_initially: is_held
		end

feature -- Access

	words_per_second: REAL_64
	Min_wpm: INTEGER = 40
	Max_wpm: INTEGER = 400

feature -- Input

	on_voice (a_frame: PT_VOICE_FRAME)
		do
			is_speaking := a_frame.is_speech
		end

	on_alignment (a_alignment: PT_ALIGNMENT)
		do
		end

feature -- Motion

	advance (a_dt_s: REAL_64)
		do
			caret_changed := False
			if is_held then
				velocity := 0
			else
				velocity := words_per_second
				target := (target + words_per_second * a_dt_s).min (word_count)
			end
		ensure then
			constant_rate: (not is_held and old target + words_per_second * a_dt_s <= word_count)
					implies (target - (old target + words_per_second * a_dt_s)).abs < 1.0e-9
		end

invariant
	rate_positive: words_per_second > 0

end
```

### 2.11 PT_ALIGNER, PT_TRACKING_FOLLOWER, PT_VOICE_GATED_FOLLOWER (signatures)

```eiffel
class PT_ALIGNER
create make
feature
	revision: PT_SCRIPT_REVISION
	position: INTEGER
	confidence: REAL_64
	last_alignment: PT_ALIGNMENT
	update (a_heard: PT_HEARD_WORDS)            -- contracts 05
	reanchor (a_index: INTEGER)
	required_anchors (a_jump: INTEGER): INTEGER
	Window_back: INTEGER = 3
	Window_ahead: INTEGER = 40
	Recent_heard: INTEGER = 6
	Small_jump: INTEGER = 4
	Backward_evidence: INTEGER = 3
end

class PT_VOICE_GATED_FOLLOWER inherit PT_FOLLOWER
	-- velocity ramps to words_per_second over Ramp_up_s (0.15) when speech starts,
	-- to 0 over Ramp_down_s (0.20) when it stops (NFR-001 ≤ 250 ms). The idea is
	-- SR_GOVERNOR's brake glide (sr_governor.e:216-266), applied to the speech gate.
	Ramp_up_s: REAL_64 = 0.15
	Ramp_down_s: REAL_64 = 0.20
end

class PT_TRACKING_FOLLOWER inherit PT_FOLLOWER
	-- While speaking: velocity = measured_rate (from alignments) + spring term toward the aligned word
	-- (never negative); coast at measured_rate ≤ Coast_limit (1.5 s) after the last anchor, then hold.
	-- Before the first alignment: behaves like voice-gated at the configured wpm.
	measured_rate: REAL_64
	seconds_since_anchor: REAL_64
	Coast_limit: REAL_64 = 1.5
	Min_rate: REAL_64 = 1.0
	Max_rate_factor: REAL_64 = 1.6
end
```

### 2.12 PT_TAKE_CONTROLLER (signatures)

```eiffel
class PT_TAKE_CONTROLLER
create make (a_history: PT_SCRIPT_HISTORY; a_journal: PT_JOURNAL; a_clock: PT_RECORDING_CLOCK;
             a_follower: PT_FOLLOWER; a_policy: PT_RESTART_POLICY)
feature -- Status
	state: INTEGER
	is_recording: BOOLEAN
	caret: INTEGER
	revision: PT_SCRIPT_REVISION        -- = history.current_revision
	is_allowed (a_action: INTEGER): BOOLEAN   -- transitions.is_allowed (state, a_action, is_recording)
	again_target: INTEGER
	follower_caret: INTEGER
	needs_argument (a_action: INTEGER): BOOLEAN   -- Pick_word, Edit_commit, Note
feature -- Commands
	perform (a_action: INTEGER)         -- require not needs_argument (a_action); contracts 05
	pick_word (a_index: INTEGER)
	commit_edit (a_new_text: READABLE_STRING_GENERAL)
	note (a_text: READABLE_STRING_GENERAL)
	sample_alignment (a_alignment: PT_ALIGNMENT)   -- journals Align events ≤ 4/s while recording
feature {NONE}
	transitions: PT_TRANSITIONS
	edit_first, edit_last: INTEGER
end
```
**Event mapping (single choice, inside `perform`):**

| Action | Events appended (recording only) | Follower effect |
|---|---|---|
| Record | session_start, count_in | set_caret (1), hold |
| Again | flub (word at follower position), rewind_to (again_target), count_in | hold; set_caret (again_target) |
| Hold | hold | hold |
| Go | count_in | set_caret (caret) |
| Count_in_done | resume (caret, revision) | release; aligner.reanchor (caret) |
| Back/Forward/… | none | none (caret only) |
| Edit_open | none | none |
| commit_edit | edit | set_caret (passage start) |
| Star/Reject/Note/Skip | star/reject/note/skip(edit) | none |
| Wrap | wrap | hold |
| Abort | abort | hold |

### 2.13 PT_CUT_LIST, PT_TAKE_SOLVER (signatures)

```eiffel
class PT_CUT
create make (a_src: INTEGER; a_span: PT_TIME_SPAN; a_first, a_last: PT_WORD_ID;
             a_first_index, a_last_index, a_attempt: INTEGER; a_tight: BOOLEAN)
invariant
	src_ok: src >= 0
	words_ordered: first_word_index <= last_word_index
	attempt_ok: attempt >= 1
end

class PT_CUT_LIST
create make
feature
	count: INTEGER
	cut (a_index: INTEGER): PT_CUT
	extend (a_cut: PT_CUT)              -- require output order (first_word_index > last cut's last_word_index)
	output_duration: REAL_64
	is_kept (a_src: INTEGER; a_rt: REAL_64): BOOLEAN
	to_output_time (a_src: INTEGER; a_rt: REAL_64): REAL_64
	floor_spans (a_src: INTEGER; a_raw_duration: REAL_64): ARRAYED_LIST [PT_TIME_SPAN]
	cuts_model: MML_SEQUENCE [PT_CUT]
	words_model: MML_SEQUENCE [PT_WORD_ID]     -- needs the revision to expand ranges: built by solver into cut.word_ids
end

class PT_TAKE_SOLVER
create make (a_splice_cost, a_age_penalty, a_min_confidence: REAL_64)
feature
	solve (a_final: PT_SCRIPT_REVISION; a_attempts: LIST [PT_ATTEMPT];
	       a_timeline: PT_WORD_TIMELINE; a_map: PT_SPEECH_MAP)      -- command; sets last_result (06 §4)
	last_result: detachable PT_CUT_LIST
	is_complete: BOOLEAN
	missing_words: ARRAYED_LIST [PT_WORD_ID]
	decisions: ARRAYED_LIST [STRING_32]           -- FR-NEW-006 decision log lines
end
```
Each `PT_CUT` carries its `word_ids: ARRAYED_LIST [PT_WORD_ID]` so `words_model` needs no revision.

### 2.14 PT_KEYMAP defaults (D-T06, F-01 §4.3, minus long-press per 03 A-102)

| Action | Default binding | Bare while recording (clicker) |
|---|---|---|
| Hold / Go (toggle) | Ctrl+Alt+Space | B, "." |
| Again | Ctrl+Alt+Backspace | PageUp (in READING) |
| Back / Forward (HELD) | Left / Right (pill focused); Ctrl+Alt+Left/Right | PageUp / PageDown (in HELD) |
| Go (HELD) | Enter (pill focused) | PageDown |
| Edit | Ctrl+Alt+E | |
| Star / Reject / Note | Ctrl+Alt+S / X / N | |
| Wrap | Ctrl+Alt+End | |
| Play / Stop (practice) | Ctrl+Alt+P | |
| Hide pill | Ctrl+Alt+H | |
| Click-through toggle | Ctrl+Alt+I | |

## 3. Dependencies

| Library | Purpose | Version (ECF) |
|---------|---------|---------------|
| base, time | Kernel | ISE 25.02 |
| testing | EQA (tests only) | ISE 25.02 |
| simple_testing | TEST_SET_BASE | 1.0 |
| simple_mml | Models | 1.0 |
| simple_text_structure | Tokens/navigation | NEW 0.1 (U-0) |
| simple_markdown | to_plain_text | 1.0 + U-0 delta |
| simple_json | Journal, cut.json, analysis | 1.0.0 |
| simple_toml | Settings | 0.1.2 |
| simple_file, simple_encoding | Files, UTF-8 | 1.0.0 |
| simple_shell | Panel, monitors, hotkeys, fast timer, QPC | 1.10.0 + U-0 delta |
| simple_widgets, simple_cairo | Views, painting | 0.x / 1.3.0 |
| simple_speech | VAD, decode, stream (CUDA variant) | 1.1.1 + U-0 delta |
| simple_audio | Practice-mode capture | 1.0 + U-0 delta |
| simple_process | ffmpeg/ffplay/worker children | current (+ write_input SHOULD) |
| simple_ffmpeg | dshow listing | 1.0 + U-0 delta |
| ffmpeg/ffplay 8.0 (external exe), whisper.cpp 1.8.2 CUDA DLLs (vendored) | Capture, render, preview, inference | measured 2026-10-05 |

## 4. File Structure

```
simple_prompter/
├── simple_prompter.ecf          (library + prompter + prompter_worker + simple_prompter_tests targets)
├── src/
│   ├── simple_prompter.e
│   ├── script/   pt_word_id.e pt_word.e pt_passage.e pt_section.e pt_script_revision.e pt_script_edit.e
│   │             pt_script_history.e pt_script_parser.e pt_id_source.e pt_stop_words.e pt_normalizer.e
│   ├── follow/   pt_clock.e pt_fake_clock.e pt_voice_frame.e pt_heard_word.e pt_heard_words.e pt_word_matcher.e
│   │             pt_alignment.e pt_aligner.e pt_spring.e pt_follow_mode.e pt_follower.e pt_constant_follower.e
│   │             pt_voice_gated_follower.e pt_tracking_follower.e pt_text_measure.e pt_fixed_measure.e
│   │             pt_line.e pt_layout.e pt_scroll_model.e
│   ├── take/     pt_event_kind.e pt_take_event.e pt_journal.e pt_journal_codec.e pt_take_state.e pt_action.e
│   │             pt_transitions.e pt_take_controller.e pt_restart_policy.e pt_recording_clock.e
│   │             pt_session_folder.e pt_session.e
│   ├── assembly/ pt_time_span.e pt_speech_map.e pt_word_occurrence.e pt_word_timeline.e pt_attempt.e
│   │             pt_attempt_builder.e pt_transcriber.e pt_scripted_transcriber.e pt_attempt_aligner.e
│   │             pt_silence_snapper.e pt_cut.e pt_cut_list.e pt_take_solver.e pt_flag_kind.e pt_flag.e
│   │             pt_flagger.e pt_analysis.e pt_session_analyzer.e
│   ├── output/   pt_timecode.e pt_caption_builder.e pt_review_srt_writer.e pt_chapter_writer.e
│   │             pt_edl_writer.e pt_cut_codec.e pt_analysis_codec.e
│   ├── record/   pt_device_choice.e pt_capture_plan.e pt_render_plan.e pt_preflight.e pt_recorder_health.e
│   └── config/   pt_settings.e pt_camera_anchor.e pt_key_binding.e pt_keymap.e
├── speech/       pt_audio_source.e pt_wasapi_source.e pt_tail_source.e pt_speech_worker.e
│                 pt_speech_slot.e pt_speech_codec.e pt_whisper_transcriber.e
├── runtime/      pt_qpc_clock.e pt_recorder.e pt_renderer.e pt_worker_launcher.e pt_preview_player.e
├── app/          pt_app.e pt_pill.e pt_pill_renderer.e pt_cairo_measure.e pt_input_router.e
│                 pt_inline_editor.e pt_edit_floor_window.e pt_take_chips_view.e pt_timeline_view.e
│                 pt_settings_window.e pt_calibration_overlay.e
├── worker/       pt_worker_app.e
├── testing/      test_app.e lib_tests.e
│                 test_script.e test_aligner.e test_followers.e test_layout.e test_journal.e
│                 test_controller.e test_solver.e test_snapper.e test_outputs.e test_plans.e test_keymap.e
│                 fixtures/ moody_script.md synthetic journals (cough, edit, run-up, star, reject, unmarked restart, missing)
├── installer/    simple_prompter.iss  (SR template; ffmpeg/whisper DLLs isolated in subfolders)
└── .eiffel-workflow/
```

## 5. Test strategy (summary)

| Area | Fixture | Key assertions |
|------|---------|----------------|
| Script | Moody script (.md with heading), abbreviation text | ids unique; passages partition; "Dr." doesn't split |
| History | Edit "notch" → "webcam" | prefix/suffix ids kept; revision count +1 |
| Aligner | Heard sequences incl. the reel's repeated "So when you", ad-libs, skips | forward bias; no move on stop words; jump evidence |
| Followers | Fake clock; voice frames | rates; held frozen; ramps ≤ 250 ms |
| Controller | Action scripts | transition table; journal events per mapping |
| Solver | Synthetic journals (F-01 §10.3 list) | exact cover; no stale/rejected; star wins |
| Snapper | Speech map + timeline | cuts in silence or tight; words not clipped |
| Outputs | Known cut list | SRT shape/round-trip; EDL lines; filter-script counts (spike recipe) |
| Plans | Device choice | capture args include mjpeg, pcm_s16le, f32le tee, flush_packets |
| Integration (manual, pasted) | Spikes S/T-0; cough test; render frame-accuracy (burned clock, spike method) | |
