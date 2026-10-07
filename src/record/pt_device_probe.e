note
	description: "[
		Reads ffmpeg's list of a dshow camera's modes (`ffmpeg -f dshow -list_options true
		-i video="NAME"`, stderr) and decides how to record it: MJPEG at 1920x1080 when the
		camera offers it (a webcam), else the device's own mode (OBS Virtual Camera offers
		only raw NV12 / YUV at OBS's frame rate; NVIDIA Broadcast's camera only raw BGR).
		Found 2026-10-07 when Larry asked to record through OBS.
	]"
	author: "Larry Rix"

class
	PT_DEVICE_PROBE

feature -- Queries

	offers_mjpeg_at (a_listing: READABLE_STRING_GENERAL; a_width, a_height: INTEGER): BOOLEAN
			-- Does the mode listing `a_listing' offer MJPEG at `a_width' x `a_height'?
		require
			size_positive: a_width > 0 and a_height > 0
		local
			l_size: STRING_32
		do
			l_size := a_width.out.to_string_32 + {STRING_32} "x" + a_height.out.to_string_32
			across a_listing.to_string_32.split ('%N') as ic until Result loop
				Result := ic.has_substring ({STRING_32} "vcodec=mjpeg") and ic.has_substring ({STRING_32} "s=" + l_size)
			end
		end

	choice (a_listing: READABLE_STRING_GENERAL; a_camera, a_microphone: READABLE_STRING_32): PT_DEVICE_CHOICE
			-- How to record `a_camera' given its mode listing.
		require
			microphone_present: not a_microphone.is_empty
		do
			if offers_mjpeg_at (a_listing, 1920, 1080) then
				create Result.make (a_camera, a_microphone, 1920, 1080, 30)
			else
				create Result.make_device_mode (a_camera, a_microphone)
			end
		ensure
			mjpeg_iff_offered: Result.uses_mjpeg = offers_mjpeg_at (a_listing, 1920, 1080)
			devices_kept: Result.camera.same_string (a_camera) and Result.microphone.same_string (a_microphone)
		end

end
