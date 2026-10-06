note
	description: "[
		Measures text for layout in one font. The app supplies a Cairo-backed
		measure (SW_PAINTER.advance); tests use PT_FIXED_MEASURE. Keeps the
		library free of GUI dependencies.
	]"
	author: "Larry Rix"

deferred class
	PT_TEXT_MEASURE

feature -- Measurement

	advance (a_text: READABLE_STRING_32): REAL_64
			-- Horizontal advance of `a_text' in pixels.
		deferred
		ensure
			non_negative: Result >= 0
			empty_is_zero: a_text.is_empty implies Result = 0
		end

	space_advance: REAL_64
			-- Advance of one space.
		deferred
		ensure
			positive: Result > 0
		end

	line_height: REAL_64
			-- Distance between baselines.
		deferred
		ensure
			positive: Result > 0
		end

end
