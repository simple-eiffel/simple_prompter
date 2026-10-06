# F-01 TAKE STUDIO: Retake, Live Script Edit, Recording, and the Edit Floor

| | |
|---|---|
| Project | simple_prompter |
| Feature | Take Studio (on-the-fly retakes + recording + automatic assembly) |
| Status | DRAFT v0.1, 2026-10-05, for Larry's review |
| Builds on | research/01-07 (hybrid voice follower, capture-invisible pill, CUDA whisper) |
| Evidence | evidence/spike-cuda-whisper.md, evidence/spike-ffmpeg-record-splice.md |

---

## 0. The idea in one paragraph

You read your script to the webcam. You cough, stumble or don't like a phrase. You press one
button: the prompter holds, offers you a restart point (or lets you pick any word), lets you
re-word the sentence if you want, counts you in, and you read it again. **The camera never stops
rolling.** Every press, rewind, edit and re-read is stamped onto the recording's own timeline. When
you wrap, a GPU pass listens to the whole recording, matches it word by word to the script, and
snaps every cut into a silence. A self-contained editor (the **Edit Floor**) shows each sentence
with its takes, picks the last good one by default, and renders one finished video with captions.
The flubs, coughs, pauses and false starts "hit the edit floor."

## 1. A session, told as a story

1. Larry opens `episode-12.md`, presses **Record**. The pill shows `● REC 00:00` and a 3-2-1.
2. He reads. The pill scrolls with his voice (Tracking mode). The journal records reading.
3. Mid-sentence 7 he coughs. He taps **Again** (clicker *Back* button).
   - The pill instantly **holds** and turns amber; the journal marks `flub @ 01:42.310`.
   - The restart caret jumps to the start of sentence 7. A 2 s count-in runs. The dimmed tail of
     sentence 6 is shown as a run-up.
   - He reads sentence 7 again. The earlier partial attempt is now superseded.
4. In sentence 12 he hates the word "notch". He taps **Hold**, then **Edit**.
   - An edit box opens on the pill with sentence 12 selected. He types "webcam" over "notch" and presses Enter.
   - The script becomes revision 2. The restart caret sits at the start of sentence 12, and he is counted in.
5. He loses his place in sentence 20 and wants to go back two sentences. He taps **Hold**, then
   presses Back twice (the caret steps back a sentence each time). He clicks a word with the mouse
   to be exact, then taps **Go**.
6. He finishes and taps **Wrap**. The pill shows: `22 sentences · 27 attempts · 3:41 recorded →
   ~3:05 final · analyzing…`
7. About 30 seconds later the **Edit Floor** opens: the script down the middle, every sentence
   with take chips (`T1 ✗ T2 ✓`). Three amber flags mark spots worth checking, e.g. "sentence 15: you said
   'their' (script: 'there')".
8. He plays two joints, nudges one cut by a word, and presses **Render**. Out come
   `episode-12.final.mp4`, `episode-12.final.srt` (captions from the script text) and
   `episode-12.chapters.txt` (from the Markdown headings). The rejected material is listed on the
   floor; nothing is deleted from the raw recording.

## 2. Goals and non-goals

**Goals**
- G-1 Retake from anywhere with one or two presses, without stopping the recording.
- G-2 Change script words mid-session; the final video and captions follow the final wording.
- G-3 Record the webcam + mic with ffmpeg, perfectly synchronized with the prompter's marks.
- G-4 Assemble a clean final cut automatically: last good take of every passage, cuts in silence.
- G-5 Review and fix that assembly in a built-in editor; render with the GPU.
- G-6 Keep everything recoverable: raw recording and journal are never modified.

**Non-goals (this feature)**
- Screen recording, multi-camera, B-roll, music, titles: hand the EDL to Resolve/Premiere for that.
- Cloud anything.
- Replacing OBS. An OBS backend is listed as a future option (§9.6).

## 3. Vocabulary

| Term | Meaning |
|------|---------|
| **Session** | One recording sitting: one raw video file + one journal + one script history. |
| **Script revision** | Immutable version of the script. Edits create revision n+1. |
| **Word id** | Stable identity of a script word across revisions. Edited words get new ids; untouched words keep theirs. |
| **Passage** | Alignment unit for take selection: a sentence by default (configurable: sentence / paragraph / line). |
| **Attempt** | One continuous stretch of reading between a *Go/Resume* and the next *Hold/Again/Wrap*. Covers a word range. |
| **Take** | The part of an attempt that covers a given passage. A passage can have many takes. |
| **Mark** | A journal event at a recording time (flub, hold, edit, star, reject, note…). |
| **Recording time (rt)** | Seconds on the raw recording's audio timeline. The only clock marks use. |
| **Cut list** | Ordered list of (rt_in, rt_out) source intervals forming the final video. |
| **Edit Floor** | The review editor. Also the bin of everything not in the cut list. |
| **Run-up** | Words read before the restart point to get into the flow; cut away automatically. |

