# DOMAIN MODEL: simple_prompter

Class prefix **`PT_`** (checked 2026-10-05: no `class PT_` anywhere under D:\prod; `PR_` is taken by
Gobo's parse library). Facade: `SIMPLE_PROMPTER`.

## Domain Concepts

### A. Script

#### Concept: Script word
**Definition:** One readable token of the script, with a stable identity.
**Attributes:** id, display text, normalized form (lowercase, punctuation stripped, digits kept), character span in its revision's text, is_stop_word, is_cue.
**Behaviors:** compare normalized forms; fuzzy-match a heard word.
**Will become:** `PT_WORD` (value object); `PT_WORD_ID` (stable identity, expanded INTEGER_64 wrapper).

#### Concept: Passage
**Definition:** A unit of the script used for restarts and take selection. A sentence by default (D-T05).
**Attributes:** index, first word index, last word index, paragraph index, section index.
**Will become:** `PT_PASSAGE`.

#### Concept: Section
**Definition:** A headed part of the script (from Markdown `#` headings). Used for chapters and jump-to-section.
**Will become:** `PT_SECTION`.

#### Concept: Script revision
**Definition:** An immutable version of the script: ordered words, passages, sections, source text.
**Behaviors:** look up a word by id; find a passage containing a word index; search words near an index.
**Will become:** `PT_SCRIPT_REVISION`.

#### Concept: Script history
**Definition:** The ordered chain of revisions in a session. Edits create new revisions.
**Behaviors:** apply an edit (range → new text) producing revision n+1 with preserved ids; strike; undo-as-new-revision.
**Will become:** `PT_SCRIPT_HISTORY`, `PT_SCRIPT_EDIT` (value).

#### Concept: Script source parsing
**Definition:** Turning .txt/.md text into words/passages/sections; Markdown stripping; cue extraction.
**Will become:** `PT_SCRIPT_PARSER` (and `PT_SENTENCE_SPLITTER` policy).

### B. Following (live)

#### Concept: Voice frame
**Definition:** ~30 ms summary of the audio: level (RMS), speech probability, speech flag, sample position.
**Will become:** `PT_VOICE_FRAME` (value, crosses processors).

#### Concept: Heard words
**Definition:** One decode result from the rolling ASR window: words with relative times, probabilities, and the window's sample position.
**Will become:** `PT_HEARD_WORDS` (value), `PT_HEARD_WORD`.

#### Concept: Alignment
**Definition:** The aligner's estimate of where the reader is: word index, confidence, matched count, speaking rate.
**Will become:** `PT_ALIGNMENT` (value); engine `PT_ALIGNER`; matching policy `PT_WORD_MATCHER`.

#### Concept: Follower
**Definition:** The state machine that turns voice frames and alignments into scroll motion: target position, velocity, coasting, holding.
**Will become:** `PT_FOLLOWER` (deferred policy root) with modes `PT_CONSTANT_FOLLOWER`, `PT_VOICE_GATED_FOLLOWER`, `PT_TRACKING_FOLLOWER`.

#### Concept: Scroll model
**Definition:** The continuous display position (fractional word / line offset) advanced by velocity × dt from a monotonic clock, with spring smoothing toward targets.
**Will become:** `PT_SCROLL_MODEL`, `PT_SPRING` (critically damped).

#### Concept: Layout
**Definition:** Wrapping words into display lines for a given font metric and column width; mapping word index ↔ line ↔ pixel offset.
**Will become:** `PT_LAYOUT`, `PT_LINE` (value). The measurement function is supplied by the app (`PT_TEXT_MEASURE` deferred), so the library stays GUI-free.

#### Concept: Speech engine (worker side)
**Definition:** Owns the audio source, VAD, rolling whisper; produces frames and heard words; accepts prompt text.
**Will become:**
- `PT_SPEECH_WORKER` (separate);
- `PT_AUDIO_SOURCE` (deferred), with `PT_WASAPI_SOURCE` (practice mode) and `PT_PIPE_SOURCE` (ffmpeg tee);
- `PT_SPEECH_SLOT` (mailbox).

### C. Take Studio

#### Concept: Recording time
**Definition:** Seconds on the raw recording's audio timeline = PCM samples received / 16,000 (D-T02).
**Will become:** `PT_RECORDING_CLOCK`.

#### Concept: Session
**Definition:** One sitting: folder, settings snapshot, raw recording, journal, script history, analysis, cut list.
**Will become:** `PT_SESSION`, `PT_SESSION_FOLDER` (paths/layout, F-01 §9.1).

#### Concept: Take event (mark)
**Definition:** An immutable journal entry at a recording time: session_start, resume, hold, flub, rewind_to, count_in, edit, star, reject, note, align (sampled), wrap, abort.
**Will become:** `PT_TAKE_EVENT` (one class with a kind code + optional fields, see 03 A-104), `PT_EVENT_KIND` (constants).

#### Concept: Journal
**Definition:** Append-only, rt-ordered event log, persisted as JSONL and flushed per event; replayable.
**Will become:** `PT_JOURNAL`, `PT_JOURNAL_CODEC` (JSONL ↔ events).

#### Concept: Take controller
**Definition:** The Take Studio state machine (IDLE, COUNT_IN, READING, HELD, EDITING, ANALYZING, WRAPPED). It maps actions to events and state changes.
**Will become:** `PT_TAKE_CONTROLLER`, `PT_TAKE_STATE` (constants), `PT_ACTION` (constants).

#### Concept: Restart policy
**Definition:** Rules choosing the caret after Again, and stepping it by passage/paragraph.
**Will become:** `PT_RESTART_POLICY`.

#### Concept: Attempt / take
**Definition:** An attempt is one continuous reading interval [rt_in, rt_out] starting at a caret word under a revision. A take is the part of an attempt covering one passage.
**Will become:** `PT_ATTEMPT` (value), `PT_ATTEMPT_BUILDER` (journal → attempts).

#### Concept: Aligned word occurrence (analysis)
**Definition:** A script word heard in the recording: word id, rt_start, rt_end, confidence, attempt index.
**Will become:** `PT_WORD_OCCURRENCE` (value), `PT_WORD_TIMELINE` (collection).

#### Concept: Speech map
**Definition:** VAD speech/silence runs over the recording.
**Will become:** `PT_SPEECH_MAP`, `PT_TIME_SPAN` (value).

#### Concept: Cut list
**Definition:** Ordered source intervals forming the final video, with words covered and attempt ref; rt ↔ output-time mapping.
**Will become:** `PT_CUT_LIST`, `PT_CUT` (value).

#### Concept: Take solver
**Definition:** Chooses takes (shortest path over words × attempts) and produces the cut list.
**Will become:** `PT_TAKE_SOLVER`.

#### Concept: Silence snapper
**Definition:** Moves cut points into VAD silences, or flags them tight.
**Will become:** `PT_SILENCE_SNAPPER`.

#### Concept: Review flag
**Definition:** An analysis finding: misread, low confidence, unmarked restart, tight splice, missing coverage, long pause.
**Will become:** `PT_FLAG` (value), `PT_FLAG_KIND` (constants).

#### Concept: Session analyzer
**Definition:** Full-recording pipeline: transcribe, align per attempt, find carets, snap, solve, flag.
**Will become:** `PT_SESSION_ANALYZER` (runs on a separate processor).

#### Concept: Writers (exports)
**Will become:**
- `PT_CAPTION_BUILDER` (SRT/VTT);
- `PT_REVIEW_SRT_WRITER`;
- `PT_CHAPTER_WRITER`;
- `PT_EDL_WRITER` (CMX3600 first; FCPXML/OTIO later);
- `PT_CUT_CODEC` (cut.json).

#### Concept: Recorder
**Definition:** Builds and runs the ffmpeg capture command; streams PCM; stops gracefully; reports health.
**Will become:** `PT_RECORDER` (separate, owns the ffmpeg child), `PT_CAPTURE_PLAN` (command builder value), `PT_RECORDER_HEALTH` (value).

#### Concept: Render plan
**Definition:** Cut list + cosmetics → ffmpeg filter script + arguments.
**Will become:** `PT_RENDER_PLAN`, `PT_RENDERER`.

### D. Configuration and placement

#### Concept: Settings
**Definition:** Persisted preferences: mode, speed, font, lines, width, opacity, colors, hotkeys, devices, count-in, pads, thresholds.
**Will become:** `PT_SETTINGS` (TOML via simple_toml).

#### Concept: Camera anchor
**Definition:** The calibrated lens point per monitor (monitor key → x, y in physical pixels).
**Will become:** `PT_CAMERA_ANCHOR` (value), stored in settings.

#### Concept: Key binding
**Definition:** Action ↔ (modifiers, virtual key), with a "bare key allowed only while recording" flag for clicker keys.
**Will become:** `PT_KEY_BINDING` (value), `PT_KEYMAP`.

## Concept Relationships

```
PT_SCRIPT_HISTORY ──has-many──> PT_SCRIPT_REVISION ──has-many──> PT_WORD (id: PT_WORD_ID)
                                        └──has-many──> PT_PASSAGE ──in──> PT_SECTION
PT_SPEECH_WORKER ──uses──> PT_AUDIO_SOURCE (PT_WASAPI_SOURCE | PT_PIPE_SOURCE)
        └──deposits──> PT_SPEECH_SLOT ──drained by GUI──> PT_FOLLOWER ──drives──> PT_SCROLL_MODEL ──maps via──> PT_LAYOUT
PT_ALIGNER ──reads──> PT_SCRIPT_REVISION, PT_HEARD_WORDS ──produces──> PT_ALIGNMENT ──feeds──> PT_TRACKING_FOLLOWER
PT_FOLLOWER ◄──is-a── PT_CONSTANT_FOLLOWER | PT_VOICE_GATED_FOLLOWER | PT_TRACKING_FOLLOWER
PT_TAKE_CONTROLLER ──appends──> PT_JOURNAL ──has-many──> PT_TAKE_EVENT
        └──uses──> PT_RESTART_POLICY, PT_SCRIPT_HISTORY, PT_RECORDING_CLOCK
PT_RECORDER ──feeds PCM──> PT_PIPE_SOURCE        (same samples = recording time)
PT_SESSION ──has──> journal, history, PT_SPEECH_MAP, PT_WORD_TIMELINE, PT_CUT_LIST
PT_SESSION_ANALYZER ──uses──> PT_ATTEMPT_BUILDER, PT_ALIGNER, PT_SILENCE_SNAPPER, PT_TAKE_SOLVER ──produces──> PT_CUT_LIST, PT_FLAG*
PT_CUT_LIST ──consumed by──> PT_RENDER_PLAN, PT_CAPTION_BUILDER, PT_EDL_WRITER
```

## Domain Rules
| Rule | Description | Enforcement |
|------|-------------|-------------|
| DR-001 | Word ids are unique within a revision | Postcondition of `PT_SCRIPT_PARSER.parse` and `PT_SCRIPT_HISTORY.apply_edit` (not an invariant: O(n), C-009) |
| DR-002 | A revision never changes once created | No commands on `PT_SCRIPT_REVISION` (immutable by construction) |
| DR-003 | An edit preserves ids of untouched words | `apply_edit` postcondition via id-sequence models |
| DR-004 | Passages partition the words, in order | Parser postcondition; O(1) invariant `passages.count <= words.count` |
| DR-005 | Journal events are rt-non-decreasing | `PT_JOURNAL.append` precondition `a_event.rt >= last_rt`; invariant `last_rt >= 0` |
| DR-006 | Journal is append-only | `append` postcondition `events_model = old events_model & a_event`; no remove features |
| DR-007 | Recording time is monotone | `PT_RECORDING_CLOCK.advance` precondition samples ≥ 0; postcondition non-decreasing |
| DR-008 | State transitions follow the table | `PT_TAKE_CONTROLLER.perform` precondition `is_allowed (a_action)` |
| DR-009 | Attempts don't overlap in rt | `PT_ATTEMPT_BUILDER.build` postcondition |
| DR-010 | Cut list covers every final word exactly once, in script order | `PT_TAKE_SOLVER.solve` postcondition |
| DR-011 | No cut overlaps a rejected attempt | `solve` postcondition |
| DR-012 | Floor = raw timeline minus cut list | `PT_CUT_LIST.floor_spans` postcondition (total durations add up) |
| DR-013 | Stale takes are never chosen automatically | `solve` postcondition |
| DR-014 | Bare keys bound only while recording | `PT_KEYMAP` precondition on activation; app releases on every exit path |
| DR-015 | The follower never moves the scroll backward on its own, except on an explicit caret change | `PT_FOLLOWER` postconditions (`target >= old target` unless `caret_changed`) |
| DR-016 | Aligner forward bias: backward moves need ≥ N anchored matches | `PT_ALIGNER.update` postcondition |
| DR-017 | Stop words alone never move alignment | `update` postcondition |

## Glossary
| Term | Definition |
|------|------------|
| rt | Recording time (seconds on the raw audio timeline) |
| Caret | The restart word chosen while HELD |
| Count-in | Visual countdown before reading resumes |
| Run-up | Words read before the caret to get into rhythm; cut away |
| Stale take | A take of a passage whose words changed in a later revision |
| Floor | Everything not in the cut list |
| Tight splice | A cut not inside a silence |
| Tee | ffmpeg's second output: 16 kHz mono f32 PCM to the prompter's stdin pipe |
| Soft hold | (deferred with F-02) |
