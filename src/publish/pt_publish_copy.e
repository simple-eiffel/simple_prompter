note
	description: "[
		The words that go with a published video (0.5.0): youtube.txt (title, description,
		chapters, hashtags), facebook.txt (the Reel's description) and x.txt (one line to
		lead the post). Built from the script, with the local AI's suggestions used where it
		gave them (PT_PUBLISH_SUGGESTIONS); without them every part still comes from the
		script: the title from its # line, the description from its first paragraphs, the
		Facebook post from its opening and closing, the X line from its opening sentences.
	]"
	author: "Larry Rix"

class
	PT_PUBLISH_COPY

create
	make

feature {NONE} -- Initialization

	make (a_script: PT_SCRIPT_TEXT; a_chapters: PT_CHAPTER_PICKER; a_suggestions: PT_PUBLISH_SUGGESTIONS; a_link, a_hashtags: READABLE_STRING_32)
			-- Copy for `a_script' with `a_chapters'; `a_link' (may be empty) closes the Facebook post,
			-- `a_hashtags' (space-separated) when the AI gave none.
		do
			script := a_script
			chapters := a_chapters
			suggestions := a_suggestions
			link := a_link.to_string_32.twin
			default_hashtags := a_hashtags.to_string_32.twin
		end

feature -- Constants

	Max_description: INTEGER = 1200
	Max_x: INTEGER = 200
	Facebook_tags: INTEGER = 5

feature -- Access

	script: PT_SCRIPT_TEXT
	chapters: PT_CHAPTER_PICKER
	suggestions: PT_PUBLISH_SUGGESTIONS
	link: STRING_32
	default_hashtags: STRING_32

	title: STRING_32
			-- The AI's title, else the script's # line.
		do
			if not suggestions.title.is_empty then
				Result := suggestions.title.twin
			elseif not script.title.is_empty then
				Result := script.title.twin
			else
				Result := {STRING_32} "Untitled"
			end
		ensure
			present: not Result.is_empty
		end

	description: STRING_32
			-- The AI's description, else the script's first paragraphs (up to `Max_description').
		do
			if not suggestions.description.is_empty then
				Result := suggestions.description.twin
			else
				create Result.make (Max_description)
				across script.paragraphs as ic until Result.count + ic.count > Max_description and not Result.is_empty loop
					if not Result.is_empty then
						Result.append ({STRING_32} "%N%N")
					end
					Result.append (ic)
				end
			end
		end

	hashtags: STRING_32
			-- The AI's hashtags, else the default ones, space-separated.
		do
			if suggestions.hashtags.count >= 3 then
				Result := joined (suggestions.hashtags, suggestions.hashtags.count)
			else
				Result := default_hashtags.twin
			end
		end

	youtube_text: STRING_32
		do
			Result := {STRING_32} "TITLE%N" + title + {STRING_32} "%N%NDESCRIPTION%N" + description
				+ {STRING_32} "%N%NCHAPTERS%N" + chapters.text + {STRING_32} "%N" + hashtags + {STRING_32} "%N"
		end

	facebook_text: STRING_32
			-- Opening, closing, the AI's question, the link, five hashtags.
		local
			l_tags: ARRAYED_LIST [STRING_32]
		do
			Result := {STRING_32} "FB REEL DESCRIPTION%N"
			if not script.paragraphs.is_empty then
				Result.append (script.paragraphs.first)
				if script.paragraphs.count > 1 then
					Result.append ({STRING_32} "%N%N" + script.paragraphs.last)
				end
			end
			if not suggestions.facebook_question.is_empty then
				Result.append ({STRING_32} "%N%N" + suggestions.facebook_question)
			end
			if not link.is_empty then
				Result.append ({STRING_32} "%N%NMore at " + link)
			end
			create l_tags.make (8)
			across hashtags.split (' ') as ic loop
				if not ic.is_empty then
					l_tags.extend (ic)
				end
			end
			if not l_tags.is_empty then
				Result.append ({STRING_32} "%N%N" + joined (l_tags, Facebook_tags))
			end
			Result.append_character ('%N')
		end

	x_text: STRING_32
			-- The AI's line, else the script's opening sentences up to `Max_x' characters.
		do
			if not suggestions.x_line.is_empty then
				Result := suggestions.x_line.twin
			else
				create Result.make (Max_x)
				if not script.paragraphs.is_empty then
					across script.sentences_of (script.paragraphs.first) as ic until
						not Result.is_empty and Result.count + ic.count + 1 > Max_x
					loop
						if not Result.is_empty then
							Result.append_character (' ')
						end
						Result.append (ic)
					end
				end
			end
			Result.append_character ('%N')
		end

feature {NONE} -- Implementation

	joined (a_items: LIST [STRING_32]; a_max: INTEGER): STRING_32
			-- The first `a_max' of `a_items', space-separated.
		local
			i: INTEGER
		do
			create Result.make (80)
			from i := 1 until i > a_items.count or i > a_max loop
				if not Result.is_empty then
					Result.append_character (' ')
				end
				Result.append (a_items [i])
				i := i + 1
			end
		end

end
