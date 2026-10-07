simple_prompter 0.3.0
=====================

A teleprompter that sits under your webcam and follows your voice: read
aloud and the text keeps the line you are reading in place. Pause and it
waits; skip ahead and it finds you. Ctrl+Alt+M switches to a steady speed.

Starting
  Start menu > simple_prompter. The first time, it opens the welcome script,
  which explains everything by being read aloud. The pill appears at the top
  center of your main monitor, just under the webcam.

Scripts
  A script is a plain .txt or Markdown .md file saved as UTF-8 (Notepad,
  VS Code and Obsidian all do this).
    - Blank lines separate paragraphs; every sentence is a restart point.
    - A line starting with # is a heading: shown, may be read, never required.
    - [CUE: like this] is a note to yourself: shown dimmed, never spoken.
    - Markdown bold, italics and links show as plain words.
  To open one: the "Open script..." button, Ctrl+Alt+O from anywhere, or drop
  the file on the control window. Your last script reopens next time.
  Two samples are in the "samples" folder (Start menu > Sample scripts).

Keys (work in any program)
  Ctrl+Alt+P          play / stop (a short count-in first)
  Ctrl+Alt+Space      hold / go
  Ctrl+Alt+Backspace  again: back to the start of the sentence
  Ctrl+Alt+Left/Right back / forward a sentence while held
  Ctrl+Alt+Up/Down    faster / slower
  Ctrl+Alt+O          open a script
  Ctrl+Alt+M          follow mode: your voice / constant speed (while stopped)
  Ctrl+Alt+H          hide / show the pill
  Ctrl+Alt+I          click-through on / off (clicks go to what is under it)
  Ctrl+Alt+R          record a take (count-in, then camera + microphone)
  Ctrl+Alt+End        wrap the take (while recording) / stop (practice)
  Ctrl+Alt+S / X / N  star (keep) / reject / marker, while recording

Mouse on the pill
  click: hold. While held: click a word to start there, the wheel steps back
  and forward, right-click goes.
  Hold Shift and the pill shows its grips: drag the middle to move it, drag
  an edge or corner to size it. The height snaps to whole lines (1 to 12);
  the width sets the text column. Position and size are remembered.

Following your voice
  The control window shows "Speech:" - loading (a few seconds at start),
  ready, then listening on your microphone. The pill shows MIC OFF if it is
  playing without hearing you. Everything runs on this PC: whisper on the
  NVIDIA GPU (CUDA 13), Silero for voice activity, ffmpeg for the microphone.
  The microphone is "Microphone (FHD Camera Microphone)" unless settings.toml
  names another (key: microphone). While the program runs in voice mode the
  microphone stays open; in constant-speed mode nothing is decoded.
  The whisper model (ggml-large-v3-turbo-q5_0.bin) is looked for in the
  "models" folder of the install, then in D:\prod\simple_speech\models.

Recording a take (new in 0.3.0)
  Ctrl+Alt+R starts a session in Videos\simple_prompter\<date time> - <script>:
  the camera and microphone are recorded (raw.mkv) while the pill follows you.
  Stumble? Just back up a sentence or two and read it again - the program
  works out which reading to keep. Ctrl+Alt+End wraps the take; it is then
  analyzed on the GPU (a few seconds) and the "Last take" panel on the right
  of the control window lists the cuts and the places worth checking. Click
  one to preview it. Render makes out\final.mp4 with captions (final.srt,
  final.vtt) and chapters.txt; Play final and Open folder do what they say.
  review.srt in the session folder marks every cut for a check in VLC.

Recording through OBS
  OBS can be the camera: in OBS click Start Virtual Camera, and set
    camera = "OBS Virtual Camera"
  in settings.toml (program closed). What OBS shows - layout, crops, filters -
  is what gets recorded; OBS itself does not need to record. Only one program
  can use the webcam at a time: if OBS has it, simple_prompter must use the
  OBS Virtual Camera. The microphone still goes straight to simple_prompter.

Screen sharing and recording
  The pill is left out of screen captures: meeting apps, recorders and
  screenshots show what is behind it, not the pill.

Settings
  %APPDATA%\simple_prompter\settings.toml - font size, column width, lines,
  opacity, speed, count-in, pill position, last script, follow mode,
  camera and microphone. Edit with the program closed. Uninstalling keeps this file.

If it closes unexpectedly
  This build checks its own contracts and stops on a broken one, leaving
  exception_trace.log in the install folder
  (%LOCALAPPDATA%\Programs\simple_prompter). Please send that file.
