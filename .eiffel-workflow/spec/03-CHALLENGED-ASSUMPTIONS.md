# CHALLENGED ASSUMPTIONS: simple_prompter

Date: 2026-10-05. Attack mindset. Inputs:
- research;
- F-01;
- the simple_speed_reader inventory (v0.9.0, read-only survey of 7.4k lines, file:line cited below);
- spec-phase spikes (evidence/spike-ffmpeg-record-splice.md addendum).

## Assumptions Challenged

### A-101: "The prompter must read ffmpeg's PCM through a stdout pipe" (F-01 §5.1)
**Challenge:** a pipe couples ffmpeg to the GUI process. If the reader stalls, ffmpeg blocks and drops
frames (R-T1). It also needs a binary streaming read that simple_process lacks
(simple_async_process.e:208-229 is UTF-8 text, accumulating).
**Evidence against the pipe:** spec spike: ffmpeg writing `-f f32le -flush_packets 1 tail.f32` keeps the
growing file within ~0.17 s of the wall clock; the final size is exact (384,000 bytes = 6.000 s).
**Verdict:** INVALID as stated. **Tail a file instead.** ffmpeg writes `session/tee.f32`. The speech
worker reads appended bytes. rt = bytes / 64,000. If the GUI stalls, the recording is untouched.
**Action:** `PT_PIPE_SOURCE` becomes **`PT_TAIL_SOURCE`**. The simple_process binary-read change drops
from MUST to unnecessary for recording. stdin write (graceful `q`) stays SHOULD; MKV already survives
a hard stop. Live-camera latency still to be measured (T-0).

### A-102: "Long-press clicker Back = Hold + browse" (F-01 §4.3)
**Challenge:** simple_shell forwards no key-up events. simple_speed_reader works around this
(sr_app.e:350-352: "hold-keys are impossible").
**Verdict:** INVALID for v1.
**Action:** drop long-press mappings. Hold is the clicker's B/"." key or Ctrl+Alt+Space; browse uses
Back/Fwd while HELD. If key-up is ever added to simple_shell, long-press can return.

### A-103: "Write a new script parser for simple_prompter"
**Challenge:** simple_speed_reader already has a contracted, tested tokenizer:
- `SR_TOKENIZER.tokenize` (sr_tokenizer.e:35-128) gives words with `source_start` char offsets plus sentence, paragraph and section indexes;
- quote-aware sentence ends (:172);
- heading/section detection (:152);
- tests (speed_reader_test_set.e:145-183, :885).

The oracle rule "Enumerate the simple_* ecosystem BEFORE designing" names exactly this failure
(hand-rolling what exists).
**Verdict:** INVALID.
**Action:** **extract** `SR_TOKENIZER`, `SR_TOKEN` (pivot made optional) and `SR_TEXT` into a new shared
library, working name **`simple_text_structure`**; simple_speed_reader migrates onto it later. The
prompter adds:
- word identity (`PT_WORD_ID`) and revisions on top;
- an abbreviation list ("Dr.", "e.g.", "U.S."; the speed reader treats them as sentence ends, an inventory gap), added in the shared library;
- Markdown stripping as **`SIMPLE_MARKDOWN.to_plain_text`** upstream (simple_markdown today is HTML-only), not a private stripper.

### A-104: "Rewind/jump navigation is new work"
**Challenge:** `SR_SESSION` (sr_session.e) already has `sentence_start` (:113), `replay_sentence` (:221: the
previous sentence if already at its head, exactly F-01 §4.4's default-caret rule), agent-parameterized
`jump_structure` (:464), `preset_position` (:142).
**Verdict:** INVALID.
**Action:** `PT_RESTART_POLICY` reuses the semantics. The structure-navigation queries move into
`simple_text_structure` as pure functions over the token list.

### A-105: "The live speech engine and the analysis pass both run in-process on SCOOP"
**Challenge:** the analysis pass is a batch job (minutes of audio, one-shot), so it doesn't need to be in-process.
simple_speed_reader's worker exe + atomic file mailbox (sr_worker.e:125-137 tmp+rename; GUI polls,
sr_app.e:781-851) is a proven ecosystem pattern. Running it as a child process isolates CUDA crashes and model memory from the GUI.
**Verdict:** MODIFY.
- **Live speech:** in-process SCOOP worker (D-003 stands; it needs streaming).
- **Analysis:** `prompter_worker.exe --analyze <session>` writes `analysis/*.json` via tmp+rename. The GUI polls.
- **Rendering:** ffmpeg child.
**Action:** add a `prompter_worker` target (an extending target, as speed_reader does). VRAM: two model copies ≈ 1.15 GB, within NFR-004.

