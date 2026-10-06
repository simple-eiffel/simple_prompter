note
	description: "[
		The live samples: reads what ffmpeg appends to the tee file (16 kHz mono
		float32, little endian) as it arrives. The file is opened sharing read, write
		and delete, so ffmpeg keeps writing and the app can remove it afterwards. A read
		that ends inside a sample keeps the stray bytes for the next read.
	]"
	author: "Larry Rix"

class
	PT_TAIL_SOURCE

create
	make

feature {NONE} -- Initialization

	make (a_path: READABLE_STRING_32)
		require
			path_present: not a_path.is_empty
		do
			create path.make_from_string (a_path)
			create bytes.make (Max_samples * 4 + 4)
		ensure
			path_set: path.same_string (a_path)
			closed: not is_open
		end

feature -- Constants

	Max_samples: INTEGER = 8192
			-- Most samples one `read_into' delivers.

feature -- Access

	path: STRING_32
	samples_read: INTEGER_64
			-- Samples delivered since `open'.
	last_count: INTEGER
			-- Samples the last `read_into' delivered.

feature -- Status

	is_open: BOOLEAN
		do
			Result := handle /= default_pointer
		end

feature -- Commands

	open
			-- Start reading at the beginning of the file, if it exists yet.
		require
			closed: not is_open
		local
			l_name: NATIVE_STRING
		do
			create l_name.make (path)
			handle := c_open (l_name.item)
			samples_read := 0
			carry_count := 0
		end

	read_into (a_buffer: SPECIAL [REAL_32])
			-- Put the samples that arrived since the last read into `a_buffer' [0 .. `last_count' - 1].
		require
			open: is_open
			room: a_buffer.count >= 1
		local
			l_cap, l_got, l_total, i: INTEGER
		do
			l_cap := (a_buffer.count.min (Max_samples)) * 4 - carry_count
			l_got := c_read (handle, bytes.item + carry_count, l_cap)
			if l_got < 0 then
				l_got := 0
			end
			l_total := carry_count + l_got
			last_count := l_total // 4
			from i := 0 until i >= last_count loop
				a_buffer [i] := bytes.read_real_32_le (i * 4)
				i := i + 1
			end
				-- Keep a partial sample for the next read.
			carry_count := l_total \\ 4
			from i := 0 until i >= carry_count loop
				bytes.put_natural_8 (bytes.read_natural_8 (last_count * 4 + i), i)
				i := i + 1
			end
			samples_read := samples_read + last_count
		ensure
			counted: samples_read = old samples_read + last_count
			fits: last_count <= a_buffer.count
		end

	close
		do
			if is_open then
				c_close (handle)
				handle := default_pointer
			end
		ensure
			closed: not is_open
		end

feature {NONE} -- Implementation

	handle: POINTER
	bytes: MANAGED_POINTER
	carry_count: INTEGER

	c_open (a_path: POINTER): POINTER
		external
			"C inline use <windows.h>"
		alias
			"[
				HANDLE l_h = CreateFileW((LPCWSTR)$a_path, GENERIC_READ,
					FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, 0, OPEN_EXISTING,
					FILE_ATTRIBUTE_NORMAL, 0);
				return (l_h == INVALID_HANDLE_VALUE) ? (EIF_POINTER)0 : (EIF_POINTER)l_h;
			]"
		end

	c_read (a_handle, a_buffer: POINTER; a_cap: INTEGER): INTEGER
		external
			"C inline use <windows.h>"
		alias
			"[
				DWORD l_got = 0;
				if (!$a_handle || $a_cap <= 0) return 0;
				if (!ReadFile((HANDLE)$a_handle, $a_buffer, (DWORD)$a_cap, &l_got, 0)) return -1;
				return (EIF_INTEGER)l_got;
			]"
		end

	c_close (a_handle: POINTER)
		external
			"C inline use <windows.h>"
		alias
			"CloseHandle((HANDLE)$a_handle);"
		end

invariant
	carry_small: carry_count >= 0 and carry_count < 4

end
