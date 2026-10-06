note
	description: "[
		VAD test double: speech probability is looked up by frame number
		(first sample // Frame_samples) from a script of probabilities; frames
		beyond the script read as silence. Keeps no state between frames.
	]"
	author: "Larry Rix"

class
	PT_SCRIPTED_VAD

inherit
	PT_VAD

create
	make

feature {NONE} -- Initialization

	make (a_probabilities: ARRAY [REAL_64])
			-- Frame n (0-based) has probability `a_probabilities' [lower + n].
		require
			all_in_range: across a_probabilities as ic all ic >= 0.0 and ic <= 1.0 end
		do
			probabilities := a_probabilities
		ensure
			set: probabilities = a_probabilities
		end

feature -- Access

	probabilities: ARRAY [REAL_64]

	reset_count: INTEGER
			-- Number of `reset' calls (test observation).

feature -- Detection

	analyze (a_samples: SPECIAL [REAL_32]; a_offset: INTEGER; a_first_sample: INTEGER_64)
			-- Scripted value for frame `a_first_sample' // Frame_samples.
		local
			l_frame: INTEGER_64
		do
			l_frame := a_first_sample // Frame_samples
			if l_frame < probabilities.count then
				last_probability := probabilities [probabilities.lower + l_frame.to_integer_32]
			else
				last_probability := 0.0
			end
		end

	reset
			-- Nothing is carried between frames; count the call.
		do
			last_probability := 0.0
			reset_count := reset_count + 1
		ensure then
			counted: reset_count = old reset_count + 1
		end

end
