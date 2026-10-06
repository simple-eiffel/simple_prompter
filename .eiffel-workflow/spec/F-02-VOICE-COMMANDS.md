# F-02 VOICE COMMANDS: Script-Aware Spoken Control with an On-Screen Rail and Silent Confirm

| | |
|---|---|
| Project | simple_prompter |
| Feature | Voice commands for Take Studio actions (extends F-01 §4.3) |
| Status | **DEFERRED 2026-10-05 (Larry): "just do the mouse/key thing for now ... no voice commands."** Kept as a design for later; not in scope for the current build. Decisions Q1/Q2 below stand if it is resumed. |
| Evidence | evidence/spike-voice-commands.md (whisper on command and collision clips) |
| Origin | Larry, 2026-10-05: commands visible on screen to build muscle memory; must tell script words from command words; silent "confirm ___?" answered by voice; mouse/keyboard always available alongside |

---

## 0. Summary

You can speak Take Studio actions ("Prompter, again", "back two", "go"). The phrases you can say
right now are always shown on the pill, each beside its key or clicker button, so you learn them
by seeing them. The software knows your script: before every session it finds every place where a
command word or the wake word appears in the text (for example "it scrolls **again**",
"tele**prompter**"). While you read, it compares what you said against two explanations, *"reading
the next words of the script"* and *"giving a command"*, and only acts when the command explanation
clearly wins. When it isn't sure, it asks silently on the pill (**"Again from 'So when you'? yes ·
no"**) and you answer by voice, click or key. Voice never replaces the other controls. Clicker,
keyboard and mouse always work at the same time, and one keystroke turns voice off.

## 1. Principles (in priority order)

1. **Voice only adds, it never replaces.** Every voice action is an ordinary Take Studio action (F-01 §4.2)
   that also has a key, clicker and mouse binding. All of them stay live at once. If voice misbehaves, you
   use the button you already know; nothing is lost.
2. **Never hurt the take.** The camera keeps rolling (F-01). A wrong voice action only costs a few
   seconds that are cut out later, and every action is reversible ("no" / "undo" / Esc / clicker).
3. **Visible vocabulary.** What you can say is on screen, for the current state only, next to its
   key. You learn from the screen, not from a manual.
4. **Script-aware.** The software knows which command-like words are in the script and where.
   Reading them must never fire a command.
5. **Confirm when unsure.** Confident commands act at once; doubtful ones ask silently; unlikely
   ones are ignored.
6. **Measured, not hoped.** Recognition quality is tested against a corpus with false-accept and
   false-reject numbers (§11). The spike already overturned one naive assumption (§5.1).

## 2. Vocabulary

### 2.1 Wake phrase
- Required for commands spoken **while READING**. Optional (configurable) while HELD or in CONFIRM,
  where you aren't reading, so ambiguity is low.
- Default `"Prompter"`. User-configurable to any phrase of 2+ syllables.
- At script load, the collision check (§6) scores candidates and **warns when the wake phrase sounds
  like script text** (e.g. "Prompter" vs "teleprompter" in the Moody script). It suggests an alternative
  ("Cue-card", "Director", "Take-two"…), or lets you keep it with the collision areas set to always-confirm.

### 2.2 Commands by state

| State | Say (wake optional where marked °) | Action (F-01 §4.2) | Also on |
|-------|-----------------------------------|--------------------|---------|
| READING | *wake* **again** | Again | clicker Back · Ctrl+Alt+Backspace |
| READING | *wake* **hold** / **wait** | Hold | clicker B · Ctrl+Alt+Space |
| READING | *wake* **back** [*n*] | Hold + caret back *n* passages | clicker Back ×n |
| READING | *wake* **from** ‹script words› | Hold + caret to those words | click the word |
| READING | *wake* **star** / **keep that** | Star | Ctrl+Alt+S |
| READING | *wake* **scrap that** | Reject | Ctrl+Alt+X |
| READING | *wake* **note** ‹free text› | Note (text optional) | Ctrl+Alt+N |
| HELD | °**back** [*n*] · °**forward** [*n*] | Move caret | clicker Back/Fwd · arrows |
| HELD | °**one** … °**nine** | Jump to badged sentence | digits |
| HELD | °**from** ‹script words› | Caret to words | click |
| HELD | °**go** / °**roll** | Go (count-in) | clicker Fwd · Enter · double-click |
| HELD | °**edit** | Open inline editor | Ctrl+Alt+E |
| HELD | °**change** ‹words› **to** ‹words› (COULD) | Voice edit, always confirmed | inline editor |
| any | *wake* **wrap** | Wrap (always confirmed) | Ctrl+Alt+End |
| CONFIRM | **yes** · **confirm** · **do it** / **no** · **cancel** | Accept / decline | Enter/Esc · clicker Fwd/Back · click |
| any | *wake* **undo** (within 3 s of an immediate action) | Revert last voice action | Ctrl+Z |

