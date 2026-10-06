# PARSED REQUIREMENTS: simple_prompter

Date: 2026-10-05. Inputs:
- research/01-07 + REFERENCES;
- spec/F-01-TAKE-STUDIO.md (decided 2026-10-05);
- spec/F-02-VOICE-COMMANDS.md (**DEFERRED**, not in scope);
- evidence/ (video analysis; CUDA whisper, ffmpeg record/splice and voice-command spikes).

## Problem Summary
Larry records explainer and demo videos and speaks on calls. He needs his script right under the
webcam, scrolling with his voice and invisible to screen capture. When he flubs, he needs to back up
and re-read without stopping the camera, change words on the fly, and get a finished video
with the bad takes cut out automatically. Everything runs locally on his RTX 5070 Ti, in Eiffel on
the simple_* ecosystem.

## Scope

### In Scope
- **Prompter:** borderless, topmost, non-activating, capture-excluded pill at the camera; monospace
  centered text; read lines fade; smooth time-based scrolling; speed, size, width, lines, opacity, position.
- **Follow modes:** Constant, Voice-gated (Silero VAD), Tracking (CUDA whisper rolling window + forward-only aligner + spring follower).
- **Scripts:** .txt / .md (Markdown stripped; headings become sections; `[CUE]` text excluded from reading).
- **Controls:** global hotkeys (modifier required), mouse on the pill, key-sending clicker/foot pedal.
- **Take Studio:**
  - Again / Hold / browse / pick word / Go;
  - inline script edit (revisions);
  - Star / Reject / Note / Skip / Wrap / Abort.
- **Recording:** ffmpeg single capture (dshow MJPEG 1080p30 + mic). MKV with NVENC H.264 video and
  PCM audio, plus a 16 kHz mono f32 tee to the prompter. Marks are stamped in recording time.
- **Journal:** append-only JSONL, flushed per event; crash-recoverable.
- **Analysis pass:** full-recording whisper with word timestamps; alignment to revisions; cuts snapped into silence; flags.
- **Take solver:** latest valid take, star overrides, reject excludes, fewest splices.
- **Edit Floor v1:** take chips, choose, nudge, play joints (ffplay), restore, render.
- **Outputs:** final.mp4 (NVENC), final.srt/.vtt from the final script, chapters, EDL, review.srt.
- **Upstream library work** (in the owning libraries):
  - simple_speech: CUDA variant, VAD, rolling stream, word timestamps;
  - simple_audio: 16 kHz, selectany, packets;
  - simple_shell: capture exclusion, panel, DPI/monitors, multi-id hotkeys;
  - simple_process: binary pipe, stdin;
  - simple_ffmpeg: dshow capture builder, render plan.

### Out of Scope
- Voice commands (F-02, deferred by Larry 2026-10-05).
- macOS/Linux; cloud services; screen recording; multi-camera; B-roll/titles (use the EDL in Resolve).
- Mirror/flip mode for beam-splitter hardware; phone remote; DOCX/PDF import; Ollama helpers (later).
- Embedded video player in the Edit Floor (v1 uses ffplay); OBS backend; pickups across files (COULD).

## Functional Requirements

### Prompter (research/03)
| ID | Requirement | Priority | Source | Acceptance |
|----|-------------|----------|--------|------------|
| FR-001 | Borderless, topmost, non-activating overlay, no taskbar/Alt-Tab | MUST | r03 | Typing elsewhere keeps focus |
| FR-002 | Default top-center of primary monitor | MUST | r03 | Fresh install |
| FR-003 | Excluded from capture (WDA_EXCLUDEFROMCAPTURE; WDA_MONITOR fallback) | MUST | r03 | OBS/Teams/Snipping Tool show desktop |
| FR-004 | Dark rounded panel, monospace centered, N lines (default 3), column width | MUST | r03 | Matches video frames |
| FR-005 | Read text fades/dims upward; current line full brightness | MUST | r03 | Visual |
| FR-006 | Sub-pixel smooth time-based scroll | MUST | r03 | No stepping at 120 wpm on 60 Hz |
| FR-007 | Adjustable size/width/lines/opacity/color; drag; per-monitor positions persisted | MUST | r03 | Restart round trip |
| FR-008 | Audio-reactive glow | SHOULD | r03 | Tracks level |
| FR-009 | Camera calibration per monitor | SHOULD | r03 | External webcam on monitor 2 |
| FR-010 | Countdown; elapsed / remaining estimate | SHOULD | r03 | |
| FR-020 | Live 16 kHz mono capture from chosen device (non-recording mode) | MUST | r03 | Level meter moves |
| FR-021 | Voice-gated mode: scroll while VAD says speech | MUST | r03 | Stop ≤ 250 ms, resume ≤ 150 ms |
| FR-022 | Constant mode | MUST | r03 | |
| FR-023 | Tracking mode: position follows spoken word | SHOULD | r03 | ≤ 1 line error over 5 min |
| FR-024 | Ad-libs don't move position | SHOULD | r03 | 20 s off-script → position put |
| FR-025 | Speed adapts to measured rate between ASR updates | SHOULD | r03 | No jumping |
| FR-026 | Silero VAD, not raw volume | SHOULD | r03 | Keyboard clicks don't scroll |
| FR-040 | Open .txt/.md; headings → sections | MUST | r03 | |
| FR-041 | Edit script; reload on file change | SHOULD | r03 | |
| FR-042 | Global hotkeys, modifier required | MUST | r03 | Works while OBS focused |
| FR-043 | Hover pause (off while recording), wheel scroll, click | SHOULD | r03, F-01 §4.3 | |
| FR-044 | `[CUE]` markers dimmed, not spoken | COULD | r03 | |

