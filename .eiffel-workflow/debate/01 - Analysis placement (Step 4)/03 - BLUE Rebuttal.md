# Debate 01 - 03 BLUE Rebuttal (Pathway A)

| # | Verdict | Answer | Number changed |
|---|---|---|---|
| 1 | CONCEDE (resolved by S1) | S1 (P1-raw, installed 0.2.1, 2026-10-07): model load + warm-up = 1 s via the worker's own `load_seconds`. The "~30 s" was launch-to-mic, not load (RED-3 correct; I carried register line 40 into my ledger unchecked). My "C1 ~0.15 contingent" branch is dead. Cold-cache and separate-exe start are NOT measured. | C1: 0.45 -> 0.65 (not higher: spawn, DLL start and full-file decode unmeasured) |
| 2 | CONCEDE | No batch full-file time exists for any pathway; row 10 is live-paced. C1's slowest link is unmeasured for A, B, C and D alike. Decode cost is pathway-independent (same ctx, same GPU), so it does not separate A from B/D; it does leave absolute C1 open. | none beyond row 1 |
| 3 | CONCEDE direction, NARROW size | D beats A on C1 by (load 1 s + spawn) per take. 10 takes = 10 s plus 10 spawns, against a 25% budget of 15 s per 60 s take. The margin is real but small at 1 s; spawn is unmeasured, so I cannot show "within 25%" beyond load alone. Model-twice-size stress: load would scale to ~2 s, still small. | C1 A-vs-D: D leads, margin ~1 s + spawn |
| 4 | CONCEDE | No whisper/CUDA fault in 472 + 1222 live decodes; C5 is insurance against an unobserved event. The take is on disk either way. A's timeout/hang path (sr_app.e) is still unread; I do not claim it. Remaining C5 value: a fault costs a re-launch, not the app. | C5: 0.90 -> 0.75 |
| 5 | NARROW | RED's "double-count" is wrong for the live-resident case: +1071 includes the analysis process's own model, and live 573 is a separate resident model, so 573 + 1071 = 1644 is the correct co-resident sum (assuming the +1071 delta holds, one run, 500 ms sampling, other apps). Concede it is arithmetic, not a measured peak. Also concede Stop-first is not written into A's flow; analysis starts on Wrap, mic stopped, and I now state that as a requirement. | C3: 0.80 -> 0.75 (single run, arithmetic) |
| 6 | CONCEDE | A adds: ECF target, CLI parse, JSON schema, tmp+rename write, poll, exe lookup, error states (about 6 items). B adds one job state in one loop. sr is a one-shot quiz pattern, not a decode pipeline. C7 is not "lowest"; B is. A only wins C7 against C and D. | C7: 0.85 -> 0.55 |
| 7 | CONCEDE | Withdrawn as a load bound. S1 supersedes it (1 s). Row 11 stays only as a loose upper bound on process-start plus 5 tests. | none (already folded in row 1) |

**Revised A confidences:** C1 0.65, C2 0.80, C3 0.75, C4 0.65, C5 0.75, C6 0.85, C7 0.55.

**Champion:** A, narrowly, not D. S1 removes the load argument against A, so D's only edge is about 1 s plus spawn per take, bought with a new resident-job protocol and a ~1 GB process held all session. But A no longer clearly beats B on C7 or on C1/C3 simplicity, and I concede F-A's "at least as well as B" is now my weakest of the three claims.

**Most important concession:** Challenge 6 (C7), then 4. A's cost is no longer cheaper than B's, and C5 is insurance for an unobserved fault.
