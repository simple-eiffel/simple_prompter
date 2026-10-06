# Spike: voice commands vs script reading (2026-10-05)

Setup: SAPI TTS clips (16 kHz mono) in scratchpad/cmd; whisper large-v3-turbo-q5_0, CUDA build,
greedy, no_context=true. Server rows: resident whisper-server with Silero VAD (pad 30 ms).

| Clip (spoken) | Server (VAD) | cli no VAD | cli VAD pad 250 ms |
|---------------|--------------|------------|--------------------|
| "Prompter, again." | " again." | " again." | " again." |
| "Prompter, back two." | " back to" | " back to" | " PROMPTER. BACK TO." |
| "Prompter, from the main idea." | " prompter, from the main idea." | | |
| "Prompter, hold." | " Promptor, hold." | | |
| "So when you stop speaking, it pauses, and when you continue, it scrolls again." | exact | | |
| "Moody is a notch teleprompter for Mac." | exact | | |
| "Go." | " Go." | | |
| "Back." | " back." | | |

Latency (server, warm): 50-86 ms per clip.

## Findings
1. **Free transcription drops a leading vocative wake word** (2 of 4 command clips), with or without
   VAD. VAD is not the cause. A design that requires the wake word to *appear in the transcript*
   will miss commands. Wake/command detection must score the audio against the command phrases
   (whisper guided mode, examples/command; or grammar-constrained decoding, whisper.h:581-584
   `grammar_rules` / `grammar_penalty`), not search the transcript.
2. **Spelling drift:** "Promptor". Matching must be phonetic/fuzzy.
3. **Number homophones:** "two" becomes "to". Argument slots need homophone normalization (to/too/two → 2, for/four → 4).
4. Script sentences containing command words ("stop", "continue", "again", "teleprompter") are
   transcribed exactly. The disambiguation has to come from *context* (aligner expectation,
   pauses), because the words themselves are identical.
5. Collision example in the very first script: wake word "Prompter" is contained in "teleprompter".