Argument normalization (spike finding: "two" was heard as "to"):
- number slots map to/too/two → 2, for/four → 4, won/one → 1, ate/eight → 8;
- "from ‹words›" is matched fuzzily against the script near and behind the caret. If ambiguous, badges appear and you say or press the digit.

### 2.3 Vocabulary is data
Commands live in a `voice_commands.toml` (phrase variants, state, action, needs_confirm, min_confidence).
Users can add synonyms. Each edit re-runs the collision check.

## 3. The command rail (on screen)

### 3.1 Placement
A thin strip inside the pill's bottom edge, below the script lines, in a smaller, dimmer font. The
text stays nearest the lens; the rail sits slightly lower, still within ~2-5 deg of it (research
02-LANDSCAPE §Eye contact). It shows **only the commands valid in the current state**, each with its key/button:

```
READING ──────────────────────────────────────────────────────────────
   So when you stop speaking, it pauses, and
   when you continue, it scrolls again.  That
   makes it feel very natural.
  🎙 Prompter: again ⌫ · hold ␣ · back n · from…  │ voice ● on (Ctrl+Alt+V)

HELD (pill expanded) ─────────────────────────────────────────────────
   ...
 ③ ▸So when you read your text, you still keep
   natural eye contact and Moody can follow...
  🎙 back n ← · forward n → · one…nine · from… · go ⏎ · edit E
```

### 3.2 Learning levels (muscle memory)
Each command has a level that moves on its own as you use it:

| Level | Rail shows | Promote when | Demote when |
|-------|-----------|--------------|-------------|
| **Novice** | Full phrase + key; "heard: …" echo after each attempt | 8 successful uses, no false triggers in the last 20 | |
| **Familiar** | First word only + key; full phrase in HELD | 20 successful uses | 3 failed attempts in a session |
| **Fluent** | Hidden while READING (key glyph only); full in HELD | | Unused for 30 days, or 3 failed attempts |

- Levels are per command, per user, stored in settings. "Pin all to Novice" is one switch.
- **Heard echo** (Novice): after an utterance the rail briefly shows `heard: "again" ✓` or
  `heard: "back to" → back 2 ✓` or `heard: "…scrolls again" = reading`. This shows *why* it did or didn't
  act, which is how you learn what works.
- **Practice mode** (no recording): the rail lights each command in turn; you say it; the software
  scores it and records your personal confidence levels (§5.4 calibration).

### 3.3 Script collision hints (learning mode)
Where the script contains a command-like phrase, the word gets a faint dotted underline on the
pill (`scrolls a̤g̤a̤i̤n̤`). That tells you "the software knows this is script; just read it." The hint
can be turned off.

## 4. The silent confirm (Larry's idea)

### 4.1 When it appears (tier policy)
Every recognized candidate gets a decision score (§5). The tier decides what happens:

| Tier | Condition | Behavior |
|------|-----------|----------|
| **Act** | Score ≥ high threshold **and** no script collision within the expected window **and** the action is not in the always-confirm set | Act immediately. Rail shows `✓ again · say "undo" / Ctrl+Z` for 3 s |
| **Confirm** | Score between thresholds, **or** a collision is near the reading position, **or** the action is Wrap / Reject / voice edit, **or** the command is still Novice and `confirm_while_learning` is ON (default ON, decided §14 Q2) | **Soft hold** + silent confirm prompt |
| **Ignore** | Score below low threshold | Nothing happens (Novice: faint `heard: … = reading`) |

### 4.2 What it looks like
The pill freezes (soft hold, amber outline). One line replaces the rail:

```
   Again from "So when you"?      yes ⏎   ·   no Esc        ●●●○○
```

- The proposed action is spelled out in plain words, including its target ("from 'So when you'",
  "back 2 → sentence 5", "wrap the session").
- The dots are a countdown (default 2.5 s, configurable).

