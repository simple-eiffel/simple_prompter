# CLASS DESIGN: simple_prompter

Date: 2026-10-05. Prefix `PT_` (verified free). Facade `SIMPLE_PROMPTER`.
New upstream library `simple_text_structure`, prefix `STS_` (verified free; `TS_` is Gobo's test lib).

## 0. Layering

```
┌──────────────────────────────── targets ────────────────────────────────┐
│ prompter (GUI app)     prompter_worker (console)    simple_prompter_tests│
│  app/ cluster           worker/ cluster              testing/ cluster    │
│  speech/ cluster        speech/ cluster                                  │
│  runtime/ cluster                                                        │
└──────────────┬───────────────────────┬──────────────────────┬───────────┘
               └──────────── all extend library target ───────┘
┌──────────── library target simple_prompter (PURE: no GUI, no whisper, no processes) ───────────┐
│ src/script  src/follow  src/take  src/assembly  src/output  src/record  src/config  facade      │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
   depends on: base, time, simple_text_structure, simple_markdown, simple_json, simple_toml,
               simple_file, simple_encoding, simple_mml
```

**Why pure:**
- The test target links only the pure core. Import-linked whisper/ggml DLLs would otherwise be needed
  just to *start* the test exe.
- Aligner, follower, controller, solver and writers are the risky logic, and all of them are testable with fakes:
  - `PT_FAKE_CLOCK`;
  - `PT_FIXED_MEASURE`;
  - a scripted `PT_TRANSCRIBER`.
- Effects (audio, whisper, ffmpeg, windows) live behind deferred classes declared in the library
  (`PT_CLOCK`, `PT_TEXT_MEASURE`, `PT_TRANSCRIBER`) and implemented in app/worker clusters.

Every target declares its own `<option><assertions …/>` (C-010).

## 1. Class Inventory

### 1.1 Upstream: simple_text_structure (NEW library, extracted from simple_speed_reader)
| Class | Role | Single Responsibility | Origin |
|-------|------|----------------------|--------|
| `SIMPLE_TEXT_STRUCTURE` | Facade | Load UTF-8 file / text → `STS_TEXT` | SR `load_file`/`load_text` (simple_speed_reader.e:61-140) |
| `STS_TOKEN` | Data (immutable) | Word + sentence/paragraph/section index + `source_start` + break flags + classification | `SR_TOKEN` minus pivot (sr_token.e) |
| `STS_TOKENIZER` | Engine | Whitespace split, sentence/clause/paragraph/section marking, **+ abbreviation awareness** | `SR_TOKENIZER` (sr_tokenizer.e:35-172) |
| `STS_ABBREVIATIONS` | Policy | Known abbreviations that don't end sentences ("Dr.", "e.g.", "U.S."…) | NEW (FR-NEW-007) |
| `STS_TEXT` | Data | Title + tokens + section count | `SR_TEXT` |
| `STS_NAVIGATOR` | Queries | `sentence_start`, `paragraph_start`, `section_start`, next/previous of each (pure functions over tokens) | `SR_SESSION` navigation (sr_session.e:113,221,266,277,464) |
| `STS_UTF8_READER` | Utility | Read a UTF-8 file to STRING_32, strip BOM (until simple_file is fixed, A-112) | SR byte path (simple_speed_reader.e:93-140) |

simple_speed_reader migrates onto this later; not a blocker for simple_prompter.

### 1.2 Upstream deltas (interfaces specified in 06 §5; built in their libraries)
| Library | Addition | For |
|---------|----------|-----|
| simple_markdown | `to_plain_text (md): STRING_32` keeping heading lines as `# text`, dropping emphasis/links/code fences markup | Script loading (A-103) |
| simple_speech | `SPEECH_DECODE_PARAMS` (no_context, prompt, greedy, audio_ctx, token timestamps); `SPEECH_WORD` results; `SPEECH_VAD` (whisper_vad_*); `SPEECH_STREAM` rolling window; CUDA lib set (ggml-cuda) as an alternate ECF target | Live follow + analysis |
| simple_audio | AUTOCONVERTPCM 16 kHz mono capture, packet-release fix, `selectany` enumerator | Practice-mode capture |
| simple_shell | `SHELL_PANEL` (topmost/toolwindow/noactivate popup, rounded region, `set_capture_excluded`, focusable on demand, whole-window alpha); `SHELL_MONITORS` (enumerate, per-monitor DPI v2, work areas); `SHELL_HOTKEYS` (multi-id, modifier interlock, bare-key opt-in) | Pill, placement, controls |
| simple_ffmpeg | dshow device + option listing | Settings, preflight |
| simple_process | `write_input` on SIMPLE_ASYNC_PROCESS (SHOULD) | Graceful ffmpeg stop |
| simple_file | UTF-8 `content` fix (verify first) | Retires STS_UTF8_READER |

### 1.3 simple_prompter library (pure)

**src/script**
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_WORD_ID` | Data (expanded) | Stable identity of a word across revisions |
| `PT_WORD` | Data | id, text, normalized, char span, flags (stop, cue), passage/paragraph/section index |
| `PT_PASSAGE` | Data | Sentence: first/last word index, paragraph, section |
| `PT_SECTION` | Data | Heading text, first word index |
| `PT_SCRIPT_REVISION` | Data (immutable) | Words, passages, sections, source text, revision number |
| `PT_SCRIPT_EDIT` | Data | A replacement: revision, word range, new text |
| `PT_SCRIPT_HISTORY` | Engine | Revision chain; `apply_edit`; id preservation (LCS) |
| `PT_SCRIPT_PARSER` | Engine | text/.md → `PT_SCRIPT_REVISION` via simple_markdown + STS; cue marking; stop words; ids |
| `PT_ID_SOURCE` | Utility | Monotone id generator per history |
| `PT_STOP_WORDS` | Policy | English stop-word set (aligner + matcher) |
| `PT_NORMALIZER` | Utility | Lowercase, strip punctuation, unify quotes/dashes, digits kept |

**src/follow**
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_CLOCK` | Deferred | `now_ms: REAL_64` monotone |
| `PT_FAKE_CLOCK` | Effective (tests + replay) | Settable clock |
| `PT_VOICE_FRAME` | Data | sample_pos, level, speech_prob, is_speech |
| `PT_HEARD_WORD` | Data | text, normalized, t0/t1 (s, relative), probability |
| `PT_HEARD_WORDS` | Data | Window sample_pos + list of heard words |
| `PT_WORD_MATCHER` | Policy | exact / stem-plural / bounded Levenshtein match of heard vs script word |
| `PT_ALIGNMENT` | Data | word_index, confidence, matched_count, rate_wps, is_anchored |
| `PT_ALIGNER` | Engine | Forward-biased bounded-window aligner (D-009) |
| `PT_SPRING` | Utility | Critically damped approach toward a target |
| `PT_FOLLOW_MODE` | Constants | constant, voice_gated, tracking |
| `PT_FOLLOWER` | Deferred (policy root) | `on_voice (frame)`, `on_alignment (a)`, `advance (dt)` → `target`, `velocity`; hold/caret |
| `PT_CONSTANT_FOLLOWER` | Effective | Fixed wpm; ignores voice |
| `PT_VOICE_GATED_FOLLOWER` | Effective | Fixed wpm while speech; decel/accel ramps (SR governor brake glide idea) |
| `PT_TRACKING_FOLLOWER` | Effective | Measured rate while speech; spring to aligned word; coast ≤ 1.5 s then hold |
| `PT_TEXT_MEASURE` | Deferred | `advance (s): REAL_64`, `line_height`, for a font |
| `PT_FIXED_MEASURE` | Effective (tests) | Monospace fixed advance |
| `PT_LINE` | Data | first/last word index, width, y |
| `PT_LAYOUT` | Engine | Wrap words into lines for width; word ↔ line ↔ y mapping |
| `PT_SCROLL_MODEL` | Engine | Fractional position (word units) advanced by follower; y offset via layout |

**src/take**
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_EVENT_KIND` | Constants | session_start … abort (range-checked INTEGERs) |
| `PT_TAKE_EVENT` | Data (immutable) | kind + rt + optional fields; per-kind creators (A-109) |
| `PT_JOURNAL` | Engine | Append-only rt-ordered events; replay |
| `PT_JOURNAL_CODEC` | Codec | Event ↔ JSONL line (simple_json) |
| `PT_TAKE_STATE` | Constants | idle, count_in, reading, held, editing, analyzing, wrapped |
| `PT_ACTION` | Constants | play (practice, no journal), again, hold, go, back, forward, back_paragraph, forward_paragraph, pick_word, edit_open, edit_commit, edit_cancel, star, reject, note, skip, wrap, abort, record, count_in_done |
| `PT_TRANSITIONS` | Policy (table) | (state, action) → allowed?, next state |
| `PT_TAKE_CONTROLLER` | Engine | State machine; actions → events; owns caret; talks to history + journal |
| `PT_RESTART_POLICY` | Policy | Default caret after Again; caret stepping (via STS_NAVIGATOR semantics) |
| `PT_RECORDING_CLOCK` | Engine | rt from tee byte count (+ QPC interpolation within a frame) |
| `PT_SESSION_FOLDER` | Utility | Paths of F-01 §9.1 layout |
| `PT_SESSION` | Aggregate | Folder + history + journal + (optional) analysis + cut list; save/load |

**src/assembly**
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_TIME_SPAN` | Data | [t0, t1] seconds, t0 ≤ t1 |
| `PT_SPEECH_MAP` | Data | Ordered disjoint speech spans; silence queries |
| `PT_WORD_OCCURRENCE` | Data | word id, span, confidence, attempt index |
| `PT_WORD_TIMELINE` | Data | Occurrences ordered by rt |
| `PT_ATTEMPT` | Data | index, span, caret word, revision, start/end word index, starred, rejected |
| `PT_ATTEMPT_BUILDER` | Engine | Journal → attempts (live marks only) |
| `PT_TRANSCRIBER` | Deferred | audio file → (speech map, heard words with absolute rt) |
| `PT_SCRIPTED_TRANSCRIBER` | Effective (tests) | Returns fixture results |
| `PT_ATTEMPT_ALIGNER` | Engine | Heard words per attempt → occurrences against the attempt's revision; finds caret word |
| `PT_SILENCE_SNAPPER` | Engine | Cut points into silences or tight |
| `PT_CUT` | Data | src index, span, first/last word id, attempt, tight |
| `PT_CUT_LIST` | Data | Ordered cuts; output-time mapping; floor spans |
| `PT_TAKE_SOLVER` | Engine | Shortest path words × attempts → cut list (F-01 §7) |
| `PT_FLAG_KIND` | Constants | misread, low_confidence, unmarked_restart, tight_splice, missing, long_pause |
| `PT_FLAG` | Data | kind, span, word range, message |
| `PT_FLAGGER` | Engine | Produce flags from occurrences + cuts + map |
| `PT_ANALYSIS` | Data | speech map + timeline + attempts + flags + decisions log lines |
| `PT_SESSION_ANALYZER` | Engine | Orchestrates transcriber → attempt aligner → snapper → solver → flagger |

**src/output**
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_TIMECODE` | Utility | Seconds ↔ `HH:MM:SS,mmm` / `HH:MM:SS.mmm` / EDL frames |
| `PT_CAPTION_BUILDER` | Engine | Final words + occurrences + cut map → caption cues (SRT/VTT text) |
| `PT_REVIEW_SRT_WRITER` | Engine | Journal → review.srt text |
| `PT_CHAPTER_WRITER` | Engine | Sections + notes + cut map → chapter list |
| `PT_EDL_WRITER` | Engine | Cut list → CMX3600 text |
| `PT_CUT_CODEC` | Codec | Cut list ↔ cut.json |
| `PT_ANALYSIS_CODEC` | Codec | Analysis ↔ analysis/*.json |

**src/record** (plans only; running processes is runtime/)
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_DEVICE_CHOICE` | Data | Camera name, mic name, size, fps |
| `PT_CAPTURE_PLAN` | Builder | ffmpeg argument list for capture (MKV + tee file) |
| `PT_RENDER_PLAN` | Builder | Cut list + cosmetics → filter script text + args |
| `PT_PREFLIGHT` | Policy | Checks: disk vs bitrate, devices listed, ffmpeg/model present (inputs injected) |
| `PT_RECORDER_HEALTH` | Data | alive, bytes/s, dropped frames, last error |

**src/config**
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_SETTINGS` | Store | TOML-backed, clamped getters, save-on-set (SR_SETTINGS pattern) |
| `PT_CAMERA_ANCHOR` | Data | monitor key, x, y (physical px) |
| `PT_KEY_BINDING` | Data | action, modifiers, vkey, bare_while_recording |
| `PT_KEYMAP` | Engine | Bindings; lookup; validation (modifier interlock) |

**facade**
| Class | Role | Responsibility |
|-------|------|----------------|
| `SIMPLE_PROMPTER` | Facade | Open script, settings, create follower for mode, create take controller/session, run analysis/solve, write outputs |

### 1.4 speech/ cluster (app + worker targets; depends on simple_speech, simple_audio)
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_AUDIO_SOURCE` | Deferred | `read_available (buffer): INTEGER` 16 kHz mono f32 |
| `PT_WASAPI_SOURCE` | Effective | simple_audio capture (practice mode) |
| `PT_TAIL_SOURCE` | Effective | Reads appended bytes of `tee.f32` (recording mode; A-101) |
| `PT_SPEECH_WORKER` | SCOOP processor | VAD frames + rolling whisper; deposits encoded records into slot; accepts prompt text |
| `PT_SPEECH_SLOT` | Mailbox (separate) | Non-blocking queue of encoded records (simple_chat/taskman pattern) |
| `PT_SPEECH_CODEC` | Codec | `PT_VOICE_FRAME` / `PT_HEARD_WORDS` ↔ compact STRING_8 (values cross processors as strings) |
| `PT_WHISPER_TRANSCRIBER` | Effective `PT_TRANSCRIBER` | Full-file pass via simple_speech (worker exe) |

### 1.5 runtime/ cluster (app target)
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_QPC_CLOCK` | Effective `PT_CLOCK` | `SHELL_DESKTOP.now_ms` (QPC, shell_desktop.e:75-82) |
| `PT_RECORDER` | Runtime | Launch ffmpeg with `PT_CAPTURE_PLAN` (SIMPLE_ASYNC_PROCESS), parse stderr progress, stop (stdin `q` if available, else terminate), health |
| `PT_RENDERER` | Runtime | Run render plan; progress |
| `PT_WORKER_LAUNCHER` | Runtime | Start `prompter_worker --analyze`, poll mailbox (SR pattern, sr_app.e:781-851) |
| `PT_PREVIEW_PLAYER` | Runtime | ffplay for take/joint ranges |

### 1.6 app/ cluster (GUI; simple_shell, simple_widgets, simple_cairo)
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_APP` | Root | Two-phase construction (VEVI rule, SR lesson); heartbeat arms 16 ms tick; drains speech slot |
| `PT_PILL` | View | `SHELL_PANEL` host; states visuals (normal / held-expanded / count-in / editing) |
| `PT_PILL_RENDERER` | View | Cached line strip, fade mask, glow, caret, badges, REC dot (SW_PAINTER/cairo) |
| `PT_CAIRO_MEASURE` | Effective `PT_TEXT_MEASURE` | SW_PAINTER `advance` |
| `PT_INPUT_ROUTER` | Controller | Hotkeys/mouse/clicker → `PT_ACTION` → controller |
| `PT_INLINE_EDITOR` | View | Edit box on the pill (SW_TEXT_BOX) |
| `PT_EDIT_FLOOR_WINDOW` | View | Script column + take chips + detail + timeline + Render |
| `PT_TAKE_CHIPS_VIEW`, `PT_TIMELINE_VIEW` | View | Parts of Edit Floor |
| `PT_SETTINGS_WINDOW` | View | Devices, mode, appearance, keys |
| `PT_CALIBRATION_OVERLAY` | View | Crosshair to mark the lens |

### 1.7 worker/ cluster
| Class | Role | Responsibility |
|-------|------|----------------|
| `PT_WORKER_APP` | Root | `--analyze <session>`: run `PT_SESSION_ANALYZER` with `PT_WHISPER_TRANSCRIBER`; write analysis via tmp+rename (sr_worker.e:125-137) |

**Counts:** library 77 (11 script, 19 follow, 12 take, 18 assembly, 7 output, 5 record, 4 config, 1 facade;
includes the test doubles PT_FAKE_CLOCK, PT_FIXED_MEASURE, PT_SCRIPTED_TRANSCRIBER that live in src for replay
use), speech 7, runtime 5, app 11, worker 1, so **101 simple_prompter classes**, plus
7 in simple_text_structure. Phase tags in 07.

## 2. Facade Design: SIMPLE_PROMPTER

**Purpose:** headless entry point for scripts, following, takes, assembly and outputs. The GUI and worker
are clients of it. It mirrors the SR pattern (a headless facade driven by `tick`).

```eiffel
class SIMPLE_PROMPTER
create make
feature -- Script
    open_script (a_path: READABLE_STRING_GENERAL)
    load_script_text (a_title, a_text: READABLE_STRING_GENERAL)
    history: PT_SCRIPT_HISTORY
    has_script: BOOLEAN
feature -- Following
    set_mode (a_mode: INTEGER)            -- {PT_FOLLOW_MODE}
    follower: PT_FOLLOWER
    feed_voice (a_frame: PT_VOICE_FRAME)
    feed_heard (a_heard: PT_HEARD_WORDS)
    tick (a_now_ms: REAL_64)
    scroll: PT_SCROLL_MODEL
feature -- Take Studio
    start_session (a_folder: PT_SESSION_FOLDER)
    controller: PT_TAKE_CONTROLLER
    session: detachable PT_SESSION
    perform (a_action: INTEGER)
feature -- Assembly
    assemble (a_analysis: detachable PT_ANALYSIS): PT_CUT_LIST     -- live-marks fallback when Void
    write_outputs (a_cuts: PT_CUT_LIST)
feature -- Configuration
    settings: PT_SETTINGS
```
**Hides:** parser, aligner, policies, codecs, solver internals.

## 3. Key engine designs

### PT_ALIGNER (D-009)
```eiffel
class PT_ALIGNER
create make (a_revision: PT_SCRIPT_REVISION; a_matcher: PT_WORD_MATCHER)
feature
    position: INTEGER               -- current word index (0 = before first)
    confidence: REAL_64
    update (a_heard: PT_HEARD_WORDS)          -- command
    last_alignment: PT_ALIGNMENT              -- query
    reanchor (a_word_index: INTEGER)          -- caret change: high-confidence reset
feature -- Policy (constants, single choice)
    Window_back: INTEGER = 3
    Window_ahead: INTEGER = 40
    Recent_heard: INTEGER = 6
```

### PT_FOLLOWER hierarchy
```
            PT_FOLLOWER (deferred)
   ┌───────────────┼────────────────────┐
PT_CONSTANT   PT_VOICE_GATED      PT_TRACKING
_FOLLOWER     _FOLLOWER           _FOLLOWER
```

### PT_TAKE_CONTROLLER
- Holds `state`, `caret`, `current_revision`.
- `perform (a_action)` requires `is_allowed (a_action)` (table in `PT_TRANSITIONS`, single choice).
- Appends events to the journal with rt from `PT_RECORDING_CLOCK`.
- Never blocks; no I/O except the journal flush (simple_file append, one line per event).

### PT_TAKE_SOLVER
- Input: final revision, attempts, timeline (or live-mark estimate), speech map, config (splice cost S, age penalty, confidence threshold).
- Algorithm: DP over (word index, attempt) with transitions at passage boundaries or tight carets. O(words × attempts).
- Output: `PT_CUT_LIST`.

### PT_SPEECH_WORKER (SCOOP)
```
GUI: separate worker; separate slot
     worker.start (source_kind, model_path, use_gpu)   -- async call, returns immediately
     each tick: slot.take_all → decode → follower
     worker.set_prompt (already_read_text)              -- async
worker loop: read source → VAD per 30 ms → frame record → every 250 ms if speech: decode 3 s window
             (no_context, prompt, greedy, word ts) → heard record → slot.put
```
All whisper/audio externals are `C blocking inline` (C-006). Records are encoded strings (taskman A-103 pattern).

## 4. Data Class Designs (immutable values)

```eiffel
class PT_WORD
feature
    id: PT_WORD_ID
    text, normalized: STRING_32
    char_start, char_end: INTEGER
    passage_index, paragraph_index, section_index: INTEGER
    is_stop_word, is_cue: BOOLEAN
invariant
    span_ordered: char_start <= char_end
    normalized_not_longer: normalized.count <= text.count
end

class PT_TIME_SPAN
feature
    t0, t1: REAL_64
    duration: REAL_64 do Result := t1 - t0 end
invariant
    ordered: t0 <= t1
    non_negative: t0 >= 0
end
```

## 5. Inheritance Hierarchy

```
PT_CLOCK* ── PT_FAKE_CLOCK, PT_QPC_CLOCK
PT_TEXT_MEASURE* ── PT_FIXED_MEASURE, PT_CAIRO_MEASURE
PT_FOLLOWER* ── PT_CONSTANT_FOLLOWER, PT_VOICE_GATED_FOLLOWER, PT_TRACKING_FOLLOWER
PT_TRANSCRIBER* ── PT_SCRIPTED_TRANSCRIBER, PT_WHISPER_TRANSCRIBER
PT_AUDIO_SOURCE* ── PT_WASAPI_SOURCE, PT_TAIL_SOURCE
PT_EVENT_KIND, PT_TAKE_STATE, PT_ACTION, PT_FLAG_KIND, PT_FOLLOW_MODE: constant holders (no inheritance; reached as {X}.Constant)
```

**Inheritance Justification:**
| Child | Parent | IS-A Valid? | Liskov OK? |
|-------|--------|-------------|------------|
| PT_FAKE_CLOCK / PT_QPC_CLOCK | PT_CLOCK | Both are monotone ms clocks | YES (same postcondition: non-decreasing) |
| PT_FIXED_MEASURE / PT_CAIRO_MEASURE | PT_TEXT_MEASURE | Both measure strings in px | YES (advance ≥ 0; additive within tolerance) |
| PT_*_FOLLOWER | PT_FOLLOWER | Each is a follow policy | YES: all honor DR-015 (no spontaneous backward motion) and `held implies velocity = 0` |
| PT_SCRIPTED / PT_WHISPER_TRANSCRIBER | PT_TRANSCRIBER | Both produce map + words for a file | YES (spans ordered, within duration) |
| PT_WASAPI / PT_TAIL_SOURCE | PT_AUDIO_SOURCE | Both deliver 16 kHz mono f32 | YES (count ≥ 0, never blocks) |

No implementation inheritance between engines (composition everywhere else).

## 6. Generic Classes

| Class | Type Parameter | Constraint | Purpose |
|-------|----------------|------------|---------|
| *(none in v1)* | | | Collections use base ARRAYED_LIST/HASH_TABLE; models use MML_SEQUENCE/MML_SET. A generic mailbox was rejected: SCOOP values cross as encoded strings (taskman pattern), so `PT_SPEECH_SLOT` is concrete. |

Considered and rejected: `PT_CONSTANT_SET [G]` for the constant holders. Range-checked INTEGER
constants (taskman rule 8) are simpler and `{X}.Constant`-reachable.

## 7. Class Diagram (core flow)

```
┌──────────────────┐ open_script ┌────────────────────┐ revisions ┌──────────────────────┐
│ SIMPLE_PROMPTER  │────────────>│ PT_SCRIPT_PARSER   │──────────>│ PT_SCRIPT_HISTORY    │
│ (facade)         │             └────────────────────┘           └──────────┬───────────┘
│ tick/feed_*      │─────────┐                                                │ current
└──────┬───────────┘         ▼                                                ▼
       │           ┌──────────────────┐ alignment ┌────────────┐   ┌──────────────────────┐
       │           │ PT_FOLLOWER*     │<──────────│ PT_ALIGNER │<──│ PT_SCRIPT_REVISION   │
       │           └───────┬──────────┘           └────────────┘   └──────────────────────┘
       │                   │ target/velocity
       │                   ▼
       │           ┌──────────────────┐  y offset  ┌────────────┐
       │           │ PT_SCROLL_MODEL  │──────────> │ PT_LAYOUT  │
       │           └──────────────────┘            └────────────┘
       │ perform
       ▼
┌────────────────────┐ events ┌────────────┐  replay  ┌────────────────────┐  attempts ┌───────────────┐
│ PT_TAKE_CONTROLLER │──────> │ PT_JOURNAL │────────> │ PT_ATTEMPT_BUILDER │─────────> │ PT_TAKE_SOLVER│
└────────────────────┘        └────────────┘          └────────────────────┘           └──────┬────────┘
                                                                                               │ PT_CUT_LIST
                                       ┌──────────────────┬─────────────────┬──────────────────┤
                                       ▼                  ▼                 ▼                  ▼
                               PT_RENDER_PLAN    PT_CAPTION_BUILDER   PT_EDL_WRITER    PT_CHAPTER_WRITER
```

## 8. ECF Targets

| Target | Kind | Root | Clusters | Extra libs | Concurrency |
|--------|------|------|----------|-----------|-------------|
| `simple_prompter` | library_target | (none) | src (recursive), facade | base, time, simple_text_structure, simple_markdown, simple_json, simple_toml, simple_file, simple_encoding, simple_mml | support scoop |
| `prompter` | extends | `PT_APP.make` | app, runtime, speech | simple_shell, simple_widgets, simple_cairo, simple_speech (CUDA variant), simple_audio, simple_process, simple_ffmpeg | **use scoop** |
| `prompter_worker` | extends | `PT_WORKER_APP.make` | worker, speech | simple_speech (CUDA), simple_audio (for source class compile), simple_process | scoop (single processor in practice) |
| `simple_prompter_tests` | extends | `TEST_APP.make` | testing | testing, simple_testing | scoop |

Every extending target repeats `<option><assertions precondition postcondition check invariant loop supplier_precondition/>` (C-010).
