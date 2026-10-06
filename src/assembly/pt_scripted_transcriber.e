note
	description: "Transcriber test double: returns a fixture speech map and heard words for any path."
	author: "Larry Rix"

class
	PT_SCRIPTED_TRANSCRIBER

inherit
	PT_TRANSCRIBER

create
	make, make_failing

feature {NONE} -- Initialization

	make (a_map: PT_SPEECH_MAP; a_heard: PT_HEARD_WORDS)
			-- Succeed with `a_map' and `a_heard'.
		do
			fixture_map := a_map
			fixture_heard := a_heard
		ensure
			will_succeed: not fails
		end

	make_failing (a_reason: READABLE_STRING_32)
			-- Fail with `a_reason'.
		do
			fails := True
			reason := a_reason.to_string_32
			create fixture_map.make (0)
			create fixture_heard.make (0, 1, create {ARRAYED_LIST [PT_HEARD_WORD]}.make (0))
		ensure
			will_fail: fails
		end

feature -- Access

	fails: BOOLEAN
	reason: detachable STRING_32

feature -- Basic operations

	transcribe (a_audio_path: READABLE_STRING_32; a_duration: REAL_64)
			-- Hand back the fixture (map re-dimensioned to `a_duration').
		local
			l_map: PT_SPEECH_MAP
		do
			if fails then
				is_success := False
				if attached reason as al_reason then
					last_error := al_reason
				else
					last_error := {STRING_32} "scripted failure"
				end
			else
				create l_map.make (a_duration)
				across 1 |..| fixture_map.span_count as i loop
					if fixture_map.span (i).t1 <= a_duration and fixture_map.span (i).t0 >= l_map.last_end then
						l_map.extend_span (fixture_map.span (i))
					end
				end
				last_map := l_map
				last_heard := fixture_heard
				last_error := Void
				is_success := True
			end
		end

feature {NONE} -- Implementation

	fixture_map: PT_SPEECH_MAP
	fixture_heard: PT_HEARD_WORDS

end
