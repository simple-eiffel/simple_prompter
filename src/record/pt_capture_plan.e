note
	description: "[
		The ffmpeg capture command: the single place its arguments are decided.
		Recording: dshow MJPEG camera + mic -> raw.mkv (h264_nvenc, 1 s GOP, PCM
		audio) AND 16 kHz mono f32 -> tee.f32 with per-packet flush (spike
		evidence: MJPEG needed for 1080p; PCM avoids encoder delay; the growing
		tee file tracks real time). Practice (approved Q4): microphone only -> tee.f32.
	]"
	author: "Larry Rix"

class
	PT_CAPTURE_PLAN

create
	make_recording, make_audio_only

feature {NONE} -- Initialization

	make_recording (a_ffmpeg: READABLE_STRING_32; a_devices: PT_DEVICE_CHOICE; a_raw_path, a_tee_path: READABLE_STRING_32)
			-- Camera + microphone recording with tee.
		require
			ffmpeg_present: not a_ffmpeg.is_empty
			has_camera: a_devices.has_camera
			raw_present: not a_raw_path.is_empty
			tee_present: not a_tee_path.is_empty
		do
			ffmpeg := a_ffmpeg.to_string_32
			devices := a_devices
			raw_path := a_raw_path.to_string_32
			tee_path := a_tee_path.to_string_32
		ensure
			recording: not is_audio_only
		end

	make_audio_only (a_ffmpeg: READABLE_STRING_32; a_devices: PT_DEVICE_CHOICE; a_tee_path: READABLE_STRING_32)
			-- Microphone only, tee file only (practice mode).
		require
			ffmpeg_present: not a_ffmpeg.is_empty
			tee_present: not a_tee_path.is_empty
		do
			ffmpeg := a_ffmpeg.to_string_32
			devices := a_devices
			create raw_path.make_empty
			tee_path := a_tee_path.to_string_32
			is_audio_only := True
		ensure
			audio_only: is_audio_only
		end

feature -- Constants

	Tee_rate: INTEGER = 16_000
	Gop_frames: INTEGER = 30
	Audio_buffer_ms: INTEGER = 50
	Cluster_ms: INTEGER = 500
			-- Longest Matroska cluster in the raw recording; bounds what a hard kill can lose.
			-- dshow audio device buffer; the device default can be large and adds directly
			-- to tee latency (review H6; measure in spike T-0).

