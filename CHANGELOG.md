# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-10-10

### Added
- Publish, in the Last take panel: everything needed to post a take to YouTube, Facebook
  Reels and X, run by the speech worker (about two minutes for a three-minute take; the
  window stays live and shows each stage):
  - The finished final.mp4: the silence before the first word cut to a quarter second,
    the video opening on the thumbnail and dissolving into the picture while the voice
    starts at once (out\thumbnail.jpg or .png, else the first thumbnail_A* image), the last
    frame held and faded to black after the last word, the sound at YouTube's loudness
    (-14 LUFS). The render is kept as "final (before cleanup).mp4", so Publish can run
    again after a new thumbnail.
  - captions.en_US.SRT (the name Facebook Reels wants): captions of what was said, from
    whisper on the finished video, in the script's wording wherever a sentence was read as
    written. Whisper's inventions are left out: words heard in silence ("Thank you." over a
    silent ending) and phrases echoed once too often. The render's captions are kept as
    "final (analyzer original)".
  - Chapters timed to the finished video, one per paragraph that starts at least 10 s after
    the last (YouTube's rule), at most eight.
  - youtube.txt (title, description, chapters, hashtags), facebook.txt (the Reel's
    description) and x.txt (one line to lead the post). The local AI (Ollama on this
    machine's GPU) writes the title, description, hashtags, chapter names, a question for
    Facebook and the X line; without it every part comes from the script.
  - Settings (settings.toml): publish_link (closes the Facebook post), publish_hashtags,
    ollama_url (default http://localhost:11435), ollama_model (empty: the first model
    installed that is not for OCR or embeddings), use_ollama.
  - Thumbnails are still made outside the program, on request.

### Fixed
- The opening line could be cut off (Reel 4 lost "Worthless servant!"): when the aligner
  did not match the first words, the first cut started at the first matched word. The
  video's first cut now starts before speech that runs on, with gaps under a second, from
  up to 3 s before the first matched word.

## [0.4.0] - 2026-10-10

### Changed
- The pill is the whole program. The control window is gone from the screen (it still
  runs the event pump, hidden; `--window` shows it for development). Everything it held
  is now beside the pill, and an icon in the notification area stands for the program.

### Added
- Rails on the pill. Left: one Status button with three lights (microphone, camera,
  voice following: off, OK, needs a look, problem). Right: Quit, Script, Settings,
  Last take. A button whose callout is open is lit.
- Callouts, each its own panel beside the pill and hidden from screen captures like it:
  Status (left), Script and Settings (right), Last take (below). Each has a close button
  and sizes itself to its content; they follow the pill when it moves.
- Tooltips on everything (the rails, the transport bar, every callout control, the
  handle, the side grips), shown after the pointer rests for 450 ms, with a Show
  tooltips switch in Settings to turn them off.
- Recent scripts: the last five, one click to open again, in the Script callout.
- The slide handle: a tab under the pill. Drag it to slide the pill left and right
  only; open callouts come along live.
- Side grips: drag the pill's left or right edge to make it wider or narrower, no
  Shift needed. Shift+drag still moves the pill or sizes it from any edge.
- Drop a script (.md or .txt) on the pill or on the Script callout to open it.
- Tray icon: click it to show or hide the pill (as Ctrl+Alt+H does); right-click for
  Hide/Show the pill, Open a script..., and Quit.
- Needs simple_shell 1.14.0 (panel handles, side grips, drops on panels, tray clicks
  and menu, a window that starts hidden).

## [0.3.6] - 2026-10-10

### Changed
- Sync moves from recording to previews and the render: the raw recording keeps the
  picture as it arrived, so a wrong sync is fixed by changing it and rendering again.
  The render opens the raw file twice (the picture moved by -itsoffset, the sound
  untouched) so every cut trims both at the same instants; previews shift the picture
  in ffplay. The Settings page's value is now where each new take starts.

### Added
- Sync row in the Last take panel: - / + in 10 ms steps (-500 to +1000 ms), Preview
  sync, and Measure. Each take keeps its own value (sync.toml in its folder); every
  change becomes the starting value for the next take.
- Measure (PT_SYNC_MEASURE, PT_SYNC_MEASURER): finds claps in the take's sound and the
  frame where the hands meet in the picture, and sets the sync from them. On today's
  two clap recordings it found 320 ms and 80 ms, within a camera frame of the values
  measured by hand.
- The Last take panel shows the newest take at start, so it can be rendered, previewed
  or measured again after a restart.

## [0.3.5] - 2026-10-10

### Fixed
- Picture and sound out of sync on a virtual camera (OBS Virtual Camera, NVIDIA
  Broadcast): the picture ran about 0.35 s behind the sound (clap test). The camera
  and the microphone were two ffmpeg inputs, each starting its clock at 0, which
  threw away the ~0.5 s between the camera's first frame and the microphone's
  first sound. They are now one input on one clock (-use_video_device_timestamps 0):
  0.11 s behind, which is the time NVIDIA Broadcast and OBS spend on the picture.

### Added
- Picture delay (Settings, `video_delay_ms`): each take moves the picture that much
  earlier, the sound and the voice-following copy untouched. Checked on a clap
  recording: 110 ms put the hands meeting within a frame of the clap.
- Settings page in the control window (the Settings... button beside Open
  script...): choose the camera and the microphone from what Windows offers, and
  set the picture delay. Each change is saved at once and used without a restart
  (the speech worker switches devices and checks the camera again); locked while a
  take records. A chosen device Windows no longer offers stays listed as "(not
  found)" instead of being swapped silently.

## [0.3.4] - 2026-10-10

### Added
- Program icon (app/resources/simple_prompter.ico, seven sizes from 16 to 256,
  made by scripts/make_icon.py): the pill in miniature, three script lines
  with the blue follow caret on the one being read and the red record dot,
  in the pill's own colors. The exe carries it (`1 ICON` in simple_prompter.rc,
  compiled in by the build), so Explorer, the taskbar and the control window's
  title bar show it (simple_shell 1.13.1); so do the installer, Start menu and
  desktop shortcuts, and the Apps & features entry.

