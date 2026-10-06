# simple_prompter

[GitHub](https://github.com/simple-eiffel/simple_prompter) •
[Issues](https://github.com/simple-eiffel/simple_prompter/issues)

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Eiffel 25.02](https://img.shields.io/badge/Eiffel-25.02-purple.svg)
![DBC: Contracts](https://img.shields.io/badge/DBC-Contracts-green.svg)
![SCOOP](https://img.shields.io/badge/Concurrency-SCOOP-orange.svg)

A teleprompter that follows your voice, plus a take studio that edits your recording for you.
Written in Eiffel for Windows, with speech recognition on the local GPU.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

🚧 **Library complete, application in progress**
- The library (this repository) is built and verified: 88 classes, 183 tests passing in both
  the contract-checked and the lean release build, every exported feature exercised by a test.
- Verified against a real recording: the follower stays within a line of the reader, holds
  still during an ad-lib, catches up after a skipped paragraph, and never scrolls backward.
- Not yet built: the prompter window, live microphone capture, and the GPU speech pieces
  (whisper and Silero VAD through simple_speech). The library talks to them only through
  deferred classes, so its tests run without any of them.

## What it does

**Voice following.** A small text pill sits under your webcam. As you read, it scrolls with
you: voice activity drives the motion, and speech recognition plus a forward-only aligner keep
it on the word you are reading. It tolerates the way people really read: homophones
("their/there"), spoken abbreviations ("for example" for "e.g."), numbers read as words,
split compounds, and the odd garbled word.

**Take studio.** Record with ffmpeg while you read. Flub a sentence, press Again, and read it
again without stopping the camera; edit the script on the fly; star or reject a take; drop
markers. Everything is journaled in recording time. When you wrap, the automatic editor:
- picks the latest good take of every passage (a starred take wins),
- cuts out ad-libs, dead air and rejected takes, placing every cut in silence,
- flags what needs your eye: misread words, long pauses, tight splices, missing passages,
- writes captions (SRT and WebVTT), YouTube chapters and an EDL, and an ffmpeg render plan.

Voice commands are deferred; control is by hotkeys, the mouse, and a presentation clicker or
foot pedal.

## Quick start

```eiffel
local
    prompter: SIMPLE_PROMPTER
do
    create prompter.make_with_settings (create {PT_SETTINGS}.make_in_memory)
    prompter.load_script_text ("Episode 12", script_text)
    prompter.perform ({PT_ACTION}.Play)           -- practice run: count in, no recording
    prompter.perform ({PT_ACTION}.Count_in_done)

        -- From the speech worker (SCOOP processor), as audio arrives:
    prompter.feed_voice (frame)                   -- PT_VOICE_FRAME from the VAD
    prompter.feed_heard (words)                   -- PT_HEARD_WORDS from the decoder

        -- From the GUI timer, every frame:
    prompter.tick (now_ms)
    offset := prompter.scroll.y_offset
end
```

## Design

- **Design by Contract** throughout; MML model queries on every collection.
- **One position convention**: positions count words already read, so the aligner, the
  follower and restarts agree.
- **Effects behind deferred classes** (`PT_CLOCK`, `PT_TEXT_MEASURE`, `PT_VAD`, `PT_DECODER`,
  `PT_TRANSCRIBER`), with scripted doubles for tests.
- **Recording time from the audio tee**: ffmpeg writes 16 kHz float samples alongside the
  video; their byte count is the clock, so marks and video stay in sync by construction.
- **The journal is the truth**: one JSONL line per event, flushed immediately, so a crash loses
  at most a torn last line, which replay skips.

## Building

```bash
ec.sh test -config simple_prompter.ecf -target simple_prompter_tests
./EIFGENs/simple_prompter_tests/F_code/simple_prompter.exe
```

Dependencies (simple_* first): simple_mml, simple_json, simple_file, simple_encoding,
simple_toml, simple_testing; EiffelBase.

The full development record (research, specification, approved intent, contracts, review,
tasks, and the evidence of every phase) is in `.eiffel-workflow/`.

## License

MIT
