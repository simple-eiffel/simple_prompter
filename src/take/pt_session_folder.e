note
	description: "[
		Paths of one Take Studio session folder (spec F-01 section 9.1). The only
		place file names are decided.
	]"
	author: "Larry Rix"

class
	PT_SESSION_FOLDER

create
	make

feature {NONE} -- Initialization

	make (a_root: READABLE_STRING_32)
			-- Session rooted at `a_root' (e.g. ...\Videos\simple_prompter\2026-10-05-episode-12.take).
		require
			root_present: not a_root.is_empty
			no_trailing_separator: a_root [a_root.count] /= '\' and a_root [a_root.count] /= '/'
		do
			root := a_root.to_string_32
		ensure
			root_set: root.same_string (a_root)
		end

feature -- Access

	root: STRING_32

	raw_path: STRING_32 do Result := under ("raw.mkv") end
	tee_path: STRING_32 do Result := under ("tee.f32") end
	journal_path: STRING_32 do Result := under ("journal.jsonl") end
	session_settings_path: STRING_32 do Result := under ("session.toml") end
	review_srt_path: STRING_32 do Result := under ("review.srt") end
	cut_path: STRING_32 do Result := under ("cut.json") end
	script_dir: STRING_32 do Result := under ("script") end
	analysis_dir: STRING_32 do Result := under ("analysis") end
	out_dir: STRING_32 do Result := under ("out") end

	revision_path (a_number: INTEGER): STRING_32
			-- File of script revision `a_number'.
		require
			positive: a_number >= 1
		do
			Result := script_dir + {STRING_32} "\r" + a_number.out + {STRING_32} ".md"
		ensure
			inside: Result.starts_with (script_dir)
		end

feature {NONE} -- Implementation

	under (a_name: READABLE_STRING_32): STRING_32
			-- `a_name' inside `root'.
		do
			Result := root + {STRING_32} "\" + a_name
		ensure
			inside: Result.starts_with (root)
			named: Result.ends_with (a_name)
		end

invariant
	root_present: not root.is_empty

end
