note
	description: "[
		Reads a Take Studio session back from its folder: session.toml (title and the id
		base), the script (script\r1.md, re-parsed with ids issued after the id base, so
		they are the ids the journal and the analysis refer to), the journal, and the
		analysis when there is one. Used by the analysis job and the Edit Floor, so a
		session needs nothing but its folder.
	]"
	author: "Larry Rix"

class
	PT_SESSION_LOADER

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_error.make_empty
			create title.make_empty
		ensure
			nothing_loaded: not is_loaded
		end

feature -- Access

	folder: detachable PT_SESSION_FOLDER
	history: detachable PT_SCRIPT_HISTORY
	journal: detachable PT_JOURNAL
	analysis: detachable PT_ANALYSIS
			-- Present when the session has a readable analysis\analysis.json.

	id_base: INTEGER_64
			-- The id just before the script's first word (0 when session.toml does not say).

	title: STRING_32
			-- The script's title (from session.toml).

	last_error: STRING_32
			-- Why the last `load' failed (empty when it did not).

	is_loaded: BOOLEAN
			-- Did the last `load' read the script and the journal?

	analysis_path (a_folder: PT_SESSION_FOLDER): STRING_32
			-- Where the analysis is kept.
		do
			Result := a_folder.analysis_dir + {STRING_32} "\analysis.json"
		end

feature -- Basic operations

	load (a_root: READABLE_STRING_32)
			-- Read the session in `a_root'.
		require
			root_present: not a_root.is_empty
			no_trailing_separator: a_root [a_root.count] /= '\' and a_root [a_root.count] /= '/'
		local
			l_folder: PT_SESSION_FOLDER
			l_parser: PT_SCRIPT_PARSER
			l_ids: PT_ID_SOURCE
			l_history: PT_SCRIPT_HISTORY
			l_journal: PT_JOURNAL
			l_codec: PT_ANALYSIS_CODEC
		do
			is_loaded := False
			history := Void
			journal := Void
			analysis := Void
			id_base := 0
			title := {STRING_32} "Session script"
			last_error := {STRING_32} ""
			create l_folder.make (a_root)
			folder := l_folder
			read_settings (l_folder)
			if not (create {SIMPLE_FILE}.make (l_folder.revision_path (1))).exists then
				last_error := {STRING_32} "the session's script is missing: " + l_folder.revision_path (1)
			elseif not (create {SIMPLE_FILE}.make (l_folder.journal_path)).exists then
				last_error := {STRING_32} "the session's journal is missing: " + l_folder.journal_path
			else
				create l_ids.make_after (id_base)
				create l_parser.make
				l_parser.parse (title, utf_8_text (l_folder.revision_path (1)), 1, l_ids)
				create l_history.make (l_ids, l_parser)
				l_history.start (l_parser.last_revision)
				history := l_history
				create l_journal.make_in_memory
				l_journal.replay_from (lines_of (l_folder.journal_path))
				journal := l_journal
				if (create {SIMPLE_FILE}.make (analysis_path (l_folder))).exists then
					create l_codec.make
					l_codec.decode (byte_text (analysis_path (l_folder)))
					if l_codec.last_analysis.is_success then
						analysis := l_codec.last_analysis
					end
				end
				is_loaded := True
			end
		ensure
			loaded_or_error: is_loaded xor not last_error.is_empty
			parts_when_loaded: is_loaded implies (attached history and attached journal and attached folder)
		end

feature {NONE} -- Implementation

	read_settings (a_folder: PT_SESSION_FOLDER)
			-- `id_base' and `title' from session.toml, when present and sensible.
		local
			l_text: STRING_32
		do
			if (create {SIMPLE_FILE}.make (a_folder.session_settings_path)).exists then
				l_text := utf_8_text (a_folder.session_settings_path)
				if not l_text.is_empty and then attached (create {SIMPLE_TOML}).parse (l_text) as al_root
					and then attached al_root.table_item ("session") as t then
					if t.has ("id_base") and then t.integer_item ("id_base") >= 0 then
						id_base := t.integer_item ("id_base")
					end
					if attached t.string_item ("title") as al_title and then not al_title.is_empty then
						title := al_title
					end
				end
			end
		end

	byte_text (a_path: READABLE_STRING_32): STRING_8
		do
			create Result.make (4096)
			across (create {SIMPLE_FILE}.make (a_path)).binary_content as ic loop
				Result.append_character (ic.to_character_8)
			end
		end

	utf_8_text (a_path: READABLE_STRING_32): STRING_32
		do
			Result := (create {SIMPLE_ENCODING}.make).utf_8_to_utf_32 (byte_text (a_path))
			if not Result.is_empty and then Result [1].natural_32_code = 0xFEFF then
				Result.remove_head (1)
			end
		end

	lines_of (a_path: READABLE_STRING_32): ARRAYED_LIST [STRING_8]
			-- Non-empty lines of `a_path' (bytes as written).
		local
			l_raw: STRING_8
		do
			l_raw := byte_text (a_path)
			l_raw.prune_all ('%R')
			create Result.make (64)
			across l_raw.split ('%N') as ic loop
				if not ic.is_empty then
					Result.extend (ic)
				end
			end
		end

end
