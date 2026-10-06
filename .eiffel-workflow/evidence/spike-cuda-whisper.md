# Spike: CUDA whisper.cpp on the RTX 5070 Ti (2026-10-05)

Goal: validate A-1 (CUDA build for Blackwell) and A-2 (rolling-window decode fast enough for tracking).

## Build
- Source: D:\prod\whisper_cpp_build (whisper.cpp v1.8.2, 4979e04), existing build/ and build_avx2/ untouched.
- New dir: `D:\prod\whisper_cpp_build\build_cuda` via VS2022 vcvars64 + bundled CMake 3.31.6 + Ninja
  (VS has no CUDA MSBuild integration, so the VS generator can't do CUDA).
- `cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120 -DBUILD_SHARED_LIBS=ON -DWHISPER_BUILD_TESTS=OFF`
- nvcc 13.0.88. 166 ninja steps, BUILD_OK. Outputs: whisper.dll, ggml.dll, ggml-base.dll, ggml-cpu.dll,
  **ggml-cuda.dll**, whisper-cli/server/bench, vad-speech-segments.
- Script: scratchpad build_cuda.bat (contents above).

## A-1 result: PASS
```
ggml_cuda_init: found 1 CUDA devices:
  Device 0: NVIDIA GeForce RTX 5070 Ti, compute capability 12.0, VMM: yes
whisper_model_load:        CUDA0 total size =   573.45 MB
system_info: ... CUDA : ARCHS = 1200 ...
```

## A-2 result: PASS (by a wide margin)
whisper-bench, warm, `-t 8`:
| Model | encode (30 s ctx) | decode per token (batchd) |
|-------|-------------------|---------------------------|
| large-v3-turbo-q5_0 | 36.53 ms | 0.61 ms |
| base.en | 3.83 ms | 0.35 ms |

Resident `whisper-server` (large-v3-turbo-q5_0, greedy `-bs 1 -bo 1`, `--vad -vm ggml-silero-v6.2.0.bin`),
HTTP round trip with curl, 3 s / 2 s windows cut from a 32 s SAPI TTS read of the Moody script:
| Request | Latency | Text |
|---------|---------|------|
| 3 s speech, first (cold kernels) | 117-231 ms | " during video recordings, online meetings, present" |
| 3 s speech, warm (no_context) | 53-63 ms | same, stable |
| 2 s speech, warm | 52-58 ms | " during video recordings, online" |
| 3 s speech + pink noise a=0.08 | 63 ms | " during video recordings, online meetings, presentation," |
| 3 s pink noise only | 6-8 ms | "" (Silero VAD rejects it before decode) |

`verbose_json` returns per-word start/end and probability: what the aligner needs.
Cold single-shot `whisper-cli` encode was 408 ms with 5.7 s model load, so **the model must stay
resident and be warmed once at startup**.

Conclusion: a 3 s window every 250 ms costs ~60 ms of GPU, a ~25% duty cycle. Tracking update
latency is ~250 ms step + ~60 ms decode + alignment (microseconds), well inside NFR-002 (700 ms).

## Two gotchas found (both would silently wreck tracking)
1. **Context carry-over across calls.** With `no_context=false` (whisper-server default), repeated
   decoding of the same/overlapping window returns truncated text (" and present") because the
   state's rolling `prompt_past1` (src/whisper.cpp:6893-6937) makes the model think the words were
   already said. Library default `whisper_full_default_params` has `no_context = true`
   (src/whisper.cpp:5912). **Sliding-window decoding must set no_context = true.**
2. **Prompting with upcoming script text makes whisper hallucinate.** Prompt = the 17 words *ahead*
   produced " and that we can also do a lot of things that we can do in the future." The prompt
   means "text already spoken". Prompt = the script text *before* the window was harmless and stable.
   **Bias with the already-read script text only (I-003 corrected).**

## Not measured (open)
- CPU-only fallback latency (base.en on CPU) for NFR-008.
- Real microphone path (simple_audio WASAPI to 16 kHz): next spike.
- GPU contention with OBS NVENC / Ollama running concurrently.