### 4.3 How to answer, by any surface
| Answer | Voice | Key | Clicker | Mouse |
|--------|-------|-----|---------|-------|
| Accept | "yes" / "confirm" / "do it" | Enter | Forward | click the prompt |
| Decline | "no" / "cancel" | Esc | Back | click ✕ |
| **Keep reading** | (just continue reading the script) | | | |
| Timeout | (silence until the dots run out) | | | |

- **Keep reading = automatic decline.** If the speech after the prompt aligns with the script
  continuing from where you were, the prompt cancels, the soft hold releases, and the scroll catches up.
  This is the escape for every false trigger: you never have to stop and say "no".
- **Timeout = decline** (safe default), except Again/Hold, where timeout can be set to accept for
  people who prefer it.
- "yes"/"no" might appear in the script too. In CONFIRM, the same reading-vs-command test (§5)
  applies: "yes" that continues the script is reading.
- Prompt, answer and any speech during it are journaled and land on the edit floor (§8).

### 4.4 Immediate actions are undoable
For Act-tier actions: "undo" (voice, 3 s), Ctrl+Z, or clicker Back-then-Forward restores the previous
state and caret. The journal records `voice_undo`; the analysis pass treats the interval as floor.

## 5. Recognition pipeline

### 5.1 What the spike taught us (evidence/spike-voice-commands.md)
- Whisper's free transcription **drops a leading wake word**: "Prompter, again" became " again."
  in 2 of 4 clips, with and without VAD.
- It spells it inconsistently ("Promptor").
- It turns "two" into "to".
- It transcribes script sentences containing "stop / continue / again / teleprompter" exactly. The words are
  the same whether reading or commanding, so **context decides, not words**.

**So the design never searches the transcript for the wake word.** It scores the audio against the
command phrases directly, and compares that with how well the audio fits the script.

### 5.2 Stages

```
 PCM (F-01 §5.1 tee) ─► VAD utterance segmentation ─► candidate gate ─► two-hypothesis scoring ─► arbiter ─► tier ─► action / confirm
                                                        │                  │                        │
                                                        │                  ├─ H_script  (aligner)   ├─ collision map (§6)
                                                        │                  └─ H_command (guided)    └─ state, level, priors
```

1. **Segmentation.** Silero VAD splits speech into utterances: speech runs bounded by silence
   ≥ 250 ms (configurable).
2. **Candidate gate** (cheap, rejects most reading). An utterance is a command candidate if:
   - it is ≤ 3.0 s long, **and**
   - it is preceded by ≥ 300 ms silence or a reading break (the follower lost alignment, e.g. after a
     cough), **and**
   - it is followed by ≥ 250 ms silence.

   In HELD/CONFIRM every short utterance is a candidate. Continuous reading rarely passes this gate.
3. **H_script score.** Align the utterance's free transcription to the script window
   [pos − 3 … pos + 20] (forward-biased aligner, research D-009) → `S_script ∈ [0,1]`
   (matched-word ratio weighted by word confidence).
4. **H_command score.** Score the same audio against each phrase valid in the current state:
   - **guided scoring** (whisper.cpp `examples/command` guided mode: the transcription is classified into
     one of an allowed list) and/or **grammar-constrained decoding** (whisper.h:581-584
     `grammar_rules`, `grammar_penalty`) with a GBNF grammar generated from `voice_commands.toml`;
   - backed up by **phonetic fuzzy matching** of the free transcription (handles "Promptor", "back to");
   - result: best command c* with `S_command ∈ [0,1]`; the wake word is scored as part of the phrase,
     so a dropped wake word in free text doesn't matter.
5. **Arbiter.** `margin = S_command − S_script`, adjusted by context:

   | Context | Effect |
   |---------|--------|
   | Expected next script words contain a collision with c* (§6) | margin − large penalty; tier at least Confirm |
   | Utterance followed by speech that aligns to the script continuing from pos | **retract** (it was reading) |
   | Follower lost alignment just before (cough, stumble) | margin + bonus (commands follow trouble) |
   | State HELD/CONFIRM | margin + bonus (not reading) |
   | Command level Novice + "confirm while learning" | tier at least Confirm |
   | Personal calibration (§5.4) | thresholds shifted per command |

6. **Tier** (§4.1) → action, confirm, or ignore.

### 5.3 Timing
- A command can only be judged after its utterance ends: VAD end-of-speech (≥ 250 ms silence) plus
  decode. Spike: 50-86 ms per short clip on the GPU. **Expected end-of-utterance to action ≈ 300-400 ms**
  (to be measured live).
