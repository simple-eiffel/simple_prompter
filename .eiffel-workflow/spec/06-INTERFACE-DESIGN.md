# INTERFACE DESIGN: simple_prompter

Date: 2026-10-05

## 1. Public API Summary: SIMPLE_PROMPTER (facade)

### Creation
| Feature | Purpose | Typical Use |
|---------|---------|-------------|
| `make` | Default settings path `%APPDATA%\simple_prompter\settings.toml` | `create p.make` |
| `make_with_settings (a_path)` | Explicit settings file (tests, portable) | `create p.make_with_settings ("t.toml")` |

### Configuration (fluent, returns `like Current`)
| Feature | Returns | Purpose |
|---------|---------|---------|
| `with_mode (a_mode)` | like Current | `{PT_FOLLOW_MODE}.Constant / Voice_gated / Tracking` |
| `with_speed_wpm (a_wpm)` | like Current | Constant/voice-gated speed (also the tracking fallback rate) |
| `with_clock (a_clock: PT_CLOCK)` | like Current | Inject QPC (app) or fake (tests) |
| `with_measure (a_measure: PT_TEXT_MEASURE; a_width: REAL_64)` | like Current | Layout metrics |

### Core Operations
| Feature | Kind | Purpose |
|---------|------|---------|
| `open_script (a_path)` | Command | Parse .txt/.md into revision 1 |
| `load_script_text (a_title, a_text)` | Command | Same from memory (paste, tests) |
| `feed_voice (a_frame)` | Command | VAD frame from the speech slot |
| `feed_heard (a_heard)` | Command | Decode result from the speech slot |
| `tick (a_now_ms)` | Command | Advance follower + scroll (GUI calls every 16 ms) |
| `start_session (a_folder)` | Command | New Take Studio session (journal opened) |
| `perform (a_action)` | Command | Take Studio action |
| `pick_word (a_index)` / `commit_edit (a_text)` | Command | Held-state operations |
| `assemble (a_analysis)` | Command | Solve + snap → `last_cuts` |
| `write_outputs` | Command | review.srt, final.srt/.vtt, chapters, EDL, cut.json, render filter script |

### Status / Access Queries
| Feature | Returns | Purpose |
|---------|---------|---------|
| `has_script` | BOOLEAN | Script loaded? |
| `history` | PT_SCRIPT_HISTORY | Revisions |
| `follower` | PT_FOLLOWER | Current policy |
| `scroll` | PT_SCROLL_MODEL | Position + y offset for rendering |
| `controller` | PT_TAKE_CONTROLLER | State, caret |
| `session` | detachable PT_SESSION | Active session |
| `last_cuts` | detachable PT_CUT_LIST | After `assemble` |
| `prompt_text` | STRING_32 | Already-read words (≤ 40) for the whisper prompt (I-003) |
| `settings` | PT_SETTINGS | Preferences |

## 2. Fluent API Example

```eiffel
create prompter.make
prompter.with_mode ({PT_FOLLOW_MODE}.Tracking)
        .with_speed_wpm (130)
        .with_clock (create {PT_QPC_CLOCK})
        .with_measure (create {PT_CAIRO_MEASURE}.make (painter, font), 520.0).do_nothing
prompter.open_script ("episode-12.md")
-- every 16 ms tick (GUI):
across speech_slot_records as ic loop
    codec.decode (ic)
    if attached codec.last_frame as al_f then prompter.feed_voice (al_f) end
    if attached codec.last_heard as al_h then prompter.feed_heard (al_h) end
end
prompter.tick (clock.now_ms)
renderer.draw (prompter.scroll.y_offset, prompter.controller.state)
```

