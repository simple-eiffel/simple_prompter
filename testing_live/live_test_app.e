note
	description: "Live speech test runner (needs the CUDA whisper DLLs beside the exe)."
	author: "Larry Rix"

class
	LIVE_TEST_APP

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
		local
			t: TEST_LIVE_SPEECH
		do
			create t
			say ("simple_prompter live speech tests%N")
			run_test (agent t.test_live_path_follows_larry, "live_path_follows_larry")
			run_test (agent t.test_live_path_follows_a_sermon, "live_path_follows_a_sermon")
			run_test (agent t.test_long_script_loads_fast, "long_script_loads_fast")
			run_test (agent t.test_worker_listens_to_the_microphone, "worker_listens_to_the_microphone")
			run_test (agent t.test_worker_records_a_take, "worker_records_a_take")
			say ("%NResults: " + passed.out + " passed, " + failed.out + " failed%N")
		end

feature {NONE} -- Implementation

	passed, failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run `a_test' unless a command-line filter is given and `a_name' does not contain it.
		local
			l_retried: BOOLEAN
		do
			if not l_retried and then (argument_count = 0 or else a_name.has_substring (argument (1))) then
				a_test.call (Void)
				say ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			say ("  FAIL: " + a_name + failure_detail + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

	failure_detail: STRING
		local
			l_utf: UTF_CONVERTER
		do
			create Result.make_empty
			if attached (create {EXCEPTION_MANAGER_FACTORY}).exception_manager.last_exception as al_e then
				Result.append (" [" + al_e.generator)
				if attached al_e.description as al_d then
					Result.append (": " + l_utf.string_32_to_utf_8_string_8 (al_d))
				end
				Result.append ("]")
			end
		end

	say (a_text: STRING)
		do
			io.put_string (a_text)
			io.output.flush
		end

end
