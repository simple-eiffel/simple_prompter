# Answer key: read_test_01.md

What the reader is instructed to do, and what each part tests. Used to score VAD, aligner and
take-solver behavior against Larry's real recording (larry_read_01.wav).

| # | Script location | Reader does | Tests | Expected system behavior |
|---|-----------------|-------------|-------|--------------------------|
| 1 | Heading + first [CUE] | Not spoken | Parser: heading = section 1, cues excluded | Aligner never waits for heading/cue words |
| 2 | "When I stop speaking, it should stop..." | Normal read | Baseline rate (wpm) | Tracking rate ≈ measured wpm |
| 3 | After paragraph 1 | ~3 s silence | VAD stop latency | Voice-gated: stop ≤ 250 ms; resume ≤ 150 ms |
| 4 | "Dr. Meyer ... e.g. ... U.S. team" | Normal read | STS abbreviations: no false sentence ends | Passage count unaffected by "Dr." "e.g." "Mr." "Ms." "U.S." |
| 5 | Numbers paragraph | Reads digits as words | Matcher vs ASR number formatting ("3.5" vs "three point five", "5070") | Numbers tolerated (normalization); no position loss |
| 6 | Cough sentence | Cough mid-sentence, re-read from start | Unmarked restart (FR-T16 flag), aligner backward evidence | Aligner: no false backward jump on cough; flagger: "unmarked restart" for the first partial read |
| 7 | Sound-alikes | Normal read | Matcher tolerance; homophones | Position holds; misread flags only if words truly differ |
| 8 | Ad-lib ~10 s | Off-script speech | FR-024 ad-libs don't move position; coast then hold | Tracking: coast ≤ 1.5 s, then hold until script words return |
| 9 | Repeated "So when you ..." x3 | Normal read | RISK-003 repeated-phrase ambiguity | Forward bias picks the right occurrence each time |
| 10 | "This paragraph should be skipped" | Skipped | Forward jump with evidence | Aligner jumps ahead once anchored words of the next paragraph are heard (≥ required_anchors) |
| 11 | Jargon | Normal read | ASR vocabulary; prior-text prompt benefit | Words matched (with or without prompt; compare) |
| 12 | "## Closing" + slow read | Slow pace | Rate adaptation | Tracking rate drops; no overshoot |

Recording: mono 48 kHz WAV (larry_read_01.wav), FHD Camera Microphone unless noted.

## Actual results for larry_read_01.wav (2026-10-05)
See `.eiffel-workflow/evidence/real-voice-larry_read_01.md`. Deviations from the plan that tests must expect:
- Headings were read aloud ("Simple Prompter Read Test 1", "Closing").
- Row 6: cough after "your text", then reading CONTINUED (no re-read). The cough (59.81-60.99 s) is VAD speech.
- "e.g." spoken as "for example"; "twenty twenty-six" heard as "26"; "5070" heard as "55070".
- Ad-lib ran 81.9-94.7 s. Instructed pause: 19.17-22.85 s.
