note
	description: "[
		The capture devices Windows offers, read from ffmpeg's DirectShow listing
		(ffmpeg -hide_banner -list_devices true -f dshow -i dummy), whose lines name
		each device and its kind:
			[dshow @ 0000] "FHD Camera" (video)
			[dshow @ 0000] "Microphone (NVIDIA Broadcast)" (audio)
			[dshow @ 0000]   Alternative name "@device_pnp_..."
		Alternative-name lines carry no kind and are skipped. A device listed as
		both kinds is offered as both.
	]"
	author: "Larry Rix"

class
	PT_DEVICE_LIST

create
	make_empty, make_from_listing

feature {NONE} -- Initialization

	make_empty
			-- No devices.
		do
			create cameras.make (4)
			create microphones.make (4)
		ensure
			no_cameras: cameras.is_empty
			no_microphones: microphones.is_empty
		end

	make_from_listing (a_listing: READABLE_STRING_32)
			-- The devices `a_listing' names, in its order.
		do
			make_empty
			across a_listing.split ('%N') as ic loop
				read_line (ic)
			end
		end

feature -- Access

	cameras: ARRAYED_LIST [STRING_32]
			-- Video devices, each once.

	microphones: ARRAYED_LIST [STRING_32]
			-- Audio devices, each once.

feature -- Status

	has_camera (a_name: READABLE_STRING_32): BOOLEAN
		do
			Result := across cameras as ic some ic.same_string (a_name) end
		end

	has_microphone (a_name: READABLE_STRING_32): BOOLEAN
		do
			Result := across microphones as ic some ic.same_string (a_name) end
		end

feature {NONE} -- Reading

	read_line (a_line: READABLE_STRING_32)
			-- Take the device `a_line' names, if it names one with a kind.
		local
			l_open, l_close: INTEGER
			l_name, l_kind: STRING_32
		do
			if not a_line.is_empty then
				l_open := a_line.index_of ('"', 1)
				l_close := a_line.last_index_of ('"', a_line.count)
			end
			if l_open > 0 and l_close > l_open + 1 then
				l_name := a_line.substring (l_open + 1, l_close - 1)
				l_kind := a_line.substring (l_close + 1, a_line.count)
				l_kind.left_adjust
				l_kind.right_adjust
				if l_kind.starts_with ({STRING_32} "(") and l_kind.ends_with ({STRING_32} ")") then
					if l_kind.has_substring ({STRING_32} "video") and not has_camera (l_name) then
						cameras.extend (l_name)
					end
					if l_kind.has_substring ({STRING_32} "audio") and not has_microphone (l_name) then
						microphones.extend (l_name)
					end
				end
			end
		end

invariant
	no_empty_camera: across cameras as ic all not ic.is_empty end
	no_empty_microphone: across microphones as ic all not ic.is_empty end

end
