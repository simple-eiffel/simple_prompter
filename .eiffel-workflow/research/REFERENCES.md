# REFERENCES: simple_prompter

All URLs below were fetched or returned in search results during research on 2026-10-05.
Items marked [snippet] were seen only in search-result text.

## Source material
- `C:\Users\LJR19\Videos\simple_prompter.mp4`: Moody reel; analysis in `../evidence/video-analysis.md`.

## Products
- https://moody.mjarosz.com: Moody features, $39, macOS 15+, "only you can see the prompter", noise caveat.
- https://cuenotch.com/blog/best-macbook-notch-teleprompter-apps-2026: notch app comparison (Moody "volume-based").
- https://stevechazin.com/best-mac-notch-teleprompter-apps-in-2026/: Tellie word tracking; Moody "sound-based".
- https://www.producthunt.com/products/notchie: Notchie voice pacing, noise suppression, hidden from share.
- https://appsumo.com/products/promptsmart/: PromptSmart VoiceTrack.
- https://sharespeak.co/ and https://sharespeak.co/best-teleprompter-windows: ShareSpeak; Windows comparison table (competitor-authored).
- https://ghost-prompter.com/: GhostPrompter, Windows, click-through, hidden.
- https://flowprompter.app/: FlowPrompter, "AI voice tracking".
- https://www.speakflow.com/: Speakflow.
- https://www.voice-scroll.com/blog/free-teleprompter-for-windows: placement advice (narrow column near lens).
- https://www.voice-scroll.com/blog/free-teleprompter-for-mac: QPrompt notes.
- https://riverside.com/blog/best-teleprompter-software: external webcam placement.

## Repositories examined
- https://github.com/cyberhunter73/moody-windows: Electron clone; `setContentProtection(true)`; hotkeys.
- https://github.com/ubaniebereo/glass-prompter: Python/Qt, offline ASR, hidden from capture.
- https://github.com/Sven-Bo/talkprompter: C# WPF, Vosk + sherpa-onnx, camera-strip mode.
- https://github.com/JoeKarlsson/followspot: whisper.cpp server, 3.5 s window / 0.25 s step, Smith-Waterman, coast logic, Silero VAD, `-ac 512`.
- https://github.com/872pcjb72g-dot/ScriptFollower: forward-only bounded-window fuzzy alignment.
- https://github.com/f/textream: three modes (word tracking / constant / voice-activated).
- https://github.com/ggml-org/whisper.cpp: CUDA build flag, VAD flags.
- https://github.com/ggml-org/whisper.cpp/releases/tag/v1.7.6: VAD introduced.
- https://github.com/ggml-org/whisper.cpp/tree/master/examples/stream: `whisper-stream` (naive example).
- https://github.com/ggml-org/whisper.cpp/blob/master/examples/cli/README.md: `--prompt` initial prompt.
- https://huggingface.co/ggml-org/whisper-vad: `ggml-silero-v6.2.0.bin` (downloaded to simple_speech/models).
- https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/c-api/c-api.h: streaming C API, provider=cuda, hotwords.
- https://k2-fsa.github.io/sherpa/onnx/install/windows/build-cuda.html: Windows CUDA build.
- https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html: streaming models.
- https://github.com/alphacep/vosk-api/blob/master/src/vosk_api.h: grammar recognizer.
- https://github.com/k2-fsa/sherpa-onnx/issues/790: NeMo streaming export discussion.

## Articles / papers
- https://arxiv.org/abs/2307.14743: Whisper-Streaming / LocalAgreement, 3.3 s latency.
- https://arxiv.org/html/2401.09200: real-time lyrics alignment, 160 ms chunks, DTW/HMM.
- https://huggingface.co/blog/nvidia/nemotron-speech-asr-scaling-voice-agents: Nemotron streaming latency/WER.
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12439499/: "Don't look at the camera", eye contact peaks ~2 deg below lens.
- https://www.researchgate.net/publication/221514782_Leveraging_the_asymmetric_sensitivity_of_eye_contact_for_videoconference: Chen CHI 2002 [snippet; 403 on fetch].

## Windows API
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity: WDA_EXCLUDEFROMCAPTURE (0x11), Win10 2004+, top-level window of calling process.
- https://learn.microsoft.com/en-us/archive/msdn-technet-forums/7ce400f0-ebda-4b95-869c-85b5b93f972d: affinity unsupported for UpdateLayeredWindow windows.
- https://github.com/robmikh/Win32CaptureSample/issues/51: same.
- https://learn.microsoft.com/en-us/answers/questions/700122/setwindowdisplayaffinity-on-windows-11: error 8 reports on Win11.
- https://www.interviewpilot.in/blog/does-zoom-teams-meet-detect-screen-overlays/ and https://shadowclaude.com/blogs/invisible-screen-share-how-it-works: which captures honor affinity (third-party).

## Ecosystem files (read-only sweep)
- simple_speech: src/simple_speech.e:148,167; src/engines/whisper_engine.e:93,108; Clib/whisper.h:505,562,574,655,667,680-719; Clib/whisper_wrapper.c:9,21; README.md:33.
- whisper_cpp_build: build/CMakeCache.txt (GGML_CUDA OFF), v1.8.2 commit 4979e04.
- simple_audio: Clib/audio_bridge.h:76; audio_device.e:173; AUDIO_RECORDER.
- simple_shell: Clib/simple_shell.h:49,412,424,640-652,715-720; shell_window.e:123.
- simple_cairo: cairo_gradient.e:35-82; cairo_context.e:399-415; simple_cairo.e:109-120.
- simple_widgets: SW_PAINTER :47,194,230,296; sw_window.e:592; speechkit/sw_dictation.e:62-93.
- simple_ocr_capture: ocr_hotkey.e:57,63,97; Clib/ocr_hotkey.h:86; ocr_settings.e:644.
- simple_ai_client: ollama_client.e:281.
- simple_chat: src/client/summary_slot.e; client_app.e:24-34.
- simple_taskman: src/handoff/tm_sampling_worker.e; spec/03-CHALLENGED-ASSUMPTIONS.md A-103.
- simple_speed_reader: app/sr_app.e:182-193; worker/sr_worker.e; installer/simple_speed_reader.iss.