### Take Studio (F-01 §11)
| ID | Requirement | Priority | Source | Acceptance |
|----|-------------|----------|--------|------------|
| FR-T01 | One-press Again: hold + restart current sentence + count-in, recording continues | MUST | F-01 | Cough test |
| FR-T02 | Hold → browse → pick any word → Go | MUST | F-01 | Mid-sentence restart |
| FR-T03 | Hotkeys, mouse, clicker/pedal (key-sending) drive the same actions | MUST | F-01 (+ no voice) | Each surface passes cough test |
| FR-T04 | Bare clicker keys captured only while recording | MUST | F-01 | PageDown normal after Wrap |
| FR-T05 | Inline edit → new revision; untouched word ids preserved | MUST | F-01 | Contracts; final SRT |
| FR-T06 | Stale (pre-edit) takes never auto-chosen | MUST | F-01 | Solver test |
| FR-T07 | ffmpeg MKV (NVENC + PCM) + 16 kHz tee | MUST | F-01 | Kill app → raw.mkv plays |
| FR-T08 | Marks in recording time | MUST | F-01 | review.srt within 100 ms |
| FR-T09 | Journal append-only, flushed per event; crash recovery | MUST | F-01 | Kill → reopen → Edit Floor |
| FR-T10 | Analysis refines cuts to word boundaries in silence | MUST | F-01 | 10-joint listening test |
| FR-T11 | Solver: latest valid wins; star; reject; fewest splices | MUST | F-01 | Postconditions as tests |
| FR-T12 | Edit Floor: chips, choose, nudge, play joint, restore | MUST | F-01 | |
| FR-T13 | One-pass NVENC render, click-free joints | MUST | F-01 | Frame-accurate joints |
| FR-T14 | Captions from final script via cut list | MUST | F-01 | Drift ≤ 150 ms |
| FR-T15 | review.srt | SHOULD | F-01 | VLC |
| FR-T16 | Flags (misread, low conf, unmarked restart, tight splice, missing, long pause) | SHOULD | F-01 | Fixture per flag |
| FR-T17 | EDL / FCPXML / OTIO | SHOULD | F-01 | Resolve import |
| FR-T18 | Chapters from headings + notes | SHOULD | F-01 | |
| FR-T19 | Punch-in cosmetic (default off: plain cuts decided) | SHOULD | F-01 §15 | |
| FR-T20 | Pickups across files | COULD | F-01 | |
| FR-T21 | Voice commands | DEFERRED | F-02 | n/a |
| FR-T22 | Blooper reel | COULD | F-01 | |
| FR-T23 | OBS backend | COULD | F-01 | |

