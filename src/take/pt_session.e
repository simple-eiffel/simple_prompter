note
	description: "[
		One Take Studio sitting: folder, script history, journal, and (after
		analysis and editing) the analysis and the chosen cut list. The raw
		recording and the journal are never modified after Wrap (NFR-T05).
	]"
	author: "Larry Rix"

class
	PT_SESSION

create
	make

feature {NONE} -- Initialization

	make (a_folder: PT_SESSION_FOLDER; a_history: PT_SCRIPT_HISTORY; a_journal: PT_JOURNAL)
		require
			has_revision: a_history.revision_count >= 1
		do
			folder := a_folder
			history := a_history
			journal := a_journal
		ensure
			folder_set: folder = a_folder
			history_set: history = a_history
			journal_set: journal = a_journal
			not_analyzed: analysis = Void and cuts = Void
		end

feature -- Access

	folder: PT_SESSION_FOLDER
	history: PT_SCRIPT_HISTORY
	journal: PT_JOURNAL
	analysis: detachable PT_ANALYSIS
	cuts: detachable PT_CUT_LIST

feature -- Status

	is_analyzed: BOOLEAN
		do
			Result := attached analysis as al_a and then al_a.is_success
		end

feature -- Element change

	set_analysis (a_analysis: PT_ANALYSIS)
		do
			analysis := a_analysis
			if a_analysis.is_success then
				cuts := a_analysis.cuts
			end
		ensure
			set: analysis = a_analysis
			cuts_from_success: a_analysis.is_success implies cuts = a_analysis.cuts
		end

	set_cuts (a_cuts: PT_CUT_LIST)
			-- The Edit Floor's edited choice.
		do
			cuts := a_cuts
		ensure
			set: cuts = a_cuts
			analysis_kept: analysis = old analysis
		end

end
