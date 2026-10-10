note
	description: "[
		What the local AI suggests for a published video (0.5.0): a title, a description,
		hashtags, a name for each chapter, a question for the Facebook post, and a line for X.
		Read from the JSON object the model answers with; anything missing, empty or too long
		is left empty, and PT_PUBLISH_COPY then writes that part from the script instead.
	]"
	author: "Larry Rix"

class
	PT_PUBLISH_SUGGESTIONS

create
	make_empty,
	make_from_json

feature {NONE} -- Initialization

	make_empty
		do
			create title.make_empty
			create description.make_empty
			create hashtags.make (8)
			create chapter_labels.make (8)
			create facebook_question.make_empty
			create x_line.make_empty
		ensure
			nothing: not has_any
		end

	make_from_json (a_json: READABLE_STRING_32)
			-- The suggestions in `a_json' (an object: title, description, hashtags, chapters,
			-- facebook_question, x_line).
		do
			make_empty
			if attached (create {SIMPLE_JSON}).parse (a_json) as al_value and then al_value.is_object then
				read (al_value.as_object)
			end
		end

feature -- Constants

	Max_title: INTEGER = 100
	Max_description: INTEGER = 2000
	Max_label: INTEGER = 60
	Max_x: INTEGER = 250
	Max_question: INTEGER = 160

feature -- Access

	title: STRING_32
	description: STRING_32
	hashtags: ARRAYED_LIST [STRING_32]
			-- Each with its #, no spaces.
	chapter_labels: ARRAYED_LIST [STRING_32]
	facebook_question: STRING_32
	x_line: STRING_32

	has_any: BOOLEAN
			-- Did anything usable come back?
		do
			Result := not title.is_empty or not description.is_empty or not hashtags.is_empty
				or not chapter_labels.is_empty or not facebook_question.is_empty or not x_line.is_empty
		end

feature {NONE} -- Implementation

	read (o: SIMPLE_JSON_OBJECT)
		local
			l_tag: STRING_32
			i: INTEGER
		do
			title := text_item (o, "title", Max_title)
			description := text_item (o, "description", Max_description)
			facebook_question := text_item (o, "facebook_question", Max_question)
			x_line := text_item (o, "x_line", Max_x)
			if attached o.array_item ("hashtags") as al_a then
				from i := 1 until i > al_a.count or hashtags.count >= 10 loop
					if attached al_a.string_item (i) as al_s then
						l_tag := al_s.to_string_32.twin
						l_tag.prune_all (' ')
						l_tag.prune_all ('#')
						if not l_tag.is_empty and l_tag.count <= 40 then
							hashtags.extend ({STRING_32} "#" + l_tag)
						end
					end
					i := i + 1
				end
			end
			if attached o.array_item ("chapters") as al_a then
				from i := 1 until i > al_a.count loop
					if attached al_a.string_item (i) as al_s then
						chapter_labels.extend (clean (al_s, Max_label))
					end
					i := i + 1
				end
			end
		end

	text_item (o: SIMPLE_JSON_OBJECT; a_key: STRING_32; a_max: INTEGER): STRING_32
			-- `o's string `a_key', trimmed, or empty when missing or longer than `a_max'.
		do
			create Result.make_empty
			if attached o.string_item (a_key) as al_s then
				Result := clean (al_s, a_max)
			end
		end

	clean (a_text: READABLE_STRING_GENERAL; a_max: INTEGER): STRING_32
			-- `a_text' trimmed; empty when longer than `a_max'.
		do
			Result := a_text.to_string_32.twin
			Result.left_adjust
			Result.right_adjust
			if Result.count > a_max then
				create Result.make_empty
			end
		ensure
			fits: Result.count <= a_max
		end

end
