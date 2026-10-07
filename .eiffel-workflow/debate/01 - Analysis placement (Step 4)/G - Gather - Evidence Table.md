# G - Gather - Evidence Table (debate 01, as of 2026-10-07)

Declared: GR-20 discovery first; spec leaned A, orchestrator suspected B/D. Rows are neutral facts. Tier per skill profile; P1-raw = read raw or executed here.

| # | Path | Fact | Evidence | Tier | P | Version/as-of | Path:line |
|---|---|---|---|---|---|---|---|
| 1 | B,C | whisper.h offers separate states over one loaded context | `whisper_init_state(struct whisper_context * ctx)`; `whisper_full_with_state(ctx, state, params, samples, n_samples)`; `whisper_free_state` | H1 | P1-raw | whisper.cpp 1.8.2 header | whisper.h:241, 609-615, 269 |
| 2 | B,C | The shipped binding does NOT use states: it calls `whisper_full(ctx,...)` on the context's internal state, one ctx per `whisper_init_from_file_with_params` | `return whisper_full((struct whisper_context*)l_ctx, l_fp, ...)`; init at :43 | H1 | P1-raw | 2026-10-07 | simple_speech/gpu/Clib/speech_gpu.h:43,70 |
| 3 | B,C | So "two decodes, one model" needs new C externals (state init/free/full_with_state and per-state result getters); today a second decoder = a second model load | no `state` symbol in speech_gpu.h besides getters on ctx (grep `whisper_init\|whisper_full\|state`: only lines 43,53-107 hit) | H1 | P1-raw | 2026-10-07 | speech_gpu.h:43-107 |
| 4 | B | PT_SPEECH_WORKER.run exits its loop on `stop_wanted(slot)`, then closes decoder and VAD and calls `report_stopped`; "Stop" in the slot means exit of the worker, not idle. It has no job queue, only listen_wanted/stop_requested | loop `until stop_wanted (al_slot) or failed`; then `al_d.recognizer.close`, `al_v.detector.close`, `report_stopped` | H1 | P1-raw | 2026-10-07 | pt_speech_worker.e:105,121-127 |
| 5 | B | The live worker polls with `Idle_sleep_ms` sleeps when no audio; analysis inside it would sit in that same loop (no GUI-side stall by SCOOP, but microphone control shares the loop) | `sleep (Idle_sleep_ms ...)` when `l_got < Chunk_samples` | H1 | P1-raw | 2026-10-07 | pt_speech_worker.e:115-118 |
| 6 | A,D | Worker-exe pattern: GUI spawns `speed_reader_worker.exe --quiz <in> <out.json> ...`; worker writes `<out>.tmp` then `rename_file`; GUI polls from its heartbeat; exe path looked up beside the app, then in the build dir | `l_p.launch (l_cmd)`; `poll_quiz_worker`; `make_create_read_write (a_path + ".tmp")`, `rename_file` | H1 | P1-raw | 2026-10-07 | sr_app.e:782-847; worker/sr_worker.e:7,29,126-136 |
| 7 | A,D | The pattern is one-shot per job (CLI args, exit after writing). No resident/job-queue protocol exists in speed_reader; D would be new | worker usage line lists only `--quiz`; "Exit is always orderly" | H1 | P1-raw | 2026-10-07 | sr_worker.e:7-11 |
| 8 | A,D | Ship cost today: installer already ships one exe + cairo.dll + whisper.dll + ggml{,-base,-cpu,-cuda}.dll + Silero model in {app}\models; large-v3-turbo-q5_0 (574 MB) is found in {app}\models or elsewhere, not bundled. A second exe in the same {app} reuses all DLLs and models; it adds one `[Files]` line and a second ECF target | `[Files]` lines 57-64; header lines 6-9 | H1 | P1-raw | .iss as of 2026-10-07 | installer/simple_prompter.iss:6-9,57-64 |
| 9 | A | Spec A-105 reasoning: VRAM "two model copies ~1.15 GB, within NFR-004"; crash isolation; MODIFY verdict | quoted | spec | P1-raw (is a claim, not a measure) | spec as filed | spec/03-CHALLENGED-ASSUMPTIONS.md:55-63 |
| 10 | all | Live decode cost measured on this machine: mean 62-64 ms per decode, worst 159-179 ms; 144 s audio in 41 s and 334 s in 108 s were live (real-time-paced, not batch) | `472 decodes, mean 62 ms, worst 159 ms`; `1222 decodes, mean 64 ms, worst 179 ms` | S | P1-raw | run of 2026-10-06 | evidence/steps2-3-live.txt:7,20 |
| 11 | A,C,D | Fresh-process GPU test exe (loads model, 5 tests, decode 54 ms) ran end to end in 14.6 s wall incl. process start and all five tests | see Spikes | S | P1-raw | exe built 2026-10-06 10:44, F_code | spike below |
| 12 | A,C | GPU memory for ONE process holding the live-style model: baseline 2048 MiB (other apps), peak 3119 MiB = **+1071 MiB** (model 573 MB + compute buffers + VAD) | see Spikes | S | P1-raw | 2026-10-07, nvidia-smi 500 ms sampling | spike below |
| 13 | A,B,C,D | Live worker observed ~30 s launch-to-listening on 2026-10-06, unexplained (orchestrator's observation); `load_seconds` is recorded by the worker | register line 40; `load_seconds := ...` | P4 note | P4 | 2026-10-06 | register; pt_speech_worker.e:99 |

## Spikes

Harness: RTX 5070 Ti host JACKJACK, Windows 11, F_code exe `D:\prod\simple_speech\gpu\EIFGENs\simple_speech_gpu_tests\F_code\simple_speech_gpu.exe`, run from `simple_speech\gpu`, bash, warm OS file cache likely (exe built the day before; not cold-disk).
```
s=$(date +%s%N); timeout 300 $E | tail; e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms
  [gpu] 54.34 ms: This is a test of simple promises.
  PASS x5 ... Results: 5 passed, 0 failed
14606 ms
nvidia-smi --query-gpu=memory.used -lms 500  (35 samples): min 2048 MiB, max 3119 MiB
```
Limits: 14.6 s is process start + load + 5 tests, NOT a clean load-only figure; the test may load the model more than once. Single run, no cold-cache run.

## Gaps (not found = unverified)

- Load-only time and warm-up time split (the 14.6 s is an upper bound); the unexplained ~30 s launch-to-listening is not reproduced here.
- GPU memory with TWO contexts or one context + two states: not measured (needs new Eiffel/C code; barred in this seat). Row 12 is the single-context figure only.
- Whether `whisper_full_with_state` on a second state while a first decodes concurrently is thread-safe on one ctx: not checked (header does not say; source of whisper.cpp 1.8.2 not read).
- Full-file analysis time (C1): no full-file whisper pass has been run; only live-paced and 30 s-window decodes exist.
- GUI frame time during a competing GPU decode (C2): unmeasured.
- C4 stability for any pathway beyond the live worker's 2026-10-06 runs: unmeasured.
- Speed_reader worker's behavior on a crash (GUI timeout handling) not read beyond the poll function's existence.
