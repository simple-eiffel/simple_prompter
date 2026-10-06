# Real-voice evidence: larry_read_01 (2026-10-05)

Source: `testing/fixtures/Recording.m4a` (Windows Voice Recorder; AAC 48 kHz stereo, 144.02 s), read by
Larry from `read_test_01.md`. Converted to `larry_read_01.wav` (16 kHz mono PCM, 4,608,760 bytes) with ffmpeg.

## Tools (all local, GPU)
- whisper.cpp 1.8.2 CUDA build (`whisper_cpp_build/build_cuda`), large-v3-turbo-q5_0, `-ml 1 -sow -osrt -ojf`.
- Silero VAD v6.2.0 through `vad-speech-segments.exe -vsd 250`.

## Measurements
| Item | Result |
|------|--------|
| Full-file transcription time | **8.03 s total** for 144 s of audio (incl. model load); wall 9.7 s |
| Full-file VAD time | 0.89 s wall, 41 speech segments |
| Analysis-pass ratio (NFR-T03 target <= 25%) | **~5.6%** (whisper) + ~0.6% (VAD) |
| Script words spoken (excl. cues, skipped paragraph) | 216 |
| Heard words (excl. ad-lib 81.5-95.0 s) | 214 |
| Raw word accuracy vs script (exact normalized match) | **91.7%** (198/216) |
| Pace | 128 wpm over voiced time; 100 wpm over wall time (pauses included) |
| Silences >= 1 s (VAD) | 3.45-4.67 (1.22), **19.17-22.85 (3.68, the instructed pause)**, 56.45-57.83 (1.38), 79.65-82.21 (2.56), 94.65-96.35 (1.70), 106.11-108.35 (2.24), 125.53-128.23 (2.70), 134.08-135.11 (1.03) |

## Mismatches (script -> heard) and their class
| Script | Heard | Class | Handled by |
|--------|-------|-------|-----------|
| one (heading "Test One") | 1 | number words <-> digits | number normalization |
| e.g. | for example | reader expands abbreviation | abbreviation table |
| Ms. | Mrs. | abbreviation variant / ASR | abbreviation table + phonetic |
| postcondition | post condition | compound split | compound join |
| c p p | CPP | letters joined | compound join |
| twenty twenty-six | 26 | number words <-> digits + ASR drop | number normalization (partial) |
| 5070 | 55070 | ASR error | not an anchor (tolerated) |
| their / they're | there | homophone | homophone classes |
| to / too | two | homophone | homophone classes |
| whole | hole | homophone | homophone classes |
| so | sew | homophone | homophone classes |
| Silero | Celero | proper noun misheard (edit distance 2 on 6 letters: rejected by spelling tolerance) | phonetic key |

All but the two true ASR errors are equivalence classes the matcher can absorb.

## Behaviors (answer key rows)
| Row | Planned | Actual |
|-----|---------|--------|
| 1 Heading/cues | Not spoken | **Larry read the headings aloud** ("Simple Prompter Read Test 1", "Closing"); cues not spoken |
| 3 Pause | ~3 s silence | 3.68 s VAD silence; **whisper word timestamps absorbed it** (no gap in word times) |
| 4 Abbreviations | Read as written | "e.g." spoken as "for example"; "Ms." heard as "Mrs." |
| 5 Numbers | Digits read as words | "twenty twenty-six" heard as "26"; "5070" heard as "55070" |
| 6 Cough + restart | Cough, re-read from start | Cough after "your text" (decoded alone: `*cough*`), **then continued without re-reading**. **Silero classified the cough (59.81-60.99 s) as speech** |
| 7 Sound-alikes | Read | All collapsed to one spelling (see table) |
| 8 Ad-lib | ~10 s off-script | ~12 s (81.9-94.7 s), clean return to the script |
| 9 Repeated phrase | 3 x "So when you" | All three transcribed correctly, in order |
| 10 Skip paragraph | Skipped | Skipped (2.24 s silence at the jump) |
| 11 Jargon | Read | Correct except "Silero" -> "Celero", "c p p" -> "CPP" |
| 12 Slow closing | Slower | Present; not separately measured |

## Consequences for the design
1. PT_WORD_MATCHER / PT_NORMALIZER need **equivalence classes**: homophones, abbreviations (as-written <-> spoken),
   number words <-> digits, compound split/join, and a phonetic key. Otherwise ~8% of real words fail to
   anchor and the flagger raises ~14 false "misread" flags in 3 minutes.
2. **Cut placement must use the VAD speech map**, not whisper word end times (they absorb silences). This confirms the
   snapper design. The analysis pass should also try DTW token timestamps (`-dtw large.v3.turbo`).
3. **Headings may be spoken**: heading words must be optional (matchable, not required for exact cover).
4. **A cough counts as speech for Silero**: voice-gated mode will creep during a cough. Tracking mode can treat
   `*cough*`-style non-speech annotations as non-words.
5. The analysis pass is ~4x faster than the 25% budget on this GPU.