## Non-Functional Requirements
| ID | Requirement | Category | Measure | Target |
|----|-------------|----------|---------|--------|
| NFR-001 | Pause latency | PERFORMANCE | ms | ≤ 250 |
| NFR-002 | Tracking update latency | PERFORMANCE | ms p95 | ≤ 700 (spike: ~250 step + ~60 decode) |
| NFR-003 | GUI frame time during ASR | PERFORMANCE | ms p99 | ≤ 16.7; no stall > 50 ms |
| NFR-004 | GPU memory | RESOURCE | MB | ≤ 2,000 (model 573 MB) |
| NFR-005 | CPU, Voice-gated | RESOURCE | % core | ≤ 5 |
| NFR-006 | Privacy | SECURITY | network calls | 0 |
| NFR-007 | Startup to first frame | PERFORMANCE | s | ≤ 1 (model warms in background) |
| NFR-008 | Works without GPU | PORTABILITY | | CPU fallback; Voice-gated needs no ASR |
| NFR-009 | Per-monitor DPI | USABILITY | | Crisp 100-200% |
| NFR-010 | One-hour stability | RELIABILITY | MB growth | ≤ 50, no crash |
| NFR-T01 | Again → pill frozen | PERFORMANCE | ms | ≤ 50 (GUI-local) |
| NFR-T02 | Recording never interrupted | RELIABILITY | gaps / drops | 0 / < 0.5% |
| NFR-T03 | Analysis time | PERFORMANCE | % of rec length | ≤ 25 |
| NFR-T04 | Render 1080p | PERFORMANCE | % of final length | ≤ 30 (720p spike ≈ 5) |
| NFR-T05 | Raw never modified; outputs reproducible from raw + journal + cut.json | INTEGRITY | | by construction |

## Constraints (simple_* First)
| ID | Constraint | Type |
|----|------------|------|
| C-001 | simple_* over ISE/Gobo; fix gaps in the owning library | ECOSYSTEM |
| C-002 | SCOOP (`concurrency=scoop`), never `thread` | TECHNICAL |
| C-003 | Void-safe (`void_safety=all`) | TECHNICAL |
| C-004 | No Python in the product | ECOSYSTEM |
| C-005 | Inline C for Win32; vendored whisper/ggml/ffmpeg stay as DLLs/exes | TECHNICAL |
| C-006 | Blocking externals on a SCOOP worker are `C blocking inline` | TECHNICAL |
| C-007 | Mutable C header statics `__declspec(selectany)` | TECHNICAL |
| C-008 | F_code via ec.sh; tests via TEST_SET_BASE (never `check`) | TECHNICAL |
| C-009 | **Invariants O(1)**: no MML models or `across` over data in invariants (oracle rule 2026-09-11) | TECHNICAL |
| C-010 | **Every test/app target declares its own `<option><assertions>`**: extending targets don't inherit them (oracle gotcha, simple_taskman 2026-10-05) | TECHNICAL |
| C-011 | Windows 10 2004+; Windows 11 primary | PLATFORM |
| C-012 | US English | ECOSYSTEM |

## Decisions Already Made
| ID | Decision | From |
|----|----------|------|
| D-001 | Hybrid follower; modes Tracking / Voice-gated / Constant | r04 |
| D-002 | whisper.cpp CUDA (large-v3-turbo-q5_0), base.en CPU fallback; no_context=true; prior-text prompt only | r04 + spike |
| D-003 | In-process whisper via simple_speech on a SCOOP worker | r04 |
| D-004 | Speech capabilities upstream in simple_speech | r04 |
| D-005 | Harden simple_audio (16 kHz, packets, selectany) | r04 |
| D-006 | SCOOP worker + non-blocking slot; values cross processors | r04 |
| D-007 | Opaque popup + display affinity (no UpdateLayeredWindow) | r04 |
| D-008 | Cairo rendering; cached text strip; time-based motion; 16 ms timer first | r04 |
| D-009 | Forward-biased bounded-window fuzzy aligner, pure Eiffel | r04 |
| D-010 | Per-monitor camera calibration; per-monitor-v2 DPI | r04 |
| D-011 | .txt/.md; TOML settings in %APPDATA%\simple_prompter | r04 |
| D-012 | Multi-id hotkeys extracted from OCR_HOTKEY, modifier interlock | r04 |
| D-013 | CPU default + optional GPU pack for public; Larry uses installed CUDA | r04 |
| D-014 | Library (headless core) / app split | r04 |
| D-T01 | Continuous recording; retakes are marks, never stops | F-01 |
| D-T02 | ffmpeg is the single capture; PCM tee gives recording time by construction | F-01 + spike |
| D-T03 | MKV + PCM raw; 1 s GOP | F-01 + spike |
| D-T04 | JSONL journal is truth; SRT is an exported view | F-01 |
| D-T05 | Passage unit = sentence | F-01 §15 (defaults) |
| D-T06 | Controls = hotkeys + mouse + key-sending devices; **no voice commands** | Larry 2026-10-05 |
| D-T07 | Camera = FHD Camera + its mic, MJPEG 1080p30 | F-01 §15 |
| D-T08 | Plain jump cuts (punch-in optional) | F-01 §15 |
| D-T09 | Edit Floor v1 minimal; EDL to Resolve for more | F-01 §15 |