- The display freezes the instant a candidate passes the gate (soft hold), so the scroll never runs
  on during judgment. If it turns out to be reading, the scroll resumes and catches up smoothly.

### 5.4 Personal calibration
Practice mode collects `S_command` for each command in your voice and `S_script` for your
reading of a calibration paragraph full of command words. Thresholds are set per command to
separate the two (target: zero overlap on the calibration set). They are stored in settings and
re-run on demand.

## 6. Script collision analysis (static)

Runs at script load and on every revision (F-01 §4.5). Output: the **collision map**.

1. Normalize the script into words (same tokenizer as the aligner).
2. For every command phrase variant, the wake phrase, and the confirm words:
   - exact matches in the script;
   - phonetic matches (Metaphone-style keys, implemented in Eiffel) within edit distance ≤ 1 key;
   - containment ("teleprompter" ⊃ "prompter").
3. Each hit becomes a `COLLISION_SPAN` (word range, phrase, kind = exact | phonetic | contained,
   severity).
4. Reports:
   - **Wake phrase collisions:** a warning dialog at load: *"'Prompter' sounds like 'teleprompter' (line 1,
     3 places). Choose another wake phrase, or keep it; commands near those places will always ask
     first."* Suggested alternatives are ranked by collision count and syllable distinctiveness.
   - **Command word collisions:** no warning (they're normal: "again", "go", "back"). Used by the
     arbiter and shown as dotted underlines in learning mode (§3.3).
5. Live tie-in: the arbiter asks the map "does the window [pos … pos+20] contain a collision with
   c*?" in O(log n).

**Contracts:**
- `every_exact_occurrence_found` (tested by brute force on fixtures);
- `spans_within_script`;
- `map_rebuilt_on_revision`: the revision id of the map = the current script revision.

## 7. Worked examples (from the Moody script)

| # | Situation | What happens |
|---|-----------|--------------|
| 1 | Reading "…when you continue, it scrolls **again**." smoothly | No pause before "again" → fails the candidate gate. Even if it passed: S_script high, collision at pos → reading. Nothing happens. |
| 2 | Coughs after "you still keep", pauses, says "Prompter, again" | Follower lost alignment (cough) → bonus; isolated utterance; S_command high (guided), S_script low → **Act**. Caret to start of sentence, count-in. |
| 3 | Same as 2, but whisper free text is just " again." (spike) | Guided scoring scores the whole phrase "prompter again" against the audio; free text isn't needed. If the score lands mid-tier → **Confirm**: "Again from 'So when you'?" → "yes". |
| 4 | Reads line 1 "Moody is a notch **teleprompter** for Mac" with a dramatic pause before "teleprompter" | Passes the gate (pause, short). Collision span (contained wake phrase) at pos → penalty → at most Confirm. Prompt shows; he keeps reading "…for Mac" → aligns to the script → **auto-decline**, scroll catches up. |
| 5 | HELD, says "back to" (meaning 2) | HELD bonus, number normalization → back 2 → Act (or Confirm at Novice). |
| 6 | Script literally contains "Prompter, again." (a script about this app), and he reads it | Exact collision with wake + command at pos → always Confirm → keeps reading → auto-decline. |
| 7 | Voice keeps misfiring in a noisy room | He presses the clicker as usual (always live) and Ctrl+Alt+V to mute voice. The rail shows `voice ○ off`. |

## 8. Recording and the edit floor (F-01 tie-in)

- Command utterances, confirm prompts and answers are journaled with their exact rt span:
  ```json
  {"t":"voice_candidate","rt0":102.12,"rt1":102.98,"heard":" again.","cmd":"again","s_cmd":0.81,"s_script":0.07,"tier":"act"}
  {"t":"voice_cmd","rt":102.99,"cmd":"again","by":"voice"}
  {"t":"confirm_prompt","rt":140.20,"cmd":"back","arg":2}
  {"t":"confirm_answer","rt":141.05,"answer":"yes","by":"voice"}
  {"t":"voice_retract","rt":160.40,"reason":"script_continued"}
  ```
- The analysis pass (F-01 §6) treats every command, prompt and answer span as **floor**. The cut-out
  of the preceding attempt is placed before the command utterance begins.
- Retracted candidates (it was reading) are **not** cuts. The reading stays in the take.
- `voice_candidate` rows keep the scores, so thresholds can be tuned from real sessions.

## 9. Architecture

Runs on the RECORDER processor (F-01 §10.1), next to the follower. Decisions are deposited as values; the GUI applies them.

| Class | Responsibility | Key contracts |
|-------|----------------|---------------|
| `VOICE_COMMAND_SET` | Loads `voice_commands.toml`; phrases by state | `every_command_has_action`, `every_action_has_non_voice_binding` (principle 1 as an invariant) |
| `WAKE_PHRASE` | Phrase + phonetic key | `syllables >= 2` |
| `PHONETIC_KEY` | Metaphone-style key + distance | deterministic; `distance_symmetric` |
| `SCRIPT_COLLISION_INDEX` | §6 map per revision | `every_exact_occurrence_found`, `revision = script.revision` |
| `UTTERANCE_SEGMENTER` | VAD runs → utterances | `utterances_disjoint`, `ordered` |
| `COMMAND_CANDIDATE_GATE` | §5.2 step 2 | pure function of (utterance, state, follower status) |
| `COMMAND_SCORER` *(deferred)* | S_command | `result_in_unit_interval` |
| `WHISPER_GUIDED_SCORER` | Guided / grammar scoring via simple_speech | |
| `FUZZY_TRANSCRIPT_SCORER` | Phonetic match of free text | |
| `SCRIPT_FIT_SCORER` | S_script via the aligner window | `result_in_unit_interval` |
| `INTENT_ARBITER` | margin + context → tier | `collision_near_implies_not_act`, `reading_continuation_implies_retract`, `always_confirm_set_never_act` |
| `CONFIRM_MODEL` | Prompt text, countdown, answer from any surface | `answer_from_any_surface`, `timeout_is_decline` (except configured) |
| `COMMAND_RAIL_MODEL` | Visible commands per state, learning levels, heard echo | `shows_only_state_valid_commands`, `level_monotone_with_success` |
| `VOICE_CALIBRATION` | Practice-mode statistics, thresholds | `thresholds_separate_calibration_sets` |

The scorers and arbiter are pure Eiffel apart from `WHISPER_GUIDED_SCORER`. The whole decision
layer is tested headless from recorded fixtures (§11).

Ecosystem: simple_speech gains **guided scoring** and **grammar-constrained decode** wrappers
(`grammar_rules`, `grammar_penalty`, whisper.h:581-584), alongside the research D-004 additions.

## 10. Requirements

| ID | Requirement | Priority | Acceptance |
|----|-------------|----------|-----------|
| FR-V01 | Every voice action has a working key, clicker and mouse equivalent, live at the same time | MUST | `VOICE_COMMAND_SET` invariant; manual test with voice off |
| FR-V02 | One key (Ctrl+Alt+V) toggles voice on/off at any time; state shown on rail | MUST | |
| FR-V03 | Rail shows only state-valid commands with their key glyphs | MUST | |
| FR-V04 | Learning levels with automatic promotion/demotion; heard echo at Novice | SHOULD | |
| FR-V05 | Collision map built per revision; wake-phrase collision warning with alternatives | MUST | Moody script warns on "teleprompter" |
| FR-V06 | Reading script text containing command words never fires an Act-tier command | MUST | Zero Act-tier false accepts on the collision corpus |
| FR-V07 | Silent confirm prompt with countdown, answerable by voice / key / clicker / mouse | MUST | |
| FR-V08 | Continuing to read the script auto-declines a pending confirm and retracts a soft hold | MUST | Example 4 passes |
| FR-V09 | Wrap, Reject and voice edits always confirm | MUST | |
| FR-V10 | Immediate actions undoable for 3 s ("undo", Ctrl+Z, clicker) | MUST | |
| FR-V11 | Wake word detection never depends on it appearing in free transcription | MUST | Spike clips c1/c2 recognized as commands |
| FR-V12 | Number homophone normalization in argument slots | MUST | "back to" → back 2 |
| FR-V13 | Command/confirm spans go to the floor; retracted candidates don't cut | MUST | F-01 analysis fixture |
| FR-V14 | Practice mode + personal calibration | SHOULD | |
| FR-V15 | User-editable vocabulary file with re-run collision check | SHOULD | |
| FR-V16 | Voice edit "change X to Y" | COULD | Always confirmed; result shown before commit |

| ID | Non-functional | Target |
|----|----------------|--------|
| NFR-V01 | End of command utterance to action (Act tier) | ≤ 400 ms p95 |
| NFR-V02 | Soft hold on candidate | ≤ 50 ms after gate |
| NFR-V03 | False accepts (Act tier) during normal reading | ≤ 1 per hour on the reading corpus; **0** on the collision corpus |
| NFR-V04 | False rejects at Fluent level | ≤ 5% (a reject just means pressing the button) |
| NFR-V05 | Extra GPU load from command scoring | ≤ 10% (only short candidate utterances are scored) |

## 11. Test corpus and evaluation

- **Collision corpus:** scripts dense with command words (the Moody script; a purpose-written
  paragraph: "Go back again and hold that thought; yes, no, wrap it up, from the start…"), read
  continuously and with natural pauses. Metric: false accepts per tier.
- **Command corpus:** every command and variant, isolated, after pauses, after coughs, at different
  volumes. Metric: recognition rate, tier distribution, latency.
- **Sources:** SAPI TTS (already used in the spike) for regression; Larry's own practice-mode
  recordings for realism (stored locally, opt-in).
- **Harness:** headless runner feeds WAV + script + journal state through the decision layer and prints
  a confusion table. Runs in the test suite (TEST_SET_BASE asserts on the thresholds).

## 12. Risks

| ID | Risk | L | I | Mitigation |
|----|------|---|---|-----------|
| R-V1 | Guided/grammar scoring is less reliable than hoped on short phrases | MED | MED | Phonetic fuzzy backup; Confirm tier; principle 1 (button always works) |
| R-V2 | Pauses inside expressive reading look like command gaps | MED | LOW | The gate is only step 1; S_script + collision map + auto-decline catch it |
| R-V3 | Confirm prompts become nagging | MED | MED | Learning levels lower confirms as confidence grows; per-command thresholds; "confirm while learning" switch |
| R-V4 | Users forget the wake phrase mid-take | LOW | LOW | Rail shows it while READING (Novice/Familiar) |
| R-V5 | Noisy room / other voices | MED | MED | Silero VAD, NVIDIA Broadcast mic option, voice mute key, buttons |
| R-V6 | Edit-floor cuts land inside a command utterance | LOW | MED | Journal stores exact rt spans; analysis treats them as floor |

## 13. Delivery

Voice comes **after** buttons work (F-01 T-1), as a layer over the same actions:

| Step | Content | Proof |
|------|---------|-------|
| V-0 | Guided/grammar scoring spike in simple_speech on the spike clips | c1 "Prompter, again" scored as a command despite free text " again." |
| V-1 | Collision map + wake warning + rail (static, no recognition) | Moody script warns; rail renders per state |
| V-2 | Gate + scorers + arbiter, headless on the corpus | Confusion table meets NFR-V03 on TTS corpus |
| V-3 | Live: soft hold, confirm prompt, any-surface answers, auto-decline, undo | Examples 1-7 pass live |
| V-4 | Learning levels, heard echo, practice mode, calibration | |

## 14. Open questions for Larry

1. ~~**Wake phrase:** keep "Prompter", or pick something that won't collide?~~ **DECIDED 2026-10-05
   (Larry): keep "Prompter".** Collisions ("teleprompter") are handled by the collision map: a
   one-time warning at load and always-confirm near collision spans (§6, §4.1).
2. ~~**Confirm while learning:** confirm every voice command until Familiar, or only uncertain ones?~~
   **DECIDED 2026-10-05 (Larry): Option A, confirm while learning.** Setting `confirm_while_learning`
   defaults to ON: every voice command shows the silent confirm until that command reaches Familiar
   (8 successful uses, no false triggers in the last 20, §3.2), then acts immediately (Act tier, undo
   for 3 s). A command demoted back to Novice (3 failures in a session) confirms again. The user can
   turn the setting off at any time. Always-confirm cases (borderline score, collision nearby, Wrap,
   Reject, voice edit) still confirm at every level.
   **Rationale:** thresholds are uncalibrated for Larry's voice/mic/room at first; false triggers are
   likeliest early; with confirm, a false trigger is harmless (keep reading = auto-decline) while an
   immediate false action jumps the pill mid-read. Cost is ~1 s per true command, which is floor footage only.
3. **Timeout behavior for Again/Hold:** decline (safe) or accept (faster)?
4. **Wake-free commands while HELD:** on (faster) or off (stricter)?
5. **Heard echo:** useful, or distracting on camera? (It is never captured; the pill is excluded.)
