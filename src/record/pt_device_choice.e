note
	description: "Capture devices and video mode (default: FHD Camera + its microphone, MJPEG 1080p30; spec F-01 section 15)."
	author: "Larry Rix"

class
	PT_DEVICE_CHOICE

create
	make, make_default, make_device_mode

feature {NONE} -- Initialization

	make (a_camera, a_microphone: READABLE_STRING_32; a_width, a_height, a_fps: INTEGER)
		require
			microphone_present: not a_microphone.is_empty
			size_positive: a_width > 0 and a_height > 0
			fps_range: a_fps >= 1 and a_fps <= 120
		do
			camera := a_camera.to_string_32
			microphone := a_microphone.to_string_32
			width := a_width
			height := a_height
			fps := a_fps
			uses_mjpeg := True
		ensure
			devices_set: camera.same_string (a_camera) and microphone.same_string (a_microphone)
			mode_set: width = a_width and height = a_height and fps = a_fps
			mjpeg: uses_mjpeg
		end

	make_device_mode (a_camera, a_microphone: READABLE_STRING_32)
			-- Record `a_camera' in its own format and frame rate: a virtual camera (OBS Virtual
			-- Camera: raw 1080p at OBS's frame rate; NVIDIA Broadcast: raw BGR) offers no MJPEG, so
			-- nothing is forced (Larry approved the capture-plan contract change, 2026-10-07).
		require
			microphone_present: not a_microphone.is_empty
		do
			camera := a_camera.to_string_32
			microphone := a_microphone.to_string_32
			width := 1920
			height := 1080
			fps := 30
			uses_mjpeg := False
		ensure
			devices_set: camera.same_string (a_camera) and microphone.same_string (a_microphone)
			device_mode: not uses_mjpeg
		end

	make_default
			-- Decided defaults (Larry, 2026-10-05: "use defaults").
		do
			make ({STRING_32} "FHD Camera", {STRING_32} "Microphone (FHD Camera Microphone)", 1920, 1080, 30)
		end

feature -- Access

	camera: STRING_32
			-- dshow video device name (empty = audio only).
	microphone: STRING_32
			-- dshow audio device name.
	width, height, fps: INTEGER
			-- The mode requested when `uses_mjpeg' (otherwise the device's own mode is used).

	uses_mjpeg: BOOLEAN
			-- Is the camera asked for MJPEG at `width' x `height', `fps'? (A webcam offers it;
			-- virtual cameras do not - see PT_DEVICE_PROBE.)

feature -- Status

	has_camera: BOOLEAN
		do
			Result := not camera.is_empty
		end

invariant
	microphone_present: not microphone.is_empty
	size_positive: width > 0 and height > 0
	fps_range: fps >= 1 and fps <= 120

end
