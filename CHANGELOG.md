# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