### A-106: "Settings in TOML" (D-011)
**Challenge:** simple_speed_reader's `SR_SETTINGS` (src/store/sr_settings.e) uses simple_config (JSON)
with clamped getters (`bounded`, :223) and save-on-set. That's a proven pattern.
**Evidence for TOML:** the prompter needs nested tables (keymap, per-monitor camera anchors, devices). simple_toml is a
verified parser and writer (oracle rule); TOML is friendlier to hand edits.
**Verdict:** VALID (TOML), adopting the SR pattern: clamped getters, save-on-set, UTF-8 strings.

### A-107: "WM_TIMER at 16 ms + time-based motion gives smooth scrolling" (research A-5)
**Challenge:**
- simple_speed_reader uses `window.tick_ms`, an INTEGER millisecond clock (sr_app.e:199-266), with no high-resolution clock;
- the tick must be armed only after the window handle exists (`on_heartbeat`, :186-197).

**Verdict:** NEEDS_VALIDATION.
**Action:**
- the library takes time from a deferred `PT_CLOCK`; the app supplies a QPC-backed clock (inline C, in simple_shell if absent there; checked at contracts time); tests use a fake clock (the SR headless + scripted-clock pattern);
- arm the 16 ms tick from the heartbeat (SR lesson);
- render every tick while moving, and use render-signature dedup only while idle (sr_app.e:255-262).

### A-108: "Word ids survive edits"
**Challenge:** how are untouched words recognized?
**Verdict:** VALID with a defined algorithm. An edit replaces an explicit word range [i..j] in revision
n. The new text is tokenized. An LCS over normalized forms between old[i..j] and the new words keeps the
ids of matched words. Unmatched new words get fresh ids. Words outside [i..j] are copied with their ids.
**Action:** postcondition `untouched_ids_preserved` on `PT_SCRIPT_HISTORY.apply_edit`.

### A-109: "One class per event kind" (F-01 §10.2 listed descendants)
**Challenge:**
- a 13-way hierarchy adds 13 classes, and the JSONL codec must switch on kind anyway;
- most kinds carry 0-2 fields;
- polymorphism buys nothing: no behavior differs, only data.

**Verdict:** MODIFY. One immutable `PT_TAKE_EVENT` with `kind` (range-checked constant from `PT_EVENT_KIND`),
`rt`, optional `word`, `caret`, `text`, `from_rev`/`to_rev`, `old_text`/`new_text`, `by`. Creation procedures
per kind (`make_flub`, `make_edit`, …) give type-safe construction, and their preconditions require the fields that kind needs.

### A-110: "Analysis of a 4-minute session takes tens of seconds" (F-01 §6)
**Verdict:** NEEDS_VALIDATION (estimate from a 3 s window benchmark). Measure in T-3. Design doesn't
depend on it: the Edit Floor can open on live marks and refresh when analysis lands.

### A-111: "Capture exclusion works on an opaque popup" (research A-3)
**Verdict:** NEEDS_VALIDATION (spike S-2). Design keeps `is_capture_excluded` observable and
shows a pill indicator when the affinity call fails.

### A-112: "UTF-8 script files read correctly with simple_file"
**Challenge:** SR notes `SIMPLE_FILE.content` mojibakes UTF-8 and reads bytes instead
(simple_speed_reader.e:95-97).
**Verdict:** NEEDS_VALIDATION, then fix **upstream in simple_file** (oracle: fix lib bugs in the lib).
The prompter does not copy the byte workaround. The text loader lives in `simple_text_structure`
(or simple_file) as a single place for reading a UTF-8 file.