Headless test (SR pattern: scripted clock):
```eiffel
create clock.make
create prompter.make_with_settings (temp_settings)
prompter.with_clock (clock).with_measure (create {PT_FIXED_MEASURE}.make (10.0, 20.0), 300.0).do_nothing
prompter.load_script_text ("t", "One two three. Four five six.")
prompter.with_mode ({PT_FOLLOW_MODE}.Constant).with_speed_wpm (60).do_nothing
prompter.perform ({PT_ACTION}.Play)     -- practice mode: no recording, no journal
prompter.perform ({PT_ACTION}.Count_in_done)
clock.advance (1000) ; prompter.tick (clock.now_ms)
assert_reals_equal ("one word per second", 1.0, prompter.follower.target, 1.0e-6)
```

## 3. Error Handling Pattern

No exceptions for expected failures. Each operation that can fail sets `last_error: detachable STRING_32` and
a status query:
```eiffel
prompter.open_script (path)
if prompter.has_script then … else show (prompter.last_error) end

recorder.start (plan)
if recorder.is_running then … else show (recorder.health.last_error) end
```
Value results with possible failure (`PT_ANALYSIS` from the worker mailbox) use the XOR pattern:
`is_success xor attached error`.

## 4. Command-Query Separation

| Feature | Type | Modifies State? | Returns Value? |
|---------|------|-----------------|----------------|
| `with_*` | Command (builder) | YES | like Current (chaining; house fluent exception) |
| `open_script`, `feed_*`, `tick`, `perform`, `pick_word`, `commit_edit`, `assemble`, `write_outputs` | Command | YES | NO |
| `history`, `follower`, `scroll`, `controller`, `prompt_text`, `last_cuts`, `has_script` | Query | NO | YES |
| `PT_ALIGNER.update` / `last_alignment` | Command / Query | split | |
| `PT_TAKE_SOLVER.solve` | Query-style function on value inputs | NO (pure; may cache `missing_words` as a secondary query → **split**: `solve` is a command setting `last_result`, `missing_words`) | via `last_result` |
| `PT_SPEECH_SLOT.take_all` | **Command returning value** (exception: drain must be atomic across processors; documented) | YES | YES |
| `PT_JOURNAL_CODEC.encode` / `decode` | Query / Command (`decode` sets `last_event`, `last_error`) | | |

`PT_TAKE_SOLVER` is corrected from 05's function form to command + `last_result` (CQS). The
postconditions move onto `last_result` unchanged.

## 5. Upstream interface proposals (built in their own libraries)

These are the *interfaces simple_prompter needs*. Each library's own spec kit decides internals.

### 5.1 simple_text_structure (new)
```eiffel
class SIMPLE_TEXT_STRUCTURE
    make
    load_file (a_path: READABLE_STRING_GENERAL)     -- UTF-8, BOM stripped; sets text or last_error
    load_text (a_title, a_source: READABLE_STRING_GENERAL)
    text: detachable STS_TEXT
    with_abbreviations (a_list: STS_ABBREVIATIONS): like Current
class STS_TOKEN      -- word, sentence_index, paragraph_index, section_index, source_start,
                     -- ends_sentence, ends_paragraph, has_clause_break, is_numeric, is_acronym, script
class STS_NAVIGATOR  -- sentence_start (tokens, i), paragraph_start, section_start,
                     -- previous_sentence_start, next_sentence_start, … (pure functions)
```

### 5.2 simple_markdown
```eiffel
SIMPLE_MARKDOWN.to_plain_text (a_md: READABLE_STRING_GENERAL): STRING_32
    -- Headings kept as lines starting "# " (so STS section detection still works); emphasis, links
    -- (text kept), images (alt kept), code fences (content kept), HTML comments dropped.
    ensure no_emphasis_markers: not Result.has_substring ("**")
```