## 4. Prompter states and controls

### 4.1 State machine

```
            Record                 Again / Hold                    Go
  IDLE ───────────► COUNT-IN ──► READING ─────────────► HELD ───────────► COUNT-IN ─► READING
   ▲                                │  ▲                 │  ▲  │
   │                     Wrap       │  │ Resume           │  │  │ Edit
   │   EDIT FLOOR ◄── ANALYZING ◄───┘  └──────────────────┘  │  ▼
   │                                                          │ EDITING ── Enter ─► HELD (caret at edit)
   │                                                          └─ Back/Fwd/click: REWIND browsing (sub-state of HELD)
   └──────────── Close / Render done
```

- **READING:** pill at normal size (3 lines), follower active, `● REC` dot in a corner.
- **HELD:** scrolling frozen. Pill border turns amber and the pill **expands** to 8 lines (browse room).
  Recording continues; held time goes to the floor automatically.
- **REWIND browsing** (inside HELD):
  - The restart caret `▸` sits on a word. Sentence starts carry digit badges `1-9` (nearest first).
  - The caret moves by sentence (Back/Fwd), paragraph (Shift), or exactly where you click.
- **COUNT-IN:** configurable 0-5 s (default 2). The pill shows dots `• • ○` and the run-up
  (previous ~6 words, dimmed). The follower is re-anchored at the caret with high confidence.
- **EDITING:** inline editor on the pill, with the passage containing the caret selected.
  - Enter commits a new revision, Esc cancels, Ctrl+Enter opens the full editor window.
  - The pill is capture-excluded in every state, so none of this shows on a screen share.

### 4.2 Actions (what the reader can do)

