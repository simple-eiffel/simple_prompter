# 10 ADDENDUM: design changes made while writing contracts (Phase 1, 2026-10-05)

Where this file and 04-09 disagree, the code and this file win.

| Change | Why |
|--------|-----|
| `PT_ACTION.Note` / `PT_EVENT_KIND.Note` / controller `note` renamed to **`Marker`** / `make_marker` / **`add_marker`** | `note` is an Eiffel reserved word (oracle gotcha recorded) |
| `PT_SCRIPT_PARSER.last_revision` is always attached (empty placeholder) + `has_parsed` | Postconditions without object tests (VUOT(1) on repeated `attached ... as` in one ensure; oracle gotcha) |
| `PT_FOLLOWER.rescale (word_count)` added | Live edits change the word count; the follower must clamp its target |
| `PT_WORD_TIMELINE` lookups are per attempt (`occurrence_in`, `has_in`) | A word read in several attempts (retakes) has several occurrences |
| `PT_TAKE_SOLVER.solve (history, attempts, timeline)` | The final revision comes from the history (stale-take check needs the attempt's revision); the speech map belongs to the snapper |
| `PT_CAPTION_CUE` added (output) | Cues carry word ids so the caption contract can compare them with the cut list |
| `PT_SPEECH_CODEC` moved from speech/ to the pure library (follow/) | It is pure; testable headless |
| `SIMPLE_PROMPTER.make_with_settings (PT_SETTINGS)` is the only creation procedure | Settings path resolution (%APPDATA%) belongs to the app; tests inject in-memory settings |
| `PT_TAKE_CONTROLLER.again_target` returns 0 for an empty script (no precondition) | `old again_target` is evaluated on entry for every action |
| `PT_KEYMAP` default bindings contain no bare keys; clicker keys are added by the user (`is_bare_while_recording`) | Modifier interlock; bare keys only while recording |
| Transitions table has **34** pairs (2+6+8+15+2+1) | Counted from 07 section 2.6 |
| `TEST_SCOOP_CONSUMER`: separate creation of a pipeline with local VAD/decoder objects removed | That would pass this processor's objects to another processor; the worker builds its own pipeline on its processor (Phase 4 design rule) |

## Class count
Library: **84** classes (82 planned + PT_CAPTION_CUE + PT_SPEECH_CODEC moved in). Tests: 11 classes, 78 tests.

## Phase 2 review fixes applied (2026-10-05, approved by Larry)

| Review | Change in code |
|--------|----------------|
| H1 | One position convention: PT_FOLLOWER.target and PT_ALIGNER.position = **words already read**; caret k → `set_caret (k - 1)`, `reanchor (k - 1, sample)`; controller `resumes_at_caret: follower.target = (caret - 1)`; facade prompt = text before the reader's word |
| H2 | PT_SCROLL_MODEL.tick: `snaps_back` / `forward_otherwise` postconditions; no dependency on `caret_changed` |
| H3 | PT_ALIGNER.reanchor (words_read, at_sample) + `reanchored_at`; `update` ensures stale windows are ignored; facade reanchors on Count_in_done using PT_RECORDING_CLOCK.sample_count (new) |
| H4 | SIMPLE_PROMPTER.commit_edit + `rewire` (aligner, layout, follower); perform rewires after a revision (Skip); O(1) invariant `follows_current_revision` |
| H5 | NEW PT_CONTROL (logical controls) + PT_CONTROL_RESOLVER (control + state → action); PT_KEY_BINDING carries a control; PT_KEYMAP keyed by combo (several keys per control; rebinding replaces), `bind_clicker_defaults` (PageUp/PageDown/B/".", bare while recording) |
| H6 | PT_CAPTURE_PLAN `-audio_buffer_size 50` (Audio_buffer_ms) + postcondition |
| H7 | NEW PT_EQUIVALENCES (homophones, spoken abbreviations, number words, compounds; phonetic key = Phase 4); PT_WORD_MATCHER owns it; `equivalent_matches` postcondition |
| M7 | Controller stores `last_again_target` (no `old again_target` on every action) |
| M8 | Controller `is_allowed`: no Play/Record with an empty script |
| M15 | Folded into H5 (one control per combo) |
| M16 | Facade `load_script_text` requires not recording |
| M24 | PT_WORD.is_heading + `is_required`; `spoken_ids_model` = required words only; parser `headings_flagged` |

Remaining MEDIUM/LOW items (M9-M14, M23, L17-L21, L25) go to /eiffel.tasks as acceptance criteria.
Library classes: 87 (+ PT_EQUIVALENCES, PT_CONTROL, PT_CONTROL_RESOLVER). Tests: 12 classes, 94 tests.
