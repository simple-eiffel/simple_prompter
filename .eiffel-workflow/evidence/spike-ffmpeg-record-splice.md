# Spike: ffmpeg capture, tee and splice (2026-10-05)

## Machine facts
- ffmpeg 8.0 essentials (gyan.dev); encoders present: h264_nvenc, hevc_nvenc, av1_nvenc, libx264, aac.
- dshow video devices: "FHD Camera", "Camera (NVIDIA Broadcast)", "OBS Virtual Camera".
- dshow audio devices: "Microphone (High Definition Audio Device)", "Microphone (FHD Camera Microphone)",
  "Microphone (NVIDIA Broadcast)".
- "FHD Camera" modes: MJPEG up to 1920x1080 @ 60 fps (also 720p60 etc.); raw yuyv422 1080p only 5 fps,
  so **capture must request `-vcodec mjpeg`**.
- The webcam was NOT turned on; only `-list_options` was queried.

## Splice test (frame accuracy + speed)
Synthetic 30 s "raw take": testsrc2 1280x720@30 with burned-in pts clock + the SAPI TTS script as audio,
h264_nvenc `-g 30` (1 s GOP), AAC.
Cut list keep [0,4.2] [9.5,17.0] [21.3,30.0], one filter_complex pass: trim/atrim + setpts/asetpts +
20 ms afade in/out at each joint + concat, re-encode h264_nvenc p5 cq19.
- Render wall time: **1.05 s** for 20.4 s of 720p output.
- Output duration **20.400000** (expected 4.2+7.5+8.7 = 20.4).
- Frames at output 4.1 / 4.3 / 11.7 / 11.9 s show source clocks 00:00:04.1 / 00:00:09.6 / 00:00:21.3 /
  00:00:21.5, exactly the mapped source times, so **cuts are frame-accurate** (re-encode path).

## Tee test (one capture feeding both the file and the prompter)
`ffmpeg -re -i raw_take.mp4 -map 0 -c copy tee_rec.mp4 -map 0:a -ar 16000 -ac 1 -f f32le pipe:1`
- File: 30.000000 s. Pipe: 1,921,024 bytes = 30.016 s of 16 kHz mono float.
- The +16 ms is AAC priming in the *source* file. Lesson: record raw audio as PCM/FLAC (no encoder
  delay) so pipe sample index == recording audio timeline exactly.

## Ecosystem gap found
`SIMPLE_ASYNC_PROCESS.read_available_output` (simple_process/src/simple_async_process.e:208-229)
decodes output as UTF-8 into STRING_32 and appends to `accumulated_output` (unbounded). Unusable for a
binary PCM stream; no stdin write feature exists (needed to send `q` for a graceful ffmpeg stop).
Needs: binary chunk read into a reusable MANAGED_POINTER, no accumulation, and `write_input`.

## Addendum (spec phase, 2026-10-05): tail-file instead of pipe
`ffmpeg -re -i raw_take.mp4 ... -t 6 tail_rec.mkv -map 0:a -ar 16000 -ac 1 -f f32le -flush_packets 1 -t 6 tail.f32`,
polling the growing file size against the wall clock every ~0.6 s:
```
wall=0.59s audio_in_file=0.512s lag=0.078s
wall=1.18s audio_in_file=1.152s lag=0.029s
wall=2.37s audio_in_file=2.368s lag=-0.001s
wall=4.14s audio_in_file=4.288s lag=-0.144s
wall=5.91s audio_in_file=6.000s lag=-0.087s
```
Final file 384,000 bytes = exactly 6.000 s of 16 kHz mono f32; MKV 6.166 s.
The growing raw file keeps pace with real time (|lag| <= ~0.17 s, mostly measurement/-re burst noise).
**Consequence:** the prompter can *tail a file* instead of reading a pipe. If the GUI stalls, ffmpeg
keeps writing to disk, so the pipe back-pressure risk R-T1 disappears. Recording time = file bytes / 64,000.
ffplay 8.0 is installed (choco), so Edit Floor v1 preview is available.