feature -- Access

	ffmpeg: STRING_32
	devices: PT_DEVICE_CHOICE
	raw_path: STRING_32
	tee_path: STRING_32

	audio_stream: STRING_32
			-- The microphone's stream: in the one dshow input, or the second input for a camera
			-- recorded in its own mode.
		do
			if not is_audio_only and not devices.uses_mjpeg then
				Result := {STRING_32} "1:a"
			else
				Result := {STRING_32} "0:a"
			end
		end

	arguments: ARRAYED_LIST [STRING_32]
			-- Arguments after the ffmpeg executable.
		do
			create Result.make (48)
			add (Result, <<"-hide_banner", "-nostats", "-loglevel", "error", "-progress", "pipe:2", "-y">>)
			add (Result, <<"-f", "dshow", "-rtbufsize", "512M", "-audio_buffer_size">>)
			Result.extend (Audio_buffer_ms.out.to_string_32)
			if is_audio_only then
				Result.extend ({STRING_32} "-i")
				Result.extend ({STRING_32} "audio=" + devices.microphone)
			else
				if devices.uses_mjpeg then
					add (Result, <<"-vcodec", "mjpeg", "-video_size">>)
					Result.extend ((devices.width.out + "x" + devices.height.out).to_string_32)
					Result.extend ({STRING_32} "-framerate")
					Result.extend (devices.fps.out.to_string_32)
					Result.extend ({STRING_32} "-i")
					Result.extend ({STRING_32} "video=" + devices.camera + {STRING_32} ":audio=" + devices.microphone)
				else
						-- The device's own mode (OBS Virtual Camera, NVIDIA Broadcast), as its own input:
						-- a virtual camera stamps frames on its own clock (OBS: ~231,000 s against the
						-- microphone's 0), and in one input ffmpeg held every frame back waiting for the
						-- audio, so a hard stop wrote none (OBS test, 2026-10-07). Separate inputs each
						-- start at 0; the microphone keeps its own clock, which the tee's samples follow.
					Result.extend ({STRING_32} "-i")
					Result.extend ({STRING_32} "video=" + devices.camera)
					add (Result, <<"-f", "dshow", "-audio_buffer_size">>)
					Result.extend (Audio_buffer_ms.out.to_string_32)
					Result.extend ({STRING_32} "-i")
					Result.extend ({STRING_32} "audio=" + devices.microphone)
				end
				add (Result, <<"-map", "0:v", "-map">>)
				Result.extend (audio_stream)
				add (Result, <<"-c:v", "h264_nvenc", "-preset", "p5", "-cq", "18", "-g">>)
				Result.extend (Gop_frames.out.to_string_32)
				add (Result, <<"-c:a", "pcm_s16le">>)
					-- Clusters of at most 0.5 s, flushed as written: a hard kill loses at most the
					-- last cluster (spike S-R1, 2026-10-07: ~0.7 s lost without this).
				add (Result, <<"-cluster_time_limit">>)
				Result.extend (Cluster_ms.out.to_string_32)
				add (Result, <<"-flush_packets", "1">>)
				Result.extend (raw_path)
			end
			add (Result, <<"-map">>)
			Result.extend (audio_stream)
			add (Result, <<"-ar">>)
			Result.extend (Tee_rate.out.to_string_32)
			add (Result, <<"-ac", "1", "-f", "f32le", "-flush_packets", "1">>)
			Result.extend (tee_path)
		ensure
			dshow_input: has_pair (Result, "-f", "dshow")
			small_audio_buffer: has_pair (Result, "-audio_buffer_size", Audio_buffer_ms.out)
			mjpeg_when_offered: (not is_audio_only and devices.uses_mjpeg) implies has_pair (Result, "-vcodec", "mjpeg")
			device_mode_otherwise: (not is_audio_only and not devices.uses_mjpeg) implies not has_pair (Result, "-vcodec", "mjpeg")
			own_inputs_otherwise: (not is_audio_only and not devices.uses_mjpeg) implies (has_pair (Result, "-i", {STRING_32} "video=" + devices.camera)
				and has_pair (Result, "-i", {STRING_32} "audio=" + devices.microphone))
			pcm_when_recording: not is_audio_only implies has_pair (Result, "-c:a", "pcm_s16le")
			raw_when_recording: not is_audio_only implies across Result as ic some ic.same_string (raw_path) end
			small_clusters_when_recording: not is_audio_only implies has_pair (Result, "-cluster_time_limit", Cluster_ms.out)
			no_raw_in_practice: is_audio_only implies not has_pair (Result, "-c:v", "h264_nvenc")
			tee_format: has_pair (Result, "-f", "f32le") and has_pair (Result, "-ar", "16000") and has_pair (Result, "-ac", "1")
			tee_flushed: has_pair (Result, "-flush_packets", "1")
			tee_last: Result.last.same_string (tee_path)
		end

feature -- Status

	is_audio_only: BOOLEAN

	has_pair (a_args: LIST [STRING_32]; a_flag, a_value: READABLE_STRING_GENERAL): BOOLEAN
			-- Does `a_flag' appear immediately followed by `a_value'?
		local
			i: INTEGER
		do
			from i := 1 until Result or i >= a_args.count loop
				Result := a_args [i].same_string_general (a_flag) and a_args [i + 1].same_string_general (a_value)
				i := i + 1
			end
		end

feature {NONE} -- Implementation

	add (a_args: ARRAYED_LIST [STRING_32]; a_items: ARRAY [STRING_8])
		do
			across a_items as ic loop
				a_args.extend (ic.to_string_32)
			end
		ensure
			grown: a_args.count = old a_args.count + a_items.count
		end

invariant
	raw_iff_recording: is_audio_only = raw_path.is_empty
	tee_present: not tee_path.is_empty

end
