# Debate 01 - 02 RED (deflationary, acceleration, provenance audit, champions)

S6: I read BLUE after the table, so my audit is partly sequence-led. Structure accepted: C1 chain, C5-C7 rope. F-A is three claims; "installed app" has no evidence.

## RED-1 Deflationary

| Item | Finding | Row |
|---|---|---|
| What A pays for | A per-take load (VAD + 574 MB whisper + warm-up), a spawn, a tmp+rename and poll protocol, a crash-timeout path BLUE admits it never read | 6, Gap |
| C5 insurance | No whisper/CUDA fault appears in 472 + 1222 live decodes. A is priced against an unobserved event; the take is on disk anyway (BLUE's own point) | 10 |
| Simplest C1 candidate | B: after Wrap, run the existing decoder (`whisper_full` on the one ctx, row 2), mic stopped. Needs a job state in one loop (row 4), no second model, no new C, no new exe | 2, 4 |

## RED-2 Acceleration

| Stress | Effect |
|---|---|
| 60-minute take | Decode dominates; pathways tie. Row 10 is live-paced, not batch, so full-file speed is unmeasured for all of them |
| Ten takes | A loads 10 times (10 x load_s plus 10 alloc/free of ~1.07 GB). B and D load once |
| Model twice the size | A's load doubles each take and +1071 MiB approaches 2 GB (C3). B and D pay once |
| No GPU (C6) | A, B, D end the same (marks and pads). A pays a spawn and a failed load each take |

## RED-3 Provenance audit (GR-19)

| Item | Raw check | Error as |
|---|---|---|
| **Row 13 "~30 s launch"** | `pt_speech_worker.e:91-101`: `load_seconds` spans VAD load + decoder load + `warm_up`, and line 101 prints it. The "30 s" is a human observation of launch-to-listening (app, window, mic open, load) and no `load_seconds` print is in `evidence/` (grep "to load": 0 hits). **It is not a model-load measurement.** BLUE's "C1 drops to 0.15 if load is ~30 s" rests on it | pipeline (register line 40 into BLUE ledger) |
| Row 11 "14.6 s" | Wall of a test exe: process start + 5 tests; the table says "NOT a clean load-only figure", may load more than once. BLUE's ledger calls it a "fresh-process upper bound" for C1, dropping the limits | pipeline (BLUE ledger) |
| Row 12 | Single run, 500 ms sampling, other apps; fair as a single-process figure. BLUE's 573 + 1071 = 1644 double-counts: the +1071 already includes a model | source OK, BLUE arithmetic |
| Row 10 | Real file; live-paced, so "144 s in 41 s" is NOT throughput | source OK |
| Rows 6-8 | Not re-read by me or BLUE | unchecked |

GR-22: load time is unverified, not contradicted. BLUE's C1 0.45 and 0.15 both rest on it.

## Champion B

One model in VRAM, load paid at app start and proven 2026-10-06. Row 4: a job state, not a rewrite. No new exe, ECF target or installer line (C7 lowest). Row 2: works with today's binding. C2 by SCOOP separation. Loss: a fault kills the app, not the take.

## Champion C

Leaves the proven live worker untouched. Only pathway where analysis of take N can overlap listening on take N+1, if VRAM allows. Cost: a second load until states are bound (rows 2-3), and C3 with two decoders is unmeasured.

## Champion D

Keeps A's fault domain (C5, C6) and removes A's per-take load, so C1 does not hinge on the unmeasured load figure. The job protocol is new (row 7) but the transport already exists: job file in, tmp+rename json out (rows 6-7). It is A with load amortized, and the model-size and ten-take stresses favor it.

## Challenges for BLUE

1. **Load-only time**: a P1-raw figure (VAD + decoder + warm_up, fresh process, cold and warm cache) or the 2026-10-06 `load_seconds` print. Without it C1 0.45/0.15 stand unsupported (rows 11, 13).
2. **Full-file time**: one batch decode of a 60 s+ take. Row 10 is live-paced; C1's slowest link is unmeasured.
3. **A vs D on C1**: show 10 x (load + spawn) stays within 25% of a typical take, or concede D leads A on C1.
4. **C5**: one observed whisper/CUDA fault in the record, or concede insurance against an unobserved event. State what the GUI does when the worker hangs (sr_app.e timeout, Gap).
5. **C3 overlap**: measured peak with live decoder resident plus one analysis process, or the Stop-first requirement written into A's flow (row 4). 1644 is arithmetic on a figure that includes a model.
6. **C7**: count A's new classes/targets (ECF target, CLI, JSON schema, poll, exe lookup, error states) against B's job state. The sr pattern is a one-shot quiz, not a decode pipeline.
7. **Row 11**: withdraw "upper bound" as a load bound, or show the test loads once.
