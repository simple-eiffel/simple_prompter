# Spike S-1: live microphone through ffmpeg into the tee file (2026-10-06)

Command (practice mode, PT_CAPTURE_PLAN.make_audio_only shape):
ffmpeg -f dshow -audio_buffer_size 50 -i "audio=Microphone (FHD Camera Microphone)" -ac 1 -ar 16000 -f f32le -flush_packets 1 -y live.f32

Polled the file size every 100 ms for 10 s:
- first bytes 822 ms after process start (ffmpeg + dshow startup)
- then audio kept pace with the wall clock: 9.30 s of audio in 9.22 s of wall time after the first
  bytes (the first write already held ~80 ms)
- growth per 100 ms poll: 3200..9600 bytes (real time is 6400): ~50 ms chunks, the -audio_buffer_size

Conclusion: mic-to-file delivery adds ~50 ms (chunking), well inside NFR-002 (700 ms). Start the capture
before the count-in ends (0.8 s startup). Devices seen by dshow: Microphone (FHD Camera Microphone),
Microphone (High Definition Audio Device), Microphone (NVIDIA Broadcast).
