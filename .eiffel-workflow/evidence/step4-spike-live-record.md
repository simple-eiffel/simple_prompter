# Step 4a spike S-R1: live camera + mic recording, killed mid-take (2026-10-07)

Approved by Larry ("Yes, run it now"). Files deleted after checking; no ffmpeg left running.
**Harness:** JACKJACK, RTX 5070 Ti, ffmpeg 8.0 (Chocolatey), dshow "FHD Camera" 1920x1080 mjpeg @30 +
"Microphone (FHD Camera Microphone)". Arguments exactly as PT_CAPTURE_PLAN.make_recording builds them
(h264_nvenc p5 cq18 g30 + pcm_s16le into raw.mkv; 16 kHz mono f32le tee with -flush_packets 1).

| Check | Result |
|---|---|
| Capture start (launch to tee growing) | 1.3 s |
| Recorded (wall), then hard kill (Stop-Process) | ~10 s |
| tee.f32 | 643,136 bytes = 10.05 s of 16 kHz float |
| raw.mkv after kill | 12.06 MB; opens; h264 1920x1080 + pcm_s16le 44.1 kHz stereo; no duration in header; "File ended prematurely" on full decode (the cut cluster) |
| Copy-remux of the killed file | 62 ms; duration 9.333 s; seekable |
| Video frames | 146 decodable in 9.33 s = ~15.6 fps; ffmpeg drop_frames=0 |

**Findings**
1. **A hard kill loses the last unwritten Matroska cluster (~0.7 s here).** That can clip the last word of a take.
   For 4a: raw output gets `-cluster_time_limit 500` (with `-flush_packets 1`) so a kill loses at most ~0.5 s, and
   Wrap keeps recording ~1 s (>= the tail pad) before the stop. Proper fix: graceful stop ('q' on ffmpeg's stdin),
   which needs stdin writing in simple_process (upstream gap; spec R-?: "accept kill for now").
2. **The camera delivered ~15.6 fps, not 30**, with no ffmpeg drops: the camera itself slowed (low-light
   compensation is the usual cause). Not a pipeline fault; lighting or the camera's low-light setting decides it.
   The recorder's health line should report the measured fps so Larry sees it before a real take.
3. A killed MKV is recovered for analysis and editing by a 62 ms copy-remux (or read directly; ffmpeg decodes it).
4. The tee runs at real time alongside the encoder (10.05 s of audio for ~10 s): live following during
   recording works from the recording's own tee (sync by construction, F-01).
