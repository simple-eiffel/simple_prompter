# Debate 01 - 04 VERDICT: where the post-take analysis runs (Step 4)

**Adjudicator:** debate-adjudicator (Opus), 2026-10-07. **Status:** GATED - **adopted by Larry 2026-10-07** ("adopt B"). Condition C1 for adoption (thesis-holder on the record).

## 0. Declarations

| Item | Ruling |
|---|---|
| ROE | General Research ROE **v1.0, October 6, 2026** (read in full 2026-10-07). Theological ROE not read |
| Adversarial condition | **C3** (separate seats, one model family, no named external human engaged). **C2** under the skill's executed-evidence *(proposal)*: S1, S2 and gather rows 11-12 are executed runs |
| Declared interest | None. The fork is about whisper.cpp and SCOOP, not about Anthropic or Claude (no -i) |
| My reads | P1-raw: `pt_app.e:57-75,468-487,536-552,612-648`; `pt_speech_worker.e:74-262`; `speech_gpu.h:40-70`; `whisper.h:566-575`; spec A-105, NFR table. **Spike S2** run by me (below) |
| S6 | I read BLUE and RED before my raw reads, so the reads were aimed at their cruxes (sequence-led). S2 could have failed: a live footprint under ~830 MiB would have let A and D pass C3. It did not |

**Spike S2** (P1-raw; JACKJACK, RTX 5070 Ti; installed simple_prompter 0.2.1; `nvidia-smi` every 0.5 s for 55 s). Baseline 2051-2077 MiB. GPU jumped at **35.5 s** after launch; tee file at 36.6 s. Then steady **3144 MiB**, so the **resident live worker = +1067 to +1093 MiB**. After the kill it was back to 2077. Gather row 12 (a different exe, same model) measured +1071. Two runs agree.

## 1. Procedural rulings

| Item | Ruling |
|---|---|
| Ripe (Rule 8)? | Yes. The rebuttal engages all 7 challenges; S1 settled crux 1; my reads and S2 settle C3 and B's feasibility |
| Splits (G1-G5) | F-A is three claims (A vs B / C / D), as BLUE declared. C splits into **C-ctx** (second context) and **C-state** (whisper states, new C) |
| Re-specified (16-D) | In rebuttal 5 BLUE added Stop-first to A. Relabeled **A'** (stop the live worker at Wrap, spawn the analysis exe, restart live). A as filed (live model resident) is scored separately |

## 2. External confrontation

| Executed | Read raw | Engaged / unread |
|---|---|---|
| S1 (load + warm-up = 1 s), S2 (live footprint), rows 10-12 | Binding, whisper.h, worker loop, app lifecycle | No maintainer or practitioner engaged. Unread, so no weight: whisper.cpp source on state thread-safety; sr_app.e timeout path |

## 3. Scored ledger (confidence / rootedness, never merged)

| Element | Conf | Root | Status | Decisive data |
|---|---|---|---|---|
| **B** (job in the live worker) | **0.65** | **0.80** | **PREFERRED** | Only pathway with one whisper footprint (~1.08 GB). No spawn and no reload (C1). Lowest build cost (C7, conceded). Loses C5 |
| A' (exe + Stop-first) | 0.45 | 0.75 | UNSUPPORTED vs B | Passes C3 only by stopping and restarting the live worker every take. That adds in-process CUDA churn (C4) and spawn+load+restart cost (C1). Wins C5 |
| A as filed | 0.10 | 0.85 | **DISPROVEN** (C3) | The live worker stays resident all session (`pt_app.e:69,75`): ~1.08 + ~1.07 GB ≈ 2.15 GiB > 2,000 MB |
| D as filed | 0.10 | 0.80 | **DISPROVEN** (C3) | Two resident whisper processes, the same ≈ 2.15 GiB |
| C-ctx | 0.10 | 0.80 | **DISPROVEN** (C3) | A second context = a second load (rows 2-3), same sum |
| C-state | 0.30 | 0.55 | UNTESTED | State memory and thread safety unmeasured; needs new C externals |
| L1 live footprint ≈ 1.07-1.09 GB, not 573 MB | 0.85 | 0.95 | ESTABLISHED | S2 + row 12 |
| L2 load + warm-up ≈ 1 s | 0.85 | 0.95 | ESTABLISHED | S1; S2 shows the ~1 s GPU ramp |
| L3 "~30 s launch is model load" | 0.05 | 0.20 | DISPROVEN | S1, S2: 35 s pass before the GPU allocates at all |
| L4 A-105 "two copies ≈ 1.15 GB, within NFR-004" | 0.05 | 0.30 | DISPROVEN | Measured ≈ 2.15 GiB |
| L5 Analysis ≤ 25% of length (any pathway) | - | - | UNTESTED | No batch full-file run exists |
| L6 A full-file pass can fault CUDA | - | - | UNTESTED | 1,694 clean live decodes do not test a full-file pass (GR-10) |

Errors logged (GR-19): "live model 573 MB" means the file size, but register C3, A-105 and BLUE's 573 + 1071 all read it as resident memory (**pipeline**). BLUE's "worker closes its decoder on stop, so it is not co-resident" is wrong (**pipeline**: Stop means app exit). RED's "double-count" is wrong in direction (the sum is too low, not too high).

## 4. Deployment lines