### A-113: "Assertions are inherited by test targets" (house ECF habit)
**Challenge:** oracle gotcha (simple_taskman 2026-10-05): clusters declared in an extending target don't
inherit the parent's `<option><assertions>`. simple_speed_reader's ECF declares assertions only in the library target, and its
`testing` cluster lives in the extending test target. So its test-class contracts are likely unmonitored
(same pattern as the taskman incident; not verified here).
**Verdict:** VALID concern.
**Action:** every simple_prompter target (app, worker, tests) declares its own assertions option (C-010).
Also report the likely issue to Larry for simple_speed_reader (not fixed in this phase).

### A-114: "SCOOP + `concurrency use=scoop`" (C-002)
**Challenge:** simple_speed_reader ships `support="scoop" use="thread"` and no `separate` code.
**Verdict:** VALID for simple_prompter: the live speech worker genuinely needs SCOOP (`use="scoop"`), as
simple_chat/simple_taskman do. The worker exe target can stay single-processor.

## Requirements Questioned

### FR-008 Audio-reactive glow
**Challenge:** cosmetic; costs a radial gradient per frame.
**Verdict:** KEEP (SHOULD). It is also the "you're being heard" signal that Moody calls the volume beam.
Cheap with simple_cairo `radial_gradient`.

### FR-009 Camera calibration
**Verdict:** KEEP (SHOULD). Larry's default camera is the external "FHD Camera"; a top-center default may be wrong for him.

### FR-T17 EDL / FCPXML / OTIO
**Verdict:** MODIFY. **CMX3600 EDL only** for v1 (plain text, Resolve imports it). FCPXML/OTIO deferred.

### FR-T19 Punch-in
**Verdict:** KEEP as an option, default off (plain cuts decided).

### FR-T20 / T22 / T23
**Verdict:** KEEP as COULD; no v1 design beyond the `src` index in `PT_CUT` (pickups) and a writer hook (floor reel).

### FR-044 `[CUE]` markers
**Verdict:** MODIFY to SHOULD: the aligner must exclude cue words anyway (they are never spoken), so the
parser has to recognize them regardless.

## Missing Requirements Identified
| ID | Missing Requirement | How Discovered |
|----|---------------------|----------------|
| FR-NEW-001 | Resume reading position (practice mode), stored as a **character offset** + revision hash, not a token index | SR stores a token index, which breaks on edit (inventory §11) |
| FR-NEW-002 | Drag-and-drop a script onto the pill or editor | SR has `set_on_files` on every surface (sr_app.e:135-139) |
| FR-NEW-003 | Pre-record checks: disk space vs bitrate, devices present, ffmpeg found, model present | F-01 §5.2 implied; make it explicit |
| FR-NEW-004 | Device loss mid-recording (camera unplugged): ffmpeg exits → recorder reports, session ends cleanly, files kept, journal gets `abort` with reason | Failure-mode walk |
| FR-NEW-005 | Offer to recover an unfinished session at startup | UC-006 |
| FR-NEW-006 | Log every decision of the analysis pass (attempt bounds, chosen takes, snaps) to `analysis/decisions.log` | Oracle rule "Log every decision in unattended runs" |
| FR-NEW-007 | Abbreviations don't end sentences | SR tokenizer gap |
| FR-NEW-008 | Focus self-heal after editor/dialog closes | SR lesson (sr_app.e:210-216) |

## Design Constraints Validated
| Constraint | Valid? | Notes |
|------------|--------|-------|
| simple_* first | YES | simple_text_structure (new, extracted from speed_reader), simple_markdown (+to_plain_text), simple_speech, simple_audio, simple_shell, simple_widgets, simple_cairo, simple_toml, simple_json (journal, cut.json), simple_file, simple_process, simple_ffmpeg, simple_testing, simple_mml |
| SCOOP-compatible | YES | One separate speech worker (live); analysis in a worker exe; GUI never waits |
| Void-safe | YES | All value objects attached; optional event fields detachable with kind-based preconditions |
| Invariants O(1) | YES | Collection rules are postconditions (02 DR table) |
| Per-target assertions | YES | C-010 |
| No Python | YES | |
