# Debate 01 - 01 BLUE Opening (Pathway A, worker program per analysis)

## Declarations

| Item | Declaration |
|---|---|
| Lens (GR-7) | Fault-domain-first engineering: the pathway that fails safely and ships with least new machinery wins ties; speed is bought back only where measured. |
| Structure (GR-9) | **Hybrid.** Rope across C5, C6, C7 (independent strands: containment, no-GPU path, ship cost; any one holding keeps F-A alive). **Chain inside C1** (load, then decode, then write; the slowest link sets the time). |
| Composite claims | F-A "at least as well as B, C and D" is **three claims** (A vs B, A vs C, A vs D), scored separately. "On this machine and in the installed app" is two scopes; only this machine has evidence. |
| Provenance (S1) | Evidence rows 1-8, 10-12 are P1-raw H1/S from the gather seat, not re-read by me except where noted. Row 9 (A-105) is a claim, not a measure. Row 13 is P4. Nothing here is model recall. |
| S6 | I was assigned A, the spec's lean; my searches are confirmation-seeking by sequence. Declared. |

## Alignment ledger

| Criterion | A's position | Evidence | Confidence A meets it (0-1) |
|---|---|---|---|
| C1 Time <= 25% of length | Unproven. Load is paid per analysis; fresh-process upper bound 14.6 s (includes 5 tests). Meets for takes >= ~60 s only if load is under ~15 s; fails for short takes. Decode cost is small (62-64 ms per live decode). | Rows 10, 11, 13; Gaps: no full-file pass run | 0.45 |
| C2 GUI never waits | Separate process: no shared heap, no shared SCOOP region, no GC contention; GUI only polls a file. Frame time under a competing GPU decode is unmeasured. | Row 6 (poll from heartbeat); Gap C2 | 0.80 |
| C3 GPU <= 2,000 MB | One analysis process adds +1071 MiB (measured, peak 3119 vs baseline 2048). Analysis runs after Wrap with the mic stopped, and the live worker closes its decoder on stop, so live 573 MB is not co-resident. Even with it resident, 573+1071 = 1644 < 2000 (arithmetic from rows 4, 12, register). | Rows 4, 12 | 0.80 |
| C4 Stability 1 h | Each analysis is a fresh process: leaks die with the process, so growth cannot accumulate in the GUI. Not run for A. | Row 6 (one-shot, orderly exit); Gap C4 | 0.65 |
| C5 Crash containment | A's strongest strand. A whisper/CUDA fault kills only the worker; the recording is already on disk; re-analysis is a re-launch. B and C share the app's address space. | Rows 6, 2 (whisper called in-process in the binding) | 0.90 |
| C6 No GPU | Worker failure or absent GPU means no `analysis/*.json`; the GUI opens the editor on live marks and pads. A missing-file state is already the poll protocol. | Row 6 | 0.85 |
| C7 Build and ship cost | Lowest new machinery: copy of a working pattern (sr_worker/sr_app); one `[Files]` line, one ECF target, all DLLs and models reused. B and C need new C externals for states; D needs a new job protocol. | Rows 3, 7, 8 | 0.85 |

## Concessions (GR-2)

| Datum | Standing | Number changed |
|---|---|---|
| Row 9: A-105's "two model copies ~1.15 GB" was an estimate. Row 12 measures +1071 MiB for one process; the "two copies" figure was never measured and is not the live+analysis case anyway. | Stands as unmeasured; I do not rely on it | A-105's VRAM reasoning removed; C3 rests on row 12 only (0.80, not higher) |
| Rows 10, 11, 13 and Gap C1: no full-file analysis time exists, and per-analysis load is a real cost. D pays load once; A pays it every take. | Stands. On C1 D probably beats A | C1 for A set at 0.45 |
| Row 13: the ~30 s launch-to-listening is unexplained. If it is model load, A fails C1 for every take under about 2 min (30 / 0.25). | Open, unresolved; cheap spike would settle it (load-only time) | Contingent: C1 drops to ~0.15 if load is ~30 s |
| Row 7: speed_reader's pattern is one-shot; A's crash-timeout handling was not read (Gap). | Stands | C4/C5 not above 0.90 |

## Against B, C, D

| Pathway | Strongest one-line objection | Row |
|---|---|---|
| B | The live worker has no job queue and "stop" means the worker exits and closes its models, so analysis there means redesigning its loop, and a CUDA fault takes the app with it (C5). | 4, 5 |
| C | A second in-app processor with the shipped binding means a second model load (no state API in use) or new C externals, plus the same shared-address-space crash risk as B. | 2, 3 |
| D | It is A plus a new resident-job protocol that nothing in the ecosystem has, plus a ~1 GB-class process resident all session; its C1 edge is real, but it buys it with the most new code. | 7, 12 |