| Claim | Rely on | Must not rely on |
|---|---|---|
| F-A | A' ≥ C-ctx and ≥ D (C3) | A ≥ B |
| C5 containment | A' contains an analysis fault; the live path already runs whisper in-process (D-003) | "B loses the take": that depends on the recording being closed before analysis, under every pathway |
| "B needs no new C" | No state API needed; `token_timestamps` already on (`speech_gpu.h:64`) | Reusing the live decode for a full file: `max_tokens = 40`, `no_context`, and the live prompt are tuned for 3 s windows |
| C2 under B | The GUI touches only the slot (`pt_app.e:612-648`) | That analysis code may hold the slot: `pump` reserves it across a decode (`pt_speech_worker.e:180`), so a GUI `take_speech` waits |

## 5. THE DECISION

**B: run the analysis as a job in PT_SPEECH_WORKER after Wrap, mic stopped, on the already-loaded context. PREFERRED, not ESTABLISHED:** A' still fits the decisive C3 datum, and absolute C1 is unmeasured.

Grounds: C3 rules out D, C-ctx and A as filed. Between A' and B, B wins C1 and C7 and is simpler on C3. A' wins C5 against a fault never observed, and the app already accepts that risk for live listening.

| Overturns B -> A' | Trigger |
|---|---|
| A whisper/CUDA fault kills the app during a full-file pass | Any crash in V1, V4 or V5 |
| C4 growth from analysis | V5 soak > 50 MB/h attributable to analysis jobs |
| The GUI stalls even with the slot unreserved | V3 shows a stall > 50 ms during an analysis job |
| **Reopens D / C-state** | |
| Co-resident peak ≤ 2,000 MB | V2 measures it |
| A state costs ≤ ~400 MB and is thread-safe on one context | C-state spike plus a whisper.cpp source read |
| NFR-004 raised or the model changed | Spec edit / new model file |

## 6. Do not assume

| Statement | Why |
|---|---|
| "The live model uses 573 MB of GPU" | 573 MB is the file; resident ≈ 1.08 GB (S2) |
| "Two whisper processes fit in 2 GB" | ≈ 2.15 GiB (L4 DISPROVEN) |
| "~30 s of startup is model load" | Load is 1 s; the delay precedes GPU allocation (S1, S2) |
| "The live worker frees the GPU between takes" | It runs until the window closes (`pt_app.e:69,75`) |
| "The live decode call can transcribe a whole file as is" | Its limits are tuned for 3 s windows (`speech_gpu.h:58-69`) |
| "SCOOP alone keeps the GUI from waiting" | Not while the worker holds the slot |
| "144 s in 41 s" is batch throughput | Live-paced (row 10) |
| The 14.6 s test-exe wall time is a load time | Five tests plus process start (row 11) |

## 7. Verification queue (Step 4 runs these)

| # | Spike | When |
|---|---|---|
| V1 | Batch decode of 10 s and 60 s recordings on the live context (VAD-chunked, or a full-file params entry): time ≤ 25%? | Before building |
| V3 | GUI `take_speech` wall time while the worker decodes. Analysis jobs reserve no slot; progress goes through short `report` calls | While building |
| V4 | App close mid-analysis: the job checks `stop_wanted` between chunks (or uses the `abort_callback`, `whisper.h:574`, not yet bound); orderly exit inside `stop_speech`'s 3 s | While building |
| V6 | The recording file is closed and flushed before analysis starts | While building |
| V7 | No GPU: worker Failed -> editor opens on live marks and pads | While building |
| V5 | 1-hour soak, takes + analysis, ≤ 50 MB growth | Before ship |
| V2 | Co-resident peak (live app + second whisper process); only if D or C is proposed again | On demand |

## 8. Consequences for spec

| Change |
|---|
| Reverse the analysis half of A-105's MODIFY: no `prompter_worker` target, no installer line. Fix the notes in `PT_SESSION_ANALYZER` / `PT_TRANSCRIBER` ("runs in the worker exe") |
| `08-VALIDATION` NFR-004 row ("573 + 573 ✓") is wrong: per-process ≈ 1.08 GB; B ≈ 1.08 GB total |
| New requirements: an analysis job state in the worker loop; no slot held during decode; chunked and abortable; full-file decode params kept separate from live params; recording closed before analysis |
| Known costs: a CUDA fault during analysis kills the app (the take survives on disk, per V6); voice following for the next take waits for analysis (≤ 25% of the take). A' stays the documented fallback |

## 9. Open items for Larry

| # | Item |
|---|---|
| 1 | ~~Adopt B (gate).~~ **Adopted 2026-10-07 (Larry: "adopt B").** Accepted with it: the C5 trade (an in-process crash ends the app, not the take) |
| 2 | ~~The ROE card is DRAFT.~~ **Approved by Larry 2026-10-07** (card v1.0); later cycles' seats read it |
| 3 | The executed-evidence reading (C3 -> C2) is a skill **(proposal)**, ungated |
| 4 | For the orchestrator, not a question: an **orphan ffmpeg (PID 36524, started 2026-10-06 09:50)** holds the microphone and is writing scratchpad `live_spike.f32` (5.19 GB so far). Separately, `CloseMainWindow` did not close the app within 6 s during S2. I force-killed it and removed my own orphan ffmpeg child; the GPU returned to baseline |
