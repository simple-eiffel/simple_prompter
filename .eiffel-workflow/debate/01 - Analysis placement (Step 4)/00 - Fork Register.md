# Debate 01 - Where the post-take analysis runs (Step 4) - 00 Fork Register

**Filed:** 2026-10-07 · **Mode:** code-lite (5 agents) · **Rules:** General Research ROE v1.0 (version line checked 2026-10-07); `ROE-CARD.md` is DRAFT, so seats read the General ROE, never the theological ROE.
**Budget plan (approved by Larry 2026-10-07):** gather, BLUE, RED, rebuttal = `debate-seat` (Sonnet, medium effort); adjudicator = `debate-adjudicator` (Opus, high). Caps: gather 6 KB, BLUE 6 KB, RED 6 KB, rebuttal 4 KB, verdict 10 KB. Estimate 250-350k tokens total, about 50k on Opus. Orchestrated from an Opus session (declared).

## The decision

After a take ends (Wrap), the whole recording is analyzed: a full-file whisper pass with word times, the Silero speech map, cut snapping and flags (F-01 section 6). **Where does that analysis run?**

## The pathways

| ID | Pathway | Source |
|---|---|---|
| **A** | A **worker program per analysis**: `prompter_worker.exe --analyze <session>` started on Wrap, loads the models, writes `analysis/*.json` by tmp+rename; the GUI polls | Spec A-105 (MODIFY verdict), following simple_speed_reader's worker-exe pattern |
| **B** | The **live speech worker** (`PT_SPEECH_WORKER`, already a SCOOP processor with whisper and Silero loaded) runs the analysis after Wrap, with the microphone stopped | New: the live worker exists and is proven since 2026-10-06 |
| **C** | A **second in-app SCOOP processor** for analysis, with its own whisper state | New |
| **D** | A **resident worker program**: started once at app launch, models loaded once, analyses sent to it as jobs | Simplest way to keep A's isolation without A's reload |

## Criteria, fixed before evidence

| ID | Criterion | Measure | Source |
|---|---|---|---|
| C1 | Analysis time | ≤ 25% of the recording's length, end to end from Wrap to the Edit Floor opening, model load included | NFR-T03 |
| C2 | The GUI never waits | No stall > 50 ms; frame time ≤ 16.7 ms p99 during analysis | NFR-003 |
| C3 | GPU memory | ≤ 2,000 MB total while analyzing (live model is 573 MB) | NFR-004 |
| C4 | Stability | One hour of takes, ≤ 50 MB growth, no crash | NFR-010 |
| C5 | Crash containment | A whisper/CUDA failure during analysis loses neither the recording nor the app; the take can be re-analyzed | A-105's stated reason for A |
| C6 | No GPU | The editor still opens without analysis (live marks and pads only) | NFR-008, F-01 section 6 |
| C7 | Build and ship cost | Targets, executables, DLL placement and installer changes | Ecosystem practice (simple_* first, one installer) |

## Filed claims (quantity fixed at filing)

- **F-A:** Pathway A meets C1-C7 at least as well as B, C and D, on this machine (RTX 5070 Ti) and in the installed app.
- **F-B:** Pathway B meets C1-C7 better than A, C and D.
- **F-C:** Pathway C meets C1-C7 better than A, B and D.
- **F-D:** Pathway D meets C1-C7 better than A, B and C.

## Declarations

- **S6 / GR-20 (assert-before-retrieve):** the spec leaned to **A** (A-105). The orchestrator now suspects **B** or **D**, because a per-analysis model reload looked expensive (launch-to-listening was observed at about 30 s on 2026-10-06, unexplained). Both leanings are declared; searches for either are confirmation-seeking by sequence.
- **Spike-first triage (Step 0.5):** not settled by one run. The load time (C1), memory (C3) and isolation (C5) are measurable and should be measured; the fork as a whole also turns on build cost and stability over time. Spikes the gather seat should run if cheap: model load time in a fresh process; GPU memory with one vs two whisper contexts or states.
- **Oracle check (2026-10-07):** no GOTCHA bears directly on this fork. Leads (P4): "Inline-C header statics fork per TU"; ec.sh stale-exe gotcha (read logs, check F_code timestamps).
- **Adversarial condition target:** C3 (separate contexts). Executed evidence would reach C2 under the skill's *(proposal)*.

## Inputs for the seats (read by path)

- `D:\prod\simple_prompter\speech\pt_speech_worker.e`, `pt_speech_slot.e` (the live worker)
- `D:\prod\simple_speech\gpu\src\speech_gpu_whisper.e`, `gpu\Clib\speech_gpu.h` (the binding)
- `D:\prod\whisper_cpp_build\include\whisper.h` (the C API: contexts, states)
- `D:\prod\simple_prompter\.eiffel-workflow\spec\F-01-TAKE-STUDIO.md` section 6; `spec\03-CHALLENGED-ASSUMPTIONS.md` A-105
- `D:\prod\simple_speed_reader` worker pattern (`sr_worker.e`, `sr_app.e`) for A/D
- `D:\prod\simple_prompter\.eiffel-workflow\evidence\steps2-3-live.txt` (measured decode times)