## Innovations to Implement
| ID | Innovation | Design Impact |
|----|------------|---------------|
| I-001 | VAD for motion, ASR for position | `PT_FOLLOWER` with two inputs, one output |
| I-002 | DBC-specified aligner | `PT_ALIGNER` pure Eiffel; contracts = behavior spec |
| I-003 | Already-read script as whisper prompt | Worker accepts `prompt_text` updates |
| I-004 | Camera calibration | Per-monitor geometry in settings |
| I-005 | Capture-invisible by construction | Opaque panel in simple_shell |
| I-006 | Ecosystem lift | Upstream interface specs (§ in 04) |
| I-T1 | Marks in recording time via tee | `PT_RECORDING_CLOCK` = samples/16000 |
| I-T2 | Live marks refined by GPU word alignment | `PT_SESSION_ANALYZER`, `PT_SILENCE_SNAPPER` |
| I-T3 | Take selection as shortest path with contracts | `PT_TAKE_SOLVER` |
| I-T4 | Captions free from script + cut map | `PT_CAPTION_BUILDER` |

## Risks to Address in Design
| ID | Risk | Mitigation Strategy (design) |
|----|------|------------------------------|
| RISK-001 | Capture exclusion fails | Opaque panel; affinity result checked and surfaced (`is_capture_excluded`) |
| RISK-002 | ASR hallucination / overlap | VAD gate; no_context; aligner treats words as noisy evidence |
| RISK-003 | Repeated phrases | Forward bias, bounded window, jump evidence f(N); fixtures |
| RISK-005 | Live audio path | In recording mode the tee replaces WASAPI; WASAPI hardened upstream for practice mode |
| RISK-006 | GUI freeze | SCOOP worker; slot; GUI never queries worker synchronously |
| RISK-007 | Timer jitter | Time-based offsets from QPC clock |
| RISK-008 | Header statics fork | selectany (C-007) |
| RISK-012 | Cold first decode | Warm-up at worker start; Voice-gated usable before ready |
| R-T1 | Pipe back-pressure | Recorder processor only reads + deposits; ring buffer; health |
| R-T2 | A/V drift | MJPEG + PCM + rtbufsize; measured spike T-0 |
| R-T3 | Wrong take on repeats | Journal caret anchors analysis search |
| R-T4 | Bare-key leak | Release on every exit path + stale cleanup at start |
| R-T8 | Editor creep | v1 minimal (D-T09) |

## Use Cases

### UC-001: Read a script on a call (no recording)
**Actor:** Larry. **Precondition:** script file exists; app running.
**Main Flow:**
1. Open script.
2. Pill appears under the camera.
3. Press Ctrl+Alt+Space.
4. Speak; the pill scrolls (mode per settings), pauses on silence.
5. Hide with Ctrl+Alt+H.

**Postcondition:** never visible in the screen share; settings persisted.

### UC-002: Record with retakes (cough)
**Precondition:** camera and mic configured; script open.
**Main Flow:**
1. Record.
2. Count-in, READING.
3. Cough.
4. Again (clicker Back).
5. Pill holds, caret to sentence start, count-in.
6. Re-read.
7. Continue.
8. Wrap.

**Postcondition:** one continuous raw.mkv; journal has flub/rewind/resume; analysis begins.

### UC-003: Change a word mid-session
**Main Flow:**
1. Hold.
2. Edit (Ctrl+Alt+E).
3. Type the replacement.
4. Enter.
5. Revision n+1; caret at sentence start.
6. Go.
7. Re-read.

**Postcondition:** earlier take of that sentence is stale; final captions use the new words.

### UC-004: Restart from an earlier, chosen place
**Main Flow:**
1. Hold.
2. Back ×2 (or click a word, or press a badge digit).
3. Go.
4. Run-up reading allowed.

**Postcondition:** splice at the caret word after analysis.

### UC-005: Review and render
**Precondition:** analysis complete (or fallback to live marks).
**Main Flow:**
1. Edit Floor opens.
2. Check flags.
3. Play joints.
4. Choose / nudge.
5. Render.

**Postcondition:** final.mp4, final.srt/.vtt, chapters, EDL written; raw untouched.

### UC-006: Recover after a crash
**Main Flow:**
1. Reopen the app.
2. It offers to recover the unfinished session.
3. Journal replay + raw.mkv.
4. Analysis.
5. Edit Floor.

**Postcondition:** no reading lost up to the crash instant.

### UC-007: Calibrate camera
**Main Flow:**
1. Settings → Calibrate.
2. Crosshair on the monitor.
3. Drag it to the lens.
4. Save (per monitor).

**Postcondition:** pill anchors just below the lens.