### 5.3 simple_speech
```eiffel
class SPEECH_DECODE_PARAMS     -- fluent: with_no_context (b), with_prompt (s), with_greedy, with_audio_ctx (n),
                               -- with_word_timestamps (b), with_language (s), with_threads (n)
class SPEECH_WORD              -- text, t0, t1 (s), probability
SIMPLE_SPEECH.transcribe_pcm_words (a_samples: ARRAY [REAL_32]; a_params: SPEECH_DECODE_PARAMS): ARRAYED_LIST [SPEECH_WORD]
class SPEECH_VAD               -- make (model_path); speech_probabilities (samples): ARRAY [REAL_32] per 32 ms;
                               -- segments (samples, threshold, min_speech_ms, min_silence_ms, pad_ms): ARRAYED_LIST [TUPLE [t0, t1: REAL_64]]
class SPEECH_STREAM            -- rolling window: push (samples), is_ready, decode_window (params): words with absolute t
-- ECF: library target simple_speech (CPU, unchanged) + simple_speech_cuda variant linking ggml-cuda.lib
-- All whisper externals called from SCOOP workers are "C blocking inline".
```
Evidence that the decode params matter: spike gotchas 1-2 (no_context, prompt semantics).

### 5.4 simple_audio
```eiffel
AUDIO_RECORDER.set_format (16_000, 1, 32)      -- float; uses AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | SRC_DEFAULT_QUALITY
AUDIO_RECORDER.read_into (a_buffer: MANAGED_POINTER): INTEGER   -- non-accumulating pull; frames returned
-- fixes: full-packet release; g_enumerator __declspec(selectany)
```

### 5.5 simple_shell
```eiffel
class SHELL_PANEL              -- one or more per process
    make (a_w, a_h)            -- WS_POPUP, WS_EX_TOPMOST|WS_EX_TOOLWINDOW|WS_EX_NOACTIVATE
    show_at (x, y); hide; move_to (x, y); resize (w, h)
    set_corner_radius (px)     -- SetWindowRgn rounded region (Win11: DWMWA_WINDOW_CORNER_PREFERENCE if available)
    set_capture_excluded (b)   -- SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE), fallback WDA_MONITOR
    is_capture_excluded: BOOLEAN; last_affinity_error: INTEGER
    set_opacity (0..255)       -- SetLayeredWindowAttributes (LWA_ALPHA) — affinity-compatible
    set_click_through (b)      -- WS_EX_TRANSPARENT
    enable_focus / disable_focus  -- toggle NOACTIVATE for HELD/EDITING keyboard entry
    dc / request_paint; mouse and key events like SHELL_WINDOW
class SHELL_MONITORS           -- count, bounds (i), work_area (i), dpi (i), device_name (i), monitor_at (x, y)
                               -- process set to per-monitor-v2 DPI awareness
class SHELL_HOTKEYS            -- register (id, modifiers, vkey): BOOLEAN  (require modifiers /= 0 unless allow_bare)
                               -- allow_bare (b); unregister (id); unregister_all; taken_presses: LIST [INTEGER]
                               -- generalized from OCR_HOTKEY (ocr_hotkey.e:57; single fixed id 0xB001 today)
```

### 5.6 simple_ffmpeg
```eiffel
SIMPLE_FFMPEG.dshow_devices: ARRAYED_LIST [TUPLE [name: STRING_32; is_video: BOOLEAN]]
SIMPLE_FFMPEG.dshow_video_modes (a_name): ARRAYED_LIST [TUPLE [codec: STRING_8; w, h: INTEGER; max_fps: REAL_64]]
```
(Parses `-list_devices true -f dshow -i dummy` / `-list_options true`, as run in the spike.)

### 5.7 simple_process (SHOULD)
```eiffel
SIMPLE_ASYNC_PROCESS.write_input (a_bytes: READABLE_STRING_8): BOOLEAN    -- stdin pipe; e.g. "q" to ffmpeg
```

## 6. App-facing view contracts (summary)

| View | Reads | Never does |
|------|-------|-----------|
| `PT_PILL_RENDERER` | `scroll.y_offset`, layout lines, controller state/caret, last voice level | mutate model; block |
| `PT_INPUT_ROUTER` | keymap, controller `is_allowed` | call `perform` without checking `is_allowed` (precondition) |
| `PT_EDIT_FLOOR_WINDOW` | session, analysis, cuts | modify raw or journal (NFR-T05) |
| `PT_APP` | slot (drain), clock | wait on the speech worker (SCOOP query) |