## [0.3.3] - 2026-10-09

### Fixed
- A prompter that ended without closing (crash, Task Manager, a forced stop)
  left its ffmpeg running: the camera probe or the recording kept the camera
  and microphone and its working folder. The capture, camera-probe and preview
  processes now end with the prompter however it ends (simple_process 1.2.0
  `set_ends_with_owner`, a Windows kill-on-close job). Checked by force-killing
  the prompter three times mid-probe: the probe was gone within 150 ms each
  time. The final render is left untied on purpose: it finishes on its own.

## [0.3.2] - 2026-10-09

### Added
- Transport bar under the script text on the pill (PT_TRANSPORT_BAR, always
  showing): a progress line (click it to hold with the caret on that word) and
  video-player buttons - back a sentence, again, play / hold / go, forward a
  sentence | record / wrap / stop, star, reject | slower, faster. Each does what
  its Ctrl+Alt key does; back and forward also hold first when reading. A
  button that would do nothing now is dimmed. Resting the pointer on a button
  or the line for 450 ms shows a tooltip with its key. The pill is taller by
  the bar; the number of script lines is unchanged. Needs simple_shell 1.13.0
  (`SHELL_PANEL.is_cursor_over`).

## [0.3.1] - 2026-10-09

### Added
- Camera line in the control window (PT_CAMERA_CHECK): the camera is opened as
  the recording will open it and 30 frames are measured. Live (green), live but
  dark (amber), or what is wrong (red): picture not moving (OBS closed or its
  Virtual Camera stopped: it still sends OBS's placeholder card), black, in use
  by another program, not found, no picture. A virtual camera is re-checked
  every 10 s, even during a take; a webcam once at start and after each take.
- Video line while recording (PT_CAPTURE_PROGRESS reads ffmpeg's -progress
  output): frames, fps, drops and duplicates. If no frame arrives for 1.5 s
  (or none in the first 5 s) it turns red and the pill badge shows NO VIDEO;
  NO PICTURE when the camera check finds a still or black picture mid-take.

## [0.3.0] - 2026-10-07

### Added
- Take Studio (plan Step 4): Ctrl+Alt+R records a session (camera + microphone
  into raw.mkv, NVENC) while the pill follows; Wrap, Star, Reject and Marker
  keys; the take is analyzed on the GPU after Wrap (whisper passage decode,
  Silero speech map, retake solver) into cuts and things to check.
- The "Last take" panel (Edit Floor): cuts and flags with ffplay previews;
  Render writes out\final.mp4 with captions (SRT, VTT) and chapters in one pass.
- Recording through OBS Virtual Camera (or any camera without MJPEG): the
  camera's modes are probed; a virtual camera is opened as its own input so its
  clock does not hold the video back.

### Changed
- Startup on a long script went from ~26 s to under 0.1 s (simple_mml 1.0.2
  hash-bucketed range/no_duplicates; hashable word ids; cached models).
- Control window is two columns; long lines wrap instead of running over.
- A camera or microphone held by another program now says so.


## [0.1.0] - 2026-10-06

### Added
- The app (plan Step 1): a capture-excluded pill under the webcam that scrolls
  at a steady speed, with global hotkeys, mouse control on the pill, Shift+drag
  placement, hide and click-through, scaled to the display's DPI.
- Opening scripts: an "Open script..." button (the Windows Open dialog, new in
  simple_shell 1.11.0), Ctrl+Alt+O from anywhere, or drop a .md / .txt file on
  the control window. The last script reopens at the next start.
- Installer (Inno Setup, per-user, no admin prompt) with a welcome script that
  teaches the controls and the script format by being read, and the voice read
  test as a second sample.

### Fixed
- Hold now offers the start of the sentence being read as the restart point
  (F-01), never a cue line; before, Go after Hold restarted the whole script.
- A script path with non-ASCII characters was lost from the settings (a
  simple_toml escaping bug, fixed there).

### Added (library core)
- Library core (Eiffel Spec Kit phases 0-5): script model with stable word ids and live edits;
  constant, voice-gated and tracking followers; forward-only aligner with equivalence classes
  (homophones, spoken abbreviations, number words, compounds, sound-alikes); speech pipeline;
  take studio state machine, JSONL journal and recording clock; automatic editor (attempt
  builder, attempt aligner, take solver, silence snapper, flagger, session analyzer);
  captions, chapters, review SRT, EDL and ffmpeg capture/render plans; settings and keymap.
- Real-voice acceptance tests replaying a recorded read (word times and VAD map).

### Fixed (found by replaying the real recording, Phase 5)
- A long [CUE] line stopped the attempt aligner for the rest of the take.
- A stop word in an ad-lib jumped alignment ahead; multi-word equivalences were never matched.
- One garbled word discarded a whole passage; misread words were never flagged.
- Neighbouring cuts of one take overlapped (audio played twice); an ad-lib stayed in the final
  video; good cuts were marked tight because VAD speech outlasts recognizer word times.

### Changed
- `PT_VAD.speech_probability` replaced by `analyze`, `last_probability` and `reset`: the real
  detector (Silero) is recurrent, so scoring a frame is a command (CQS audit).
