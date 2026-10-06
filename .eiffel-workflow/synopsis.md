# SYNOPSIS: Phase 2 adversarial review of simple_prompter

Date: 2026-10-05. Reviewed: 84 library classes, 11 test classes (78 tests). Full findings:
evidence/phase2-claude-response.md. Sketch: approach.md.

## Overall assessment: **PASS WITH CONDITIONS**

The contracts compile, the invariants are all O(1) (scanned), and the state machine table is
consistent. Six HIGH findings are **design and contract** defects that would surface as real
behavior bugs on camera. They must be fixed in the contracts before implementation.

## Critical (fix before Phase 3/4)

| # | Finding | Fix |
|---|---------|-----|
| H1 | Caret / aligner / follower use two index conventions, so restarts are off by one word | One convention: positions count **words already read**; caret k → set_caret (k−1), reanchor (k−1) |
| H2 | `advance` clears `caret_changed` before the scroll model looks at it, so Again would visibly rewind through the text (and break the scroll contract) | Scroll snaps (`jump_to`) whenever the follower target drops below its position; drop the flag dependency |
| H3 | A decode window from before a restart can arrive after it and yank the aligner back to the flub point | `reanchor (index, at_sample)`; `update` ignores windows that start before it (contracted) |
| H4 | After a live edit, the facade's aligner and layout still use revision 1 | Facade owns `commit_edit`/Skip and rewires; O(1) invariant ties aligner, layout and follower to the current revision |
| H5 | The keymap holds one key per action and no state, so it can't do clicker PageUp = Again (reading) vs Back (held), or several keys per action | Table keyed by key combo → logical control; new pure `PT_CONTROL_RESOLVER` (control + state → action) |
| H6 | Capture plan leaves the dshow audio buffer at the device default, eating into the ≤ 250 ms pause budget | Add `-audio_buffer_size 50`; measure in spike T-0 |
| H7 | **Real voice:** the matcher has no equivalence classes. Homophones, spoken abbreviations ("e.g." → "for example"), number words, split compounds and phonetics (Silero → Celero) leave ~8% of real words unanchored and raise ~14 false misread flags in 3 minutes | New pure `PT_EQUIVALENCES` (homophones, abbreviations, numbers, phonetic key); multi-word ↔ one-word matching in the aligner; equivalence matches are never misreads |

## Important (fix during implementation)

| # | Finding |
|---|---------|
| M7 | `old again_target` is evaluated for every action; store the target only for Again |
| M8 | Play/Record allowed with an empty script (would build a Resume with no caret) |
| M9 | A Star can mark two attempts (5 s grace window); one Star → exactly one attempt |
| M10 | The solver may switch attempts mid-sentence; contract switches only at passage starts or tight carets |
| M11 | `superseded_by_star` checks only the first word; use passage overlap |
| M12 | Padded cut spans can run past the end of the recording; clamp and contract |
| M13 | The pipeline may decode silence; contract "decode only within speech + hangover" |
| M14 | Skip creates a revision without saying so; route through the facade |
| M15 | Duplicate key combos allowed (folded into H5) |
| M16 | Reloading a script mid-recording orphans the session; require not recording |
| M23 | **Real voice:** whisper word times absorb silences (the 3.68 s pause was invisible). Clip occurrence spans to VAD speech; try DTW timestamps |
| M24 | **Real voice:** headings were read aloud. Heading words become optional (matchable, not required for cover) |

## Minor

- L17: rename `lines_written` (counts in-memory appends).
- L18: Unicode normalization length invariant.
- L19: two vacuous tests to strengthen.
- L20: settings setters missing.
- L21: pipeline models.
- L25: (real voice) Silero marks a cough as speech, so voice-gated mode creeps ~2 words; tracking strips `*cough*`.

## Real-voice evidence (Larry's recording, evidence/real-voice-larry_read_01.md)

- 144 s transcribed on the GPU in 8.0 s (about 5.6% of real time; target ≤ 25%).
- Raw accuracy 91.7%; nearly every miss is an equivalence class (H7).
- Pace 128 wpm voiced, 100 wpm including pauses.
- The ad-lib, skipped paragraph and repeated phrases all behaved as intended.

## Verified non-issues

- Edit postconditions at the very start/end of the script are safe: MML `front`/`tail` clamp through `interval`.
- All invariants are O(1) (mechanical scan of every invariant clause).

## Recommended actions before Phase 3 (`/eiffel.tasks`)

1. Apply H1-H7 (and M8, M15, M16, M24, which are one-line preconditions) to the contracts. Recompile with `ec.sh check`
   on both targets and `ec.sh test`. Add tests: off-by-one resume, Again snap (no rewind), stale-window
   ignore, edit rewiring, clicker state mapping, capture plan buffer flag.
2. Record the H-items in spec/10-ADDENDUM-CONTRACTS.md.
3. Carry M7-M14 and the LOW items into /eiffel.tasks as acceptance criteria.

**Estimated contract work:** two classes added (`PT_CONTROL_RESOLVER`, `PT_EQUIVALENCES`); about 12 classes touched; 8-10 new tests, including real-voice fixture tests on larry_read_01.