| Action | Effect | Journal |
|--------|--------|---------|
| **Again** | Hold + caret to start of current passage (previous passage if < 2 words into this one) + count-in. One press: the cough case. | `flub`, `rewind_to`, `count_in`, `resume` |
| **Hold** | Freeze, expand, wait. | `hold` |
| **Go / Resume** | From HELD: count-in from caret, then READING. | `count_in`, `resume` |
| **Back / Fwd** | In HELD: move caret one passage. With Shift: one paragraph. | `caret` (transient, not stored per step) |
| **Pick word** | Mouse click / touch on any word sets the caret exactly. Digits 1-9 jump to badged sentence starts. | `caret` |
| **Edit** | From HELD: open inline editor on caret passage. | `edit` (on commit) |
| **Star** | Keep the attempt just read even if a later take exists. | `star` |
| **Reject** | The attempt just read is bad; don't rewind (e.g. you kept going but know it was poor). | `reject` |
| **Note** | Drop a chapter/notes marker at now. | `note` |
| **Skip** | Strike the caret passage from this session (won't be read or required). | `edit` (strike) |
| **Wrap** | Stop recording gracefully, start analysis. | `wrap` |
| **Abort** | Stop, keep files, no analysis. | `abort` |

### 4.3 Control surfaces

You are on camera, so controls must work **without looking away and without visible keyboard
work**. Five surfaces, all mapped to the same actions:

| Surface | Mapping (defaults) | Notes |
|---------|-------------------|-------|
| **Presenter clicker** (sends PageUp/PageDown, B or ".", F5/Esc) | Back button = **Again** (in READING) / **Back** (in HELD); Forward = **Go** (in HELD); B/"." = **Hold**; long-press Back = **Hold** + browse | **Recommended primary.** Bare keys are only grabbed while a session is recording, and released on wrap. The pill shows a "clicker keys captured" glyph. Respects the modifier-less hotkey gotcha: never grab bare keys outside a session. |
| **USB foot pedal** (3-pedal, programmable) | Left = Again, Middle = Hold/Go, Right = Star | Program pedals to send Ctrl+Alt combos; hands stay free and invisible. |
| **Keyboard** (global hotkeys, modifier required) | Ctrl+Alt+Space Hold/Go · Ctrl+Alt+Backspace Again · Ctrl+Alt+E Edit · Ctrl+Alt+S Star · Ctrl+Alt+X Reject · Ctrl+Alt+N Note · Ctrl+Alt+End Wrap | In HELD/EDITING, plain keys (arrows, digits, Enter, Esc) are accepted only while the pill has focus. |
| **Mouse / touch on the pill** | Click word = Pick; wheel = browse; double-click = Go; right-click = action menu | Hover-to-pause (Moody behavior) is **off while recording** to avoid accidental holds. |
| **Voice commands**: **DEFERRED 2026-10-05** (Larry: mouse/keys only for now; design kept in **F-02-VOICE-COMMANDS.md**) | Wake phrase + verb: "Prompter, again" / "…hold" / "…go" / "…back two" / "…from *the main idea*"; silent "confirm ___?" answered yes/no | Always *in addition to* the surfaces above, never instead. On-screen command rail; script-aware collision map so reading "it scrolls again" never fires; spoken commands land on the floor. |

**Device-specific clicker capture (SHOULD investigate):** Windows Raw Input reports which
device sent a key. If feasible, only the clicker's PageDown is captured and the laptop
keyboard's PageDown stays untouched. Fallback: grab-while-recording as above.

### 4.4 Restart-point intelligence

- **Default caret** after Again: start of the current passage. If the flub happened within the
  first ~2 words of a passage, the start of the previous passage. If the follower's confidence is low
  (ad-lib), the last confidently aligned passage start.
- **Run-up reading is allowed.** You may begin a few words *before* the caret to find your rhythm.
  The splice point is the caret word, not where you started. The analysis pass finds the caret
  word inside the new attempt (§6) and cuts there, in the silence before it if there is one.
- **Mid-sentence restarts** (caret on a word, not a sentence start) are allowed. The editor marks them
  "tight splice" so you can listen to them first.

### 4.5 Live script editing rules

- An edit replaces a word range in revision *n* with new words in revision *n+1*.
  - Untouched words keep their ids.
  - The edited passage's earlier takes become **stale**: they no longer match the words to be said.
- After commit, the caret moves to the start of the edited passage. Count-in is offered (Go to start).
- Edits are allowed while HELD or in the full editor window (which also pauses: entering it = Hold).
- Editing a passage *not yet read* doesn't invalidate anything; it just changes what you'll read.
- Strike (Skip) is an edit to an empty range. Undo of the last edit (Ctrl+Z in the editor) is a new
  revision restoring the old words (word ids restored where unchanged).
- Final captions and transcript use the **last revision**.

## 5. Recording subsystem

### 5.1 One capture, two outputs (sync by construction)

ffmpeg is the **only** process that opens the camera and the microphone. It writes the raw
recording **and** streams the same audio to the prompter on stdout:

```
ffmpeg -f dshow -rtbufsize 512M -vcodec mjpeg -video_size 1920x1080 -framerate 30
       -i video="FHD Camera":audio="Microphone (FHD Camera Microphone)"
       -map 0:v -map 0:a -c:v h264_nvenc -preset p5 -cq 18 -g 30 -c:a pcm_s16le  session/raw.mkv
       -map 0:a -ar 16000 -ac 1 -f f32le pipe:1
```

- The prompter's voice follower, VAD and ASR consume the pipe.
- **Recording time = samples received / 16000**, so every mark is stamped on the raw file's audio timeline.
- No separate WASAPI capture and no clock-matching are needed in this mode.
- Spike: the tee works. A 30 s file gave 30.016 s of pipe audio; the 16 ms was AAC priming in
  the test source, which is why raw takes use PCM.
- **MKV, not MP4**, for the raw file: a crash or power loss leaves a playable file (an MP4 without its
  moov atom is lost).
- Video: MJPEG from the camera (the FHD Camera's raw YUYV is 5 fps at 1080p; MJPEG does 60), encoded live
  with NVENC, which is dedicated encoder silicon separate from the CUDA cores whisper uses.
  A **1 s GOP** (`-g 30`) keeps seeking in the editor snappy.
- Audio in the raw file: PCM 48 kHz (lossless, no encoder delay). Final render encodes AAC.
- **Graceful stop:** write `q` to ffmpeg's stdin, so the MKV is finalized with an index.
- Devices are chosen in Settings from the dshow list. The NVIDIA Broadcast camera/mic appear there
  too (background/noise effects applied before capture).

### 5.2 Health monitoring while rolling

| Signal | Source | Pill indicator |
|--------|--------|----------------|
| Recording alive | ffmpeg process + pipe bytes flowing | `● REC mm:ss` (red); grey if stalled > 1 s |
| Dropped frames | ffmpeg `-progress` / stderr `drop=` | small `⚠ drops` if > 0.5% |
| Audio level | pipe PCM RMS | the glow (already designed) |
| Disk space | free space vs bitrate | warn under 10 minutes left |

### 5.3 Without recording

Take Studio's controls (Again/Hold/Edit) also work with **Record off**. The prompter then uses
simple_audio WASAPI capture as in research D-005. No journal is written unless "practice log" is on.

### 5.4 Sync fallback for external recorders (future)

If the video comes from elsewhere (OBS, a phone, a camera), the prompter keeps its own mic
recording, and the offset is found by **audio cross-correlation** of the two tracks.
The marks are then shifted onto the external file's timeline.

## 6. Analysis pass (on Wrap)

Runs on the GPU while the "analyzing…" card shows. Input: raw.mkv, journal, script revisions.

1. **Transcribe** the raw audio (whisper large-v3-turbo, CUDA, `no_context` per window, prior-script
   prompts, word timestamps; Silero VAD speech map). The spike measured a 3 s window at ~60 ms warm, so
   a 4-minute session is expected to take tens of seconds. *Exact figure to be measured.*
2. **Attempt boundaries** from the journal: `resume`..next `hold|flub|wrap`.
3. **Align** each attempt's words to the script revision current at that time. The result is
   (word_id, rt_start, rt_end, confidence) for every read word.
4. **Find the caret word** in each restart attempt (handles run-up reading) and the last cleanly read
   word before each flub.
5. **Snap cuts into silence:**
   - Cut-in = midpoint of the VAD silence before the caret word, or caret_word.start − head_pad (default 120 ms) if there's no gap.
   - Cut-out = the silence after the last good word, or last_word.end + tail_pad (default 200 ms).
   - Never cut inside a VAD speech run unless the splice is marked tight.
6. **Choose takes** (§7) and build the cut list.
7. **Raise review flags:**
   - misreads (heard ≠ script);
   - low-confidence words;
   - unmarked restarts (the same words read twice in one attempt, i.e. you restarted without pressing
     anything; the editor offers to cut the first one);
   - long pauses kept inside a take;
   - tight splices;
   - passages with no good take (missing coverage).

The live marks are coarse (a button press lags speech by a few hundred ms). The analysis pass
makes cuts word-accurate. If analysis is unavailable (no GPU, model missing), the editor falls back
to live marks with conservative pads and says so.

## 7. Take selection (the assembly rule)

**Input:** final script revision words W1..Wn (in order); attempts with aligned word coverage; star/reject marks.

**Default rule:** for each word, use the **latest valid take** that covers it, where:
- *valid* = not rejected, not stale (its words match the final revision), and aligned with confidence ≥ threshold;
- a **starred** take beats later unstarred takes of the same passage.

**Splice economy:** among valid choices, prefer to keep reading inside the same attempt (fewer
cuts). This is a shortest-path problem over words.
- State = (word index, attempt).
- Cost = splices × S + age penalty (older take) + low-confidence penalty.
- Moving to a new attempt is allowed only at a passage boundary, or at a tight-splice caret.

**Contracts the solver must satisfy (become Eiffel postconditions):**
- `covers_every_word`: every word of the final revision appears exactly once in the output sequence.
- `script_order`: output words appear in script order.
- `source_monotone_per_take`: inside one take, rt increases.
- `no_rejected`: no cut-list interval overlaps a rejected attempt.
- `cuts_in_silence`: every cut point lies in a VAD silence, or is flagged tight.
- `floor_is_complement`: the edit floor = raw timeline minus the cut list; nothing is lost.

If a word has no valid take, the passage is flagged **missing**. The editor offers "record pickup"
(§8.4) or "use best available stale/low-confidence take."

## 8. The Edit Floor (review editor)

A simple_widgets window that opens after analysis (or later from `File → Open session`).

### 8.1 Layout

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ episode-12  · raw 3:41 · final 3:05 · 27 attempts · 3 flags        [Render ▶]  │
├───────────────────────────────┬────────────────────────────────────────────────┤
│ SCRIPT (final revision)       │ PREVIEW                                        │
│ 6  …stays right next to your  │   [ video frame / player ]                     │
│    camera.          T1 ✓      │   ◀◀ word  ◀ 40ms  ▶ play joint  40ms ▶ word ▶▶ │
│ 7  So when you read your      │                                                │
│    text…   T1 ✗ T2 ✗ T3 ✓     │ TAKE DETAIL  sentence 7 · T3 · 01:58.2–02:04.9 │
│ 12 …next to your webcam ✎r2   │   heard: "so when you read your text you…"     │
│    T1 ⌀stale  T2 ✓            │   cut-in 01:58.21 (silence)  cut-out 02:04.93  │
│ 15 …over there ⚑ misread      │                                                │
├───────────────────────────────┴────────────────────────────────────────────────┤
│ TIMELINE  ▓▓▓▓░░▓▓▓▓▓▓░▓▓▓▓▓▓▓▓░░░▓▓▓▓  (▓ kept  ░ floor  ▲ flags)              │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Actions
- Click a take chip to choose it for that passage (re-solves the neighbors).
- Play a take; play a joint (±2 s around a splice); play the whole cut from here.
- Nudge cut-in/out by one word or by 40 ms; "snap to silence".
- Accept/dismiss flags; "cut the first read" on an unmarked restart.
- Restore anything from the floor (the floor is a list of intervals, playable).
- Edit the caption text of a passage without changing the take (e.g. fix punctuation).
- Jump-cut cosmetics (per joint or global): none (default) · **punch-in** (alternate 100% / 108%
  zoom at each joint, the standard YouTube way to hide jump cuts) · short crossfade (frames).

### 8.3 Preview approach
- **v1:** ffplay child window for the take or joint ranges (`-ss`, `-t`). Simple, frame-exact enough for review.
- **v2:** embedded frame view (ffmpeg decodes JPEG frames into a SW image) + system audio. Deferred.

### 8.4 Pickups
"Record pickup" for a flagged passage reopens the prompter on just that passage. It records
`pickup-01.mkv` with its own journal slice, and the solver can then choose takes across files.
The cut list carries a source-file index.

### 8.5 Render
One ffmpeg pass:
- `filter_complex` with per-interval `trim`/`atrim` + `setpts`/`asetpts`;
- 20 ms `afade` in/out at each joint (no clicks);
- optional punch-in `scale/crop` per interval;
- `concat`;
- h264_nvenc (or hevc/av1_nvenc) + AAC.

Spike: 3 intervals, 20.4 s of 720p output in **1.05 s**, frame-accurate at every joint.
Long cut lists are written to a filter script file (`-filter_complex_script`) to avoid command-line limits.

**Outputs** (next to the raw file, never overwriting it):

| File | Content |
|------|---------|
| `NAME.final.mp4` | The assembled video |
| `NAME.final.srt` | Captions from the **final script text**, timed by the word alignment mapped through the cut list (accurate, free captions) |
| `NAME.final.vtt` | Same, WebVTT |
| `NAME.chapters.txt` | YouTube chapter list from Markdown headings + Note marks (`00:00 Intro`…) |
| `NAME.edl` / `NAME.fcpxml` / `NAME.otio` | Edit decision list for Resolve / Premiere / Final Cut, referencing raw.mkv (finish elsewhere) |
| `NAME.floor.mp4` (optional) | Everything that hit the floor, in order: the blooper reel |

## 9. Session files and formats

### 9.1 Folder layout

```
episode-12.take/
  session.toml           -- devices, settings snapshot, versions, created
  raw.mkv                -- the recording (never modified)
  script/
    r1.md  r2.md …       -- immutable revisions
    words.json           -- word ids ↔ revisions (id, text, rev_added, rev_removed)
  journal.jsonl          -- append-only live event log (source of truth)
  review.srt             -- marks as subtitles on raw.mkv (open raw.mkv in VLC to see them)
  analysis/
    words_heard.json     -- aligned words (word_id, rt_start, rt_end, conf, attempt)
    speech_map.json      -- VAD speech/silence runs
    flags.json
  cut.json               -- the chosen takes + cut list (what the editor edits)
  out/                   -- final.mp4, .srt, .vtt, chapters.txt, .edl, .fcpxml, .otio, floor.mp4
```

### 9.2 Why not SRT as the source of truth
SRT is a caption format: index, time range, free text. It can't carry structured data (word ids,
revisions, attempt links) without ad-hoc parsing of the text. So:
- the **journal (JSONL)** is the truth;
- **cut.json** is the editable decision;
- **SRT is exported twice:** `review.srt` (marks over the raw video, for eyeballing in any player)
  and `final.srt` (real captions).

The SRT companion idea is kept, as a view.

### 9.3 Journal (JSONL, one event per line, flushed per line)

```json
{"t":"session_start","rt":0.000,"wall":"2026-10-05T14:02:11-04:00","script_rev":1,"mode":"tracking"}
{"t":"resume","rt":2.004,"caret":"w0001","rev":1}
{"t":"align","rt":8.250,"word":"w0019","conf":0.93}
{"t":"flub","rt":102.310,"word":"w0141","by":"clicker"}
{"t":"rewind_to","rt":102.312,"caret":"w0133","reason":"again_default"}
{"t":"count_in","rt":102.320,"secs":2}
{"t":"resume","rt":104.330,"caret":"w0133","rev":1}
{"t":"hold","rt":171.020,"by":"hotkey"}
{"t":"edit","rt":178.900,"from_rev":1,"to_rev":2,"range":["w0201","w0201"],"old":"notch","new":"webcam","new_ids":["w0201b"]}
{"t":"resume","rt":181.400,"caret":"w0196","rev":2}
{"t":"star","rt":190.100}
{"t":"note","rt":200.000,"text":"Part 2"}
{"t":"wrap","rt":221.700}
```

`align` events are sampled (≤ 4/s) for recovery and fallback; analysis recomputes alignment from audio.

### 9.4 review.srt (generated)

```
12
00:01:42,310 --> 00:01:44,330
✗ FLUB at "read your text" → again from "So when you" (count-in 2 s)

19
00:02:58,900 --> 00:03:01,400
✎ EDIT r1→r2: "notch" → "webcam"
```

### 9.5 cut.json (abridged)

```json
{"final_rev":2,"sources":["raw.mkv"],
 "intervals":[{"src":0,"in":2.180,"out":101.950,"words":["w0001","w0132"],"attempt":1},
              {"src":0,"in":104.910,"out":170.880,"words":["w0133","w0195"],"attempt":2,"tight":false}],
 "cosmetics":{"jump_cut":"punch_in","punch_scale":1.08},
 "floor_seconds":36.4}
```

### 9.6 Recorder backends
- **ffmpeg (default):** §5.1.
- **OBS (future):** start/stop via obs-websocket; marks synced by audio cross-correlation (§5.4).
  For people who already have scenes, lower thirds and so on in OBS.

## 10. Architecture (Eiffel)

### 10.1 SCOOP processors

```
 GUI processor (pill, Edit Floor)        RECORDER processor (separate)          ANALYZER processor (separate)
 ─────────────────────────────────        ───────────────────────────────        ────────────────────────────
 TAKE_SESSION_CONTROLLER                  FFMPEG_CAPTURE (owns ffmpeg child)      SESSION_ANALYZER
 PROMPTER_PILL states                     PCM pipe reader → VOICE_FRAME           whisper full pass, alignment,
 hotkeys / clicker / mouse                VAD + rolling ASR → HEARD_WORDS         silence snapping, flags
 drains RECORDER_SLOT each tick  ◄──────  deposits into RECORDER_SLOT (values)    → writes analysis/*.json
 writes JOURNAL (append, flush)           accepts: prompt_text, stop               (then GUI loads)
```

- Same proven pattern as simple_chat/simple_taskman: values cross processors; GUI never waits.
- All blocking C (pipe read, whisper) is `C blocking inline`.
- The journal is written on the GUI processor only, in rt order.
- rt is taken from the latest VOICE_FRAME sample count, plus the elapsed QPC since that frame for sub-frame precision.

### 10.2 Classes (library `simple_prompter`, no GUI dependency unless noted)

| Class | Responsibility | Key contracts |
|-------|----------------|---------------|
| `SCRIPT_REVISION` | Immutable words + passages of one revision | `words_ids_unique`, `passages_partition_words` |
| `SCRIPT_HISTORY` | Revision chain; `apply_edit (range, new_text): SCRIPT_REVISION` | `revision_count_increased`, `untouched_ids_preserved`, `old_revision_unchanged` |
| `WORD_ID` | Stable identity (value object) | |
| `TAKE_JOURNAL` | Append-only event log + JSONL I/O + replay | `rt_non_decreasing`, `append_only: old count + 1 = count` |
| `TAKE_EVENT` (+ descendants FLUB, HOLD, RESUME, EDIT, STAR…) | One mark | `rt_non_negative` |
| `ATTEMPT` | Derived reading interval + covered words | `rt_in < rt_out` |
| `ATTEMPT_BUILDER` | Journal (+ alignment) → attempts | `attempts_disjoint_in_rt`, `ordered` |
| `RESTART_POLICY` | Default caret after Again; caret stepping | `caret_in_revision` |
| `TAKE_SOLVER` | §7 shortest path → CUT_LIST | `covers_every_word`, `script_order`, `no_rejected`, `floor_is_complement` |
| `CUT_LIST` | Intervals + mapping rt ↔ output time | `intervals_ordered_in_output`, `total_duration = Σ` |
| `SILENCE_SNAPPER` | Moves cut points into VAD gaps | `cut_in_silence_or_flagged_tight` |
| `CAPTION_BUILDER` | Final-revision words + cut-mapped times → SRT/VTT | `cues_non_overlapping`, `text_matches_final_revision` |
| `EDL_WRITER` (CMX3600 / FCPXML / OTIO) | Interchange | |
| `REVIEW_SRT_WRITER` | Marks → review.srt | |
| `FFMPEG_CAPTURE` | Build/launch capture command, stream PCM, graceful stop | `running implies pipe_open` |
| `FFMPEG_RENDER_PLAN` | CUT_LIST + cosmetics → filter script + args | `one_trim_pair_per_interval` |
| `SESSION_ANALYZER` | §6 pipeline | |
| `TAKE_SESSION_CONTROLLER` | The §4.1 state machine; maps actions → events | `state_transitions_legal` (table-driven), `recording implies journal_open` |
| *(app)* `PILL_TAKE_VIEW`, `REWIND_BROWSER`, `INLINE_SCRIPT_EDITOR`, `EDIT_FLOOR_WINDOW`, `CLICKER_INPUT` | UI | |

### 10.3 Testability
- Everything from `SCRIPT_HISTORY` to `CAPTION_BUILDER` is pure Eiffel and runs headless.
- Test fixtures:
  - the Moody reel script (has a repeated "So when you", a natural ambiguity test);
  - synthetic journals: cough + Again, edit + re-read, run-up restart, star of an older take, reject, unmarked restart, missing coverage.
- Render tests use the synthetic testsrc + TTS source from the spike, so they never need a camera.
- Frame-accuracy assertion: burn the pts clock in, extract the joint frames, OCR or pixel-compare.

## 11. Requirements

### 11.1 Functional
| ID | Requirement | Priority | Acceptance |
|----|-------------|----------|-----------|
| FR-T01 | One-press **Again** holds and restarts the current passage with count-in while recording continues | MUST | Cough test: raw has one continuous file; final has one clean read of the sentence |
| FR-T02 | **Hold → browse → pick any word → Go** | MUST | Caret lands on the clicked word; restart from mid-sentence works |
| FR-T03 | Clicker, foot pedal (key combos), global hotkeys and pill mouse all drive the same actions | MUST | Each surface completes the cough test |
| FR-T04 | Bare clicker keys are captured only while recording | MUST | After Wrap, PageDown works normally in other apps |
| FR-T05 | Inline **Edit** creates a new script revision; untouched word ids are preserved | MUST | `SCRIPT_HISTORY` contracts; final SRT shows the new words |
| FR-T06 | Stale takes (pre-edit) are never chosen automatically | MUST | Solver test |
| FR-T07 | ffmpeg records webcam + mic to MKV (NVENC video, PCM audio) and tees 16 kHz audio to the prompter | MUST | Kill the app mid-recording: raw.mkv still plays |
| FR-T08 | All marks are stamped in recording time | MUST | review.srt events line up with audible events in VLC within 100 ms |
| FR-T09 | Journal is append-only and flushed per event; session recoverable after a crash | MUST | Kill during READING → reopen → Edit Floor works |
| FR-T10 | Analysis pass refines cuts to word boundaries inside silences | MUST | No audible clipped words on 10 test joints |
| FR-T11 | Take solver: latest valid take wins; star overrides; reject excludes; fewest splices | MUST | §7 postconditions as tests |
| FR-T12 | Edit Floor shows passages with take chips; choose take, nudge, play joint, restore from floor | MUST | |
| FR-T13 | One-pass NVENC render with click-free joints | MUST | Frame-accurate joints (spike method) |
| FR-T14 | Captions from final script text, timed through the cut list | MUST | Caption drift ≤ 150 ms vs speech |
| FR-T15 | review.srt companion for the raw file | SHOULD | Opens in VLC |
| FR-T16 | Flags: misread, low confidence, unmarked restart, tight splice, missing coverage, long pause | SHOULD | Each fixture triggers its flag |
| FR-T17 | EDL / FCPXML / OTIO export | SHOULD | Resolve imports the EDL and the cuts match |
| FR-T18 | Chapters from headings + Note marks | SHOULD | |
| FR-T19 | Punch-in jump-cut cosmetic | SHOULD | |
| FR-T20 | Pickups across multiple files | COULD | |
| FR-T21 | Voice commands with wake phrase, rail and silent confirm (see F-02) | DEFERRED (2026-10-05) | Not in current build |
| FR-T22 | Blooper reel (floor.mp4) | COULD | |
| FR-T23 | OBS backend + cross-correlation sync | COULD | |

### 11.2 Non-functional
| ID | Requirement | Target |
|----|-------------|--------|
| NFR-T01 | Again → pill frozen | ≤ 50 ms (GUI-local; no worker round trip) |
| NFR-T02 | Recording never interrupted by prompter actions | 0 gaps; dropped frames < 0.5% |
| NFR-T03 | Analysis time | ≤ 25% of recording length on the 5070 Ti (to be measured) |
| NFR-T04 | Render time, 1080p | ≤ 30% of final length with NVENC (720p spike: ~5%) |
| NFR-T05 | Raw is never modified; every output reproducible from raw + journal + cut.json | by construction |
| NFR-T06 | Disk | raw 1080p30 bitrate to be measured; warn under 10 minutes left |

## 12. Ecosystem changes this feature needs

| Library | Change | Why |
|---------|--------|-----|
| **simple_process** | Binary, non-accumulating streaming read (MANAGED_POINTER chunks); `write_input` to stdin | PCM pipe; graceful `q`. Today `read_available_output` decodes UTF-8 and accumulates (simple_async_process.e:208-229) and there's no stdin write |
| **simple_ffmpeg** | dshow device listing/options; capture command builder; `-progress` parsing; filter-script render builder | Currently probe/transcode/frames only (README) |
| **simple_speech** | Full-file word timestamps + VAD speech map (already needed by research D-004) | Analysis pass |
| **simple_shell** | Pill state visuals (expand, amber, REC dot), focusable pill for HELD/EDITING; Raw Input device id (investigate) | Controls |
| **simple_widgets** | Edit Floor widgets: take chips, timeline strip | Editor |

## 13. Risks

| ID | Risk | L | I | Mitigation |
|----|------|---|---|-----------|
| R-T1 | Pipe back-pressure: if the prompter stops reading, ffmpeg blocks and drops frames | MED | HIGH | Recorder processor does nothing but read+deposit; ring buffer; health indicator; test with an artificial GUI stall |
| R-T2 | A/V drift in dshow capture over long takes | MED | MED | `-rtbufsize`, MJPEG, PCM; measure a 30-minute take; `aresample=async=1` if needed |
| R-T3 | Alignment confusion on repeated phrases → wrong take chosen | MED | MED | Journal caret gives the intended position; analysis searches near it; editor makes it easy to switch |
| R-T4 | Bare-key capture leaks (PageDown dead in other apps after a crash) | LOW | MED | Unregister on every exit path + on process start (stale cleanup); never outside a session |
| R-T5 | Mid-sentence splices sound unnatural | MED | LOW | Default restarts at passage starts; run-up reading; tight-splice flag; crossfade option |
| R-T6 | Editing during HELD makes the follower lose place | LOW | MED | Caret re-anchors at the edited passage start with high confidence |
| R-T7 | Webcam MJPEG decode + NVENC + whisper contend | LOW | MED | NVENC is separate silicon; whisper ~25% duty; measure during S-1 |
| R-T8 | Scope: editor feature creep | HIGH | MED | v1 editor = choose/nudge/play/render only; everything else via EDL to Resolve |

## 14. Delivery phases

| Phase | Contents | Proof |
|-------|----------|-------|
| T-0 Spikes | ffmpeg dshow live capture + tee into an Eiffel reader (needs the simple_process binary read); 30-min drift test | Pasted ffprobe + drift numbers |
| T-1 Live marking | Session controller, journal, Again/Hold/Go/browse/pick, clicker + hotkeys, review.srt | Cough test in VLC |
| T-2 Assembly | Attempt builder, take solver (live marks only), render plan, NVENC render, captions | First automatic final.mp4 |
| T-3 Precision | Analysis pass (whisper full + silence snapping + flags) | 10-joint listening test |
| T-4 Edit Floor | Review window, take chips, nudge, joints, restore, EDL export | Larry edits a real episode |
| T-5 Live edits | Inline editor, revisions, stale-take logic | Edit-and-re-read test |
| T-6 Extras | Punch-in, chapters, pickups, voice commands, floor reel, OBS backend | |

T-1/T-2 deliberately work **without** the GPU analysis (live marks + pads), so the feature is
useful before T-3 lands.

## 15. Open questions for Larry

**DECIDED 2026-10-05 (Larry: "use defaults")** for Q1-Q6:
| Q | Decision |
|---|----------|
| 1 Passage unit | **Sentence** (configurable later to paragraph/line) |
| 2 Control device | **Keyboard hotkeys + mouse on the pill**; any key-sending clicker/pedal works through the same bindings (§4.3) |
| 3 Camera / mic | **"FHD Camera" + "Microphone (FHD Camera Microphone)"**, MJPEG 1080p; NVIDIA Broadcast devices selectable in Settings |
| 4 Resolution / fps | **1080p30** |
| 5 Jump cuts | **Plain cuts** (punch-in and crossfade available as options) |
| 6 Edit Floor v1 | **Minimal**: choose take, nudge, play joints, restore from floor, render; anything fancier via EDL to Resolve |
| 7 Voice commands | No (see below) |

Original questions, kept for the record:

1. **Passage unit:** default to sentence, or paragraph (fewer, more natural splices)?
2. **Clicker:** do you have one (model)? Or a foot pedal? This decides the default mapping.
3. **Camera/mic:** FHD Camera + its mic, or NVIDIA Broadcast devices (noise removal; Broadcast also has an
   Eye Contact effect, which could matter for a prompter)?
4. **Resolution/fps default:** 1080p30 (recommended) or 1080p60?
5. **Jump cuts:** plain, punch-in, or ask per session?
6. **Edit Floor depth:** is choose/nudge/render enough for v1, with Resolve for anything fancier?
7. ~~**Voice commands:** worth it, or is the clicker enough?~~ **DECIDED 2026-10-05 (Larry): no voice
   commands for now.** Controls are keyboard (hotkeys), mouse on the pill, and key-sending devices
   (presenter clicker, foot pedal). Voice *following* (VAD/ASR scrolling) and the whisper analysis
   pass are unaffected. F-02 is deferred, not deleted.

## Appendix A: Verified on this machine (2026-10-05)

- ffmpeg 8.0 with h264/hevc/av1 NVENC; dshow sees FHD Camera, NVIDIA Broadcast camera, OBS
  Virtual Camera, and three microphones (spike-ffmpeg-record-splice.md).
- FHD Camera does MJPEG 1920x1080 @ up to 60 fps; YUYV 1080p only 5 fps.
- Frame-accurate trim/concat splice with 20 ms audio fades; 20.4 s of 720p rendered in 1.05 s on NVENC.
- One ffmpeg process can write the recording and stream 16 kHz mono PCM to stdout at once.
- CUDA whisper large-v3-turbo: 53-63 ms per warm 3 s window; Silero VAD drops pure noise in ~7 ms;
  `no_context=true` required for overlapping windows; prompt only with already-read text
  (spike-cuda-whisper.md).
- **Not yet verified:** live dshow capture of the real camera (camera was deliberately not turned on);
  long-take A/V drift; full-session analysis time; Raw Input clicker discrimination.
