simple_prompter 0.1.0
=====================

A teleprompter that sits under your webcam. This first version scrolls at a
steady speed; following your voice comes next.

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
  Ctrl+Alt+H          hide / show the pill
  Ctrl+Alt+I          click-through on / off (clicks go to what is under it)

Mouse on the pill
  click: hold. While held: click a word to start there, the wheel steps back
  and forward, right-click goes. Shift+drag moves the pill (remembered).

Screen sharing and recording
  The pill is left out of screen captures: meeting apps, recorders and
  screenshots show what is behind it, not the pill.

Settings
  %APPDATA%\simple_prompter\settings.toml - font size, column width, lines,
  opacity, speed, count-in, pill position, last script. Edit with the program
  closed. Uninstalling keeps this file.

If it closes unexpectedly
  This build checks its own contracts and stops on a broken one, leaving
  exception_trace.log in the install folder
  (%LOCALAPPDATA%\Programs\simple_prompter). Please send that file.
