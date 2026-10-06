# REQUIREMENTS: simple_prompter

## Functional Requirements

### Display (the pill)
| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-001 | Borderless, topmost, non-activating overlay with no taskbar/Alt-Tab entry | MUST | Typing in another app keeps focus while the prompter scrolls; not in Alt-Tab |
| FR-002 | Default position: horizontally centered, flush with top of the monitor that holds the camera | MUST | Fresh install opens top-center of primary monitor |
| FR-003 | Excluded from screen capture (WDA_EXCLUDEFROMCAPTURE; WDA_MONITOR fallback pre-2004) | MUST | OBS display capture, Teams share, Snipping Tool show the desktop behind it |
| FR-004 | Dark rounded panel; monospace, center-aligned text; configurable lines visible (default 3) and column width | MUST | Matches `evidence/video_frames` look |
| FR-005 | Read text fades and dims toward the top; current line full brightness | MUST | Visual check |
| FR-006 | Sub-pixel smooth scrolling at display rate | MUST | No visible stepping at 120 wpm on a 60 Hz panel |
| FR-007 | Adjustable font size, width, lines, opacity, text color; drag to reposition; positions remembered per monitor | MUST | Settings survive restart |
| FR-008 | Audio-reactive glow behind text driven by voice level | SHOULD | Glow intensity tracks speech, flat in silence |
| FR-009 | Camera calibration: user drags a marker onto the lens; prompter snaps under it | SHOULD | Works with external webcam on a second monitor |
| FR-010 | Countdown before start; elapsed / remaining-time estimate | SHOULD | |

### Voice following
| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-020 | Live mic capture from a chosen input device, 16 kHz mono float | MUST | Device picker lists WASAPI capture endpoints; level meter moves |
| FR-021 | Mode **Voice-gated**: scroll at set speed only while VAD says speech | MUST | Stops <= 250 ms after speech ends; resumes <= 150 ms after speech starts |
| FR-022 | Mode **Constant**: classic fixed-speed scroll | MUST | |
| FR-023 | Mode **Tracking**: position follows the spoken word via ASR + alignment | SHOULD | Error <= 1 line over a 5-minute read; recovers within 2 s after a skipped paragraph |
| FR-024 | Tracking is forward-biased: ad-libs and filler words do not move the position | SHOULD | Off-script talking for 20 s leaves the position put |
| FR-025 | Tracking adapts scroll speed to measured speaking rate between ASR updates | SHOULD | Smooth motion, no jumping between updates |
| FR-026 | Noise robustness: Silero VAD (not raw volume) decides "speech" | SHOULD | Keyboard clicking (like the reel's audio) does not scroll |

### Script and control
| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-040 | Open .txt and .md (Markdown stripped to plain text; headings kept as section breaks) | MUST | |
| FR-041 | Edit script in a simple editor window; reload on file change | SHOULD | |
| FR-042 | Global hotkeys: play/pause, faster/slower, back/forward line, jump to section, hide/show, click-through toggle; every hotkey needs a modifier | MUST | Hotkeys work while OBS/Zoom has focus; modifier-less rejected |
| FR-043 | Hover pauses; mouse wheel scrolls manually; click toggles pause | SHOULD | |
| FR-044 | Cue markers in script, e.g. `[PAUSE]`, `[SLIDE]`, not spoken, shown dimmed | COULD | |
| FR-045 | DOCX/PDF import | COULD | |
| FR-046 | Local-LLM helpers (tidy, shorten) via Ollama :11435 | COULD | |

## Non-Functional Requirements
| ID | Requirement | Category | Measure | Target |
|----|-------------|----------|---------|--------|
| NFR-001 | Pause latency (speech end to scroll stop) | PERFORMANCE | ms | <= 250 |
| NFR-002 | Tracking update latency (word spoken to position corrected) | PERFORMANCE | ms | <= 700 p95 |
| NFR-003 | GUI frame time while ASR runs | PERFORMANCE | ms | <= 16.7 p99, zero GUI stalls > 50 ms |
| NFR-004 | GPU memory | RESOURCE | MB | <= 2,000 (leaves room for OBS/NVENC and Ollama) |
| NFR-005 | CPU in Voice-gated mode | RESOURCE | % of one core | <= 5 |
| NFR-006 | Privacy | SECURITY | network calls | zero (except optional Ollama on localhost) |
| NFR-007 | Startup to first frame | PERFORMANCE | s | <= 1 (model loads in the background) |
| NFR-008 | Runs without GPU | PORTABILITY | | CPU fallback for Tracking with a smaller model; Voice-gated needs no ASR |
| NFR-009 | Per-monitor DPI correct | USABILITY | | Text crisp at 100-200% scaling, correct on mixed-DPI setups |
| NFR-010 | One-hour session stable | RELIABILITY | | No leak growth > 50 MB, no crash |

## Constraints
| ID | Constraint | Type | Immutable? |
|----|------------|------|------------|
| C-001 | SCOOP-compatible (`concurrency=scoop`), never `thread` | TECHNICAL | YES |
| C-002 | Prefer simple_* over ISE; fix gaps in the owning simple_* library | ECOSYSTEM | YES |
| C-003 | No Python in the product | ECOSYSTEM | YES |
| C-004 | Inline C externals for Win32 (no separate .c files in Eiffel libs); vendored C libs (whisper, ggml) stay as prebuilt DLLs as simple_speech does today | TECHNICAL | YES |
| C-005 | Blocking externals called from a SCOOP worker are `C blocking inline` | TECHNICAL | YES |
| C-006 | Mutable C statics in shared headers use `__declspec(selectany)` | TECHNICAL | YES |
| C-007 | F_code builds via `ec.sh`; tests via TEST_SET_BASE asserts (finalized `check` is vacuous) | TECHNICAL | YES |
| C-008 | Windows 10 2004+ (capture exclusion), Windows 11 primary | PLATFORM | NO |
| C-009 | US English in all docs | ECOSYSTEM | YES |
