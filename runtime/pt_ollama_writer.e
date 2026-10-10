note
	description: "[
		Asks the local AI (Ollama, on this machine's GPU) for the words that go with a published
		video (0.5.0): a title, a description, hashtags, a name for each chapter, a question for
		the Facebook post and a line for X, all from the script. One blocking HTTP call through
		simple_http; the Publish job makes it on the speech worker, never on the window.
		Thinking is switched off (a thinking model blew a 300 s call that took seconds with
		think false) and the context set to 8192 tokens (Ollama's default truncates silently).
		With no model named, it uses the first one installed that is not for OCR or embeddings.
	]"
	author: "Larry Rix"

class
	PT_OLLAMA_WRITER

create
	make

feature {NONE} -- Initialization

	make (a_url, a_model: READABLE_STRING_32)
			-- A writer asking the Ollama at `a_url' with `a_model' (empty: choose one).
		require
			url_present: not a_url.is_empty
		do
			url := a_url.to_string_32.twin
			from until url.is_empty or else url [url.count] /= '/' loop
				url.remove_tail (1)
			end
			model := a_model.to_string_32.twin
			create last_error.make_empty
			create last_model.make_empty
		end

feature -- Constants

	Timeout_s: INTEGER = 240
	List_timeout_s: INTEGER = 10

feature -- Access

	url, model: STRING_32
	last_error: STRING_32
			-- Why the last `suggest' got nothing, or empty.
	last_model: STRING_32
			-- The model the last `suggest' asked.

feature -- Basic operations

	suggest (a_script: PT_SCRIPT_TEXT; a_openings: LIST [STRING_32]): PT_PUBLISH_SUGGESTIONS
			-- The AI's suggestions for `a_script' with chapters opening with `a_openings' (empty
			-- suggestions, and `last_error' says why, when Ollama is not there or answers badly).
		local
			l_http: SIMPLE_HTTP
			l_json: SIMPLE_JSON
			l_body, l_options: SIMPLE_JSON_OBJECT
			l_messages: SIMPLE_JSON_ARRAY
			l_response: SIMPLE_HTTP_RESPONSE
			l_utf: UTF_CONVERTER
		do
			create Result.make_empty
			last_error := {STRING_32} ""
			last_model := chosen_model
			if last_model.is_empty then
				if last_error.is_empty then
					last_error := {STRING_32} "no model installed in Ollama at " + url
				end
			else
				create l_json
				l_options := l_json.new_object.put_integer (8192, "num_ctx").put_real (0.6, "temperature")
				l_messages := l_json.new_array
				l_messages := l_messages.add_object (l_json.new_object.put_string ("system", "role").put_string (system_prompt, "content"))
				l_messages := l_messages.add_object (l_json.new_object.put_string ("user", "role").put_string (user_prompt (a_script, a_openings), "content"))
				l_body := l_json.new_object.put_string (last_model, "model").put_boolean (False, "stream").put_boolean (False, "think")
					.put_string ("json", "format").put_object (l_options, "options").put_array (l_messages, "messages")
				create l_http.make
				l_http.set_timeout (Timeout_s)
				l_response := l_http.post_json (utf8 (url + {STRING_32} "/api/chat"), l_body)
				if l_response.is_success and then attached l_response.body as al_body then
					if attached l_json.parse (l_utf.utf_8_string_8_to_string_32 (al_body)) as al_value and then al_value.is_object
						and then attached al_value.as_object.object_item ("message") as al_message
						and then attached al_message.string_item ("content") as al_content then
						create Result.make_from_json (al_content)
						if not Result.has_any then
							last_error := {STRING_32} "the model's answer was not the JSON asked for"
						end
					else
						last_error := {STRING_32} "Ollama answered without a message"
					end
				else
					last_error := {STRING_32} "Ollama did not answer (HTTP " + l_response.status.out + {STRING_32} ")"
					if attached l_response.error_message as al_e then
						last_error.append ({STRING_32} ": " + l_utf.utf_8_string_8_to_string_32 (al_e))
					end
				end
			end
		ensure
			explained: not Result.has_any implies not last_error.is_empty
		end

	chosen_model: STRING_32
			-- `model', or the first installed model that is not for OCR or embeddings.
		local
			l_http: SIMPLE_HTTP
			l_response: SIMPLE_HTTP_RESPONSE
			l_utf: UTF_CONVERTER
			l_name: STRING_32
			i: INTEGER
		do
			if not model.is_empty then
				Result := model.twin
			else
				create Result.make_empty
				create l_http.make
				l_http.set_timeout (List_timeout_s)
				l_response := l_http.get (utf8 (url + {STRING_32} "/api/tags"))
				if l_response.is_success and then attached l_response.body as al_body
					and then attached (create {SIMPLE_JSON}).parse (l_utf.utf_8_string_8_to_string_32 (al_body)) as al_value
					and then al_value.is_object and then attached al_value.as_object.array_item ("models") as al_models then
					from i := 1 until i > al_models.count or not Result.is_empty loop
						if attached al_models.object_item (i) as al_m and then attached al_m.string_item ("name") as al_n then
							l_name := al_n.as_lower
							if not l_name.has_substring ({STRING_32} "ocr") and not l_name.has_substring ({STRING_32} "embed") then
								Result := al_n.twin
							end
						end
						i := i + 1
					end
				else
					last_error := {STRING_32} "Ollama is not running at " + url
				end
			end
		end

feature -- Prompts

	system_prompt: STRING_32
		do
			Result := {STRING_32} "You write the YouTube, Facebook and X copy for short Bible-teaching videos. %
				%Use the speaker's own words and ideas; never invent claims, quotes or verses. %
				%Plain, warm, direct American English. Answer with one JSON object and nothing else."
		end

	user_prompt (a_script: PT_SCRIPT_TEXT; a_openings: LIST [STRING_32]): STRING_32
			-- The request: the script, the chapter openings, and the JSON wanted.
		local
			i: INTEGER
		do
			create Result.make (4096)
			Result.append ({STRING_32} "SCRIPT TITLE: " + a_script.title + {STRING_32} "%N%NSCRIPT:%N")
			across a_script.paragraphs as ic loop
				Result.append (ic + {STRING_32} "%N%N")
			end
			Result.append ({STRING_32} "THE VIDEO'S CHAPTERS OPEN WITH THESE LINES, IN ORDER:%N")
			from i := 1 until i > a_openings.count loop
				Result.append (i.out.to_string_32 + {STRING_32} ". " + a_openings [i] + {STRING_32} "%N")
				i := i + 1
			end
			Result.append ({STRING_32} "%NAnswer with this JSON object:%N{%N")
			Result.append ({STRING_32} "  %"title%": a YouTube title under 90 characters that makes people want to watch, with the main Bible reference in parentheses when the script names one,%N")
			Result.append ({STRING_32} "  %"description%": two short paragraphs drawn from the script,%N")
			Result.append ({STRING_32} "  %"hashtags%": 6 to 8 hashtags, each starting with #, no spaces,%N")
			Result.append ({STRING_32} "  %"chapters%": exactly " + a_openings.count.out.to_string_32 + {STRING_32} " chapter names in the same order, each 2 to 7 words,%N")
			Result.append ({STRING_32} "  %"facebook_question%": one short question that invites viewers to comment,%N")
			Result.append ({STRING_32} "  %"x_line%": the script's sharpest line as one sentence under 200 characters, with the Bible reference in parentheses%N}%N")
		end

feature {NONE} -- Implementation

	utf8 (a_text: READABLE_STRING_32): STRING_8
		local
			l_utf: UTF_CONVERTER
		do
			Result := l_utf.string_32_to_utf_8_string_8 (a_text)
		end

end
