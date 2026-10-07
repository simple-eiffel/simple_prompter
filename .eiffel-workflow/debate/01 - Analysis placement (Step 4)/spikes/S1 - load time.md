# Spike S1 - model load time, measured on the installed app (answers RED Challenge 1)

**Run by:** the orchestrator, 2026-10-07, after RED filed Challenge 1. **Provenance:** P1-raw (executed this cycle; screenshot in this folder).
**Harness:** JACKJACK, RTX 5070 Ti, installed simple_prompter 0.2.1 (finalized F_code, contracts on), ggml-large-v3-turbo-q5_0 on the GPU, Silero on the CPU; models read from D:\prod\simple_speech\models.

| Measurement | Value | How |
|---|---|---|
| Launch to microphone tee file created | **32.5 s** | PowerShell: Start-Process, then poll for %TEMP%\simple_prompter_live.f32 every 0.5 s |
| Model load + warm-up inside PT_SPEECH_WORKER.run | **1 s** (rounded) | The worker's own `load_seconds` (now_ms before both models' creation to after `warm_up`, pt_speech_worker.e), shown in the status line: "listening: Microphone (FHD Camera Microphone) (speech loaded in 1 s)" - see `status-load-time.png` |

**Reading.**
- Loading whisper + Silero and one warm decode costs about **1 s** in a process that already exists. A per-analysis worker (A) pays this once per analysis, plus process start.
- The **~31 s** remainder of launch-to-listening is **not model load**. It lies before `run` starts or between Ready and the microphone starting; it is a separate defect in the app, outside this fork. The figure "~30 s launch" must not be used as a model-load cost (Do-not-assume candidate).
- Not measured here: process start of a separate exe with its DLLs (the GPU test exe's whole 5-test run took 14.6 s, row 11, which bounds it from above), and full-file analysis time (RED Challenge 2).
