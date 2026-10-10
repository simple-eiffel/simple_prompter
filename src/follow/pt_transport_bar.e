note
	description: "[
		The pill's transport bar: a thin progress line across the full width with a
		row of video-player buttons under it, below the script text. Left to right:
		back a sentence, again, play / hold, forward a sentence | record / stop,
		star, reject | slower, faster. Pure layout and display state, no drawing:
		where each button sits for a pill width, which button a point hits, which
		word a click on the progress line points at. PT_PILL_RENDERER draws it from
		this state; PT_INPUT_ROUTER acts on its hits. Always showing (Larry,
		2026-10-09); a button or the progress line held under the pointer for
		`Tooltip_delay_ms' shows a tooltip naming what it does and its key.
	]"
	author: "Larry Rix"

class
	PT_TRANSPORT_BAR

create
	make

feature {NONE} -- Initialization

	make (a_scale: REAL_64)
			-- A bar for a display of `a_scale' physical pixels per design pixel.
		require
			scale_positive: a_scale > 0
		do
			scale := a_scale
			create lefts.make_filled (0.0, 1, Button_count)
			create enabled_flags.make_filled (False, 1, Button_count)
		ensure
			scale_set: scale = a_scale
			not_laid_out: not is_laid_out
			nothing_enabled: across 1 |..| Button_count as ic all not is_enabled (ic) end
		end

feature -- Buttons (left to right)

	Back_button: INTEGER = 1
	Again_button: INTEGER = 2
	Play_button: INTEGER = 3
	Forward_button: INTEGER = 4
	Record_button: INTEGER = 5
	Star_button: INTEGER = 6
	Reject_button: INTEGER = 7
	Slower_button: INTEGER = 8
	Faster_button: INTEGER = 9
	Button_count: INTEGER = 9

	Progress_hit: INTEGER = 100
			-- What `hit' answers on the progress line's band.

feature -- Constants (design pixels)

	Design_height: REAL_64 = 50.0
			-- Whole bar: progress band, button row, bottom margin.
	Design_progress_band: REAL_64 = 12.0
			-- Band at the top holding the progress line; a click in it jumps.
	Design_button: REAL_64 = 30.0
			-- Button width and height, before narrowing to fit.
	Design_gap: REAL_64 = 8.0
			-- Space between buttons of one group.
	Design_group_gap: REAL_64 = 28.0
			-- Space between the reading, take and speed groups.
	Design_inset: REAL_64 = 10.0
			-- Progress line inset from the pill's sides.

	Tolerance: REAL_64 = 0.001

	Tooltip_delay_ms: REAL_64 = 450.0
			-- How long the pointer rests on a target before its tooltip shows.

feature -- Access

	scale: REAL_64
			-- Physical pixels per design pixel.

	height: REAL_64
			-- Bar height in physical pixels.
		do
			Result := Design_height * scale
		ensure
			positive: Result > 0
		end

	left, right, top: REAL_64
			-- The bar's strip in pill pixels (from the last `lay_out').

	button_size: REAL_64
			-- Button side (narrowed when the pill is too narrow for the natural row).

	button_top: REAL_64
			-- Top of the button row.

	progress_y: REAL_64
			-- Centre of the progress line.

	progress_left: REAL_64
		do
			Result := left + Design_inset * scale
		end

	progress_right: REAL_64
		do
			Result := right - Design_inset * scale
		end

	button_left (a_button: INTEGER): REAL_64
			-- Left edge of `a_button'.
		require
			valid: valid_button (a_button)
			laid_out: is_laid_out
		do
			Result := lefts [a_button]
		end

	button_centre_x (a_button: INTEGER): REAL_64
		require
			valid: valid_button (a_button)
			laid_out: is_laid_out
		do
			Result := lefts [a_button] + button_size / 2
		end

	button_centre_y: REAL_64
		do
			Result := button_top + button_size / 2
		end

feature -- Display state

	is_pointer_in: BOOLEAN
			-- Is the pointer over the pill (no "mouse left" event arrives, so the app polls)?

	hovered: INTEGER
			-- Button under the pointer, `Progress_hit' on the progress line, or 0.

	hover_started_ms: REAL_64
			-- When the pointer arrived on `hovered'.

	is_tooltip_shown: BOOLEAN
			-- Is the tooltip for `hovered' showing?

	tooltip: STRING_32
			-- What `hovered' does, and its key.
		require
			hovering: hovered /= 0
		do
			inspect hovered
			when Back_button then
				Result := {STRING_32} "Back a sentence  (Ctrl+Alt+Left)"
			when Again_button then
				Result := {STRING_32} "Again: restart this sentence  (Ctrl+Alt+Backspace)"
			when Play_button then
				if not is_rolling then
					Result := {STRING_32} "Play  (Ctrl+Alt+P)"
				elseif is_playing then
					Result := {STRING_32} "Hold  (Ctrl+Alt+Space)"
				else
					Result := {STRING_32} "Go: read on from the caret  (Ctrl+Alt+Space)"
				end
			when Forward_button then
				Result := {STRING_32} "Forward a sentence  (Ctrl+Alt+Right)"
			when Record_button then
				if not is_rolling then
					Result := {STRING_32} "Record a take  (Ctrl+Alt+R)"
				elseif is_recording then
					Result := {STRING_32} "Wrap the take  (Ctrl+Alt+End)"
				else
					Result := {STRING_32} "Stop  (Ctrl+Alt+End)"
				end
			when Star_button then
				Result := {STRING_32} "Star: keep this take, while recording  (Ctrl+Alt+S)"
			when Reject_button then
				Result := {STRING_32} "Reject this take, while recording  (Ctrl+Alt+X)"
			when Slower_button then
				Result := {STRING_32} "Slower, at constant speed  (Ctrl+Alt+Down)"
			when Faster_button then
				Result := {STRING_32} "Faster, at constant speed  (Ctrl+Alt+Up)"
			when Progress_hit then
				Result := {STRING_32} "Jump here: hold with the caret on this word"
			end
		ensure
			says_something: not Result.is_empty
		end

	progress: REAL_64
			-- Fraction of the script read, 0 to 1.

	is_playing: BOOLEAN
			-- Reading or counting in: the play button shows "hold" (two bars).

	is_rolling: BOOLEAN
			-- Not idle: the record button shows "stop" (a square).

	is_recording: BOOLEAN
			-- A take is being recorded: the stop square is red.

	is_enabled (a_button: INTEGER): BOOLEAN
			-- Would `a_button' do something now?
		require
			valid: valid_button (a_button)
		do
			Result := enabled_flags [a_button]
		end

	signature: INTEGER
			-- Changes whenever anything the buttons draw changes (not `progress').
		local
			i: INTEGER
		do
			from i := 1 until i > Button_count loop
				if enabled_flags [i] then
					Result := Result + (1 |<< i)
				end
				i := i + 1
			end
			Result := Result + hovered * 1024
			if is_tooltip_shown then Result := Result + 262144 end
			if is_playing then Result := Result + 32768 end
			if is_rolling then Result := Result + 65536 end
			if is_recording then Result := Result + 131072 end
		end

feature -- Status

	valid_button (a_button: INTEGER): BOOLEAN
		do
			Result := a_button >= 1 and a_button <= Button_count
		end

	is_laid_out: BOOLEAN
			-- Has `lay_out' placed the bar?
		do
			Result := right > left
		end

	is_in_bar (a_y: REAL_64): BOOLEAN
			-- Is pill row `a_y' in the bar's strip (below the script text)?
		require
			laid_out: is_laid_out
		do
			Result := a_y >= top
		end

feature -- Layout

	lay_out (a_left, a_top, a_width: REAL_64)
			-- Place the bar in the strip `a_width' wide whose top-left is (`a_left', `a_top'),
			-- buttons centred, narrowed together when the row would not fit.
		require
			wide_enough: a_width > 2 * Design_inset * scale
		local
			l_natural, l_fit, l_x, l_gap, l_group: REAL_64
			i: INTEGER
		do
			left := a_left
			right := a_left + a_width
			top := a_top
			l_natural := natural_row_width * scale
			l_fit := ((a_width - 2 * Design_inset * scale) / l_natural).min (1.0)
			button_size := Design_button * scale * l_fit
			l_gap := Design_gap * scale * l_fit
			l_group := Design_group_gap * scale * l_fit
			progress_y := a_top + Design_progress_band * scale / 2
			button_top := a_top + Design_progress_band * scale
			l_x := a_left + (a_width - l_natural * l_fit) / 2
			from i := 1 until i > Button_count loop
				lefts [i] := l_x
				l_x := l_x + button_size
				if i = Forward_button or i = Reject_button then
					l_x := l_x + l_group
				else
					l_x := l_x + l_gap
				end
				i := i + 1
			end
		ensure
			laid_out: is_laid_out
			strip_set: left = a_left and top = a_top and (right - (a_left + a_width)).abs < Tolerance
			inside: across 1 |..| Button_count as ic all
					button_left (ic) >= left - Tolerance and button_left (ic) + button_size <= right + Tolerance end
			in_order: across 2 |..| Button_count as ic all button_left (ic) > button_left (ic - 1) + button_size - Tolerance end
			row_under_band: button_top > progress_y
			row_in_strip: button_top + button_size <= top + height + Tolerance
		end

	natural_row_width: REAL_64
			-- Row width in design pixels before narrowing.
		do
			Result := Button_count * Design_button + (Button_count - 3) * Design_gap + 2 * Design_group_gap
		end

feature -- Hit testing

	hit (a_x, a_y: REAL_64): INTEGER
			-- Button under (`a_x', `a_y'), `Progress_hit' in the progress band, or 0.
		require
			laid_out: is_laid_out
		local
			i: INTEGER
		do
			if a_x >= left and a_x <= right then
				if a_y >= top and a_y < button_top then
					Result := Progress_hit
				elseif a_y >= button_top and a_y <= button_top + button_size then
					from i := 1 until i > Button_count or Result /= 0 loop
						if a_x >= lefts [i] and a_x <= lefts [i] + button_size then
							Result := i
						end
						i := i + 1
					end
				end
			end
		ensure
			known: Result = 0 or Result = Progress_hit or valid_button (Result)
			above_bar_misses: a_y < top implies Result = 0
		end

	fraction_at (a_x: REAL_64): REAL_64
			-- Where along the progress line `a_x' is, 0 to 1.
		require
			laid_out: is_laid_out
		do
			Result := ((a_x - progress_left) / (progress_right - progress_left)).max (0.0).min (1.0)
		ensure
			in_range: Result >= 0 and Result <= 1
		end

	word_at_fraction (a_fraction: REAL_64; a_word_count: INTEGER): INTEGER
			-- The word a jump to `a_fraction' of the script lands on.
		require
			in_range: a_fraction >= 0 and a_fraction <= 1
			has_words: a_word_count >= 1
		do
			Result := (a_fraction * a_word_count).ceiling.max (1).min (a_word_count)
		ensure
			a_word: Result >= 1 and Result <= a_word_count
			start_is_first: a_fraction = 0 implies Result = 1
			end_is_last: a_fraction = 1 implies Result = a_word_count
		end

feature -- Display state setting

	set_pointer_in (a_on: BOOLEAN)
			-- The pointer is over the pill, or has left it (then nothing is hovered).
		do
			is_pointer_in := a_on
			if not a_on then
				hovered := 0
				is_tooltip_shown := False
			end
		ensure
			set: is_pointer_in = a_on
			left_forgets_hover: not a_on implies (hovered = 0 and not is_tooltip_shown)
		end

	set_hovered (a_target: INTEGER; a_now_ms: REAL_64)
			-- `a_target' is under the pointer at `a_now_ms' (0 = nothing). A new target
			-- restarts the tooltip delay.
		require
			valid: a_target = 0 or a_target = Progress_hit or valid_button (a_target)
		do
			if a_target /= hovered then
				hovered := a_target
				hover_started_ms := a_now_ms
				is_tooltip_shown := False
			end
		ensure
			set: hovered = a_target
			new_target_waits: a_target /= old hovered implies (not is_tooltip_shown and hover_started_ms = a_now_ms)
		end

	update_tooltip (a_now_ms: REAL_64)
			-- Show the tooltip once the pointer has rested on its target long enough.
		do
			is_tooltip_shown := hovered /= 0 and is_pointer_in and a_now_ms - hover_started_ms >= Tooltip_delay_ms
		ensure
			needs_a_target: is_tooltip_shown implies hovered /= 0
		end

	set_enabled (a_button: INTEGER; a_on: BOOLEAN)
		require
			valid: valid_button (a_button)
		do
			enabled_flags [a_button] := a_on
		ensure
			set: is_enabled (a_button) = a_on
		end

	set_transport (a_playing, a_rolling, a_recording: BOOLEAN)
			-- What the play and record buttons show.
		do
			is_playing := a_playing
			is_rolling := a_rolling
			is_recording := a_recording
		ensure
			playing_set: is_playing = a_playing
			rolling_set: is_rolling = a_rolling
			recording_set: is_recording = a_recording
		end

	set_progress (a_position: REAL_64; a_word_count: INTEGER)
			-- The reader is at word position `a_position' of `a_word_count'.
		do
			if a_word_count > 0 then
				progress := (a_position / a_word_count).max (0.0).min (1.0)
			else
				progress := 0.0
			end
		ensure
			in_range: progress >= 0 and progress <= 1
		end

feature {NONE} -- Implementation

	lefts: ARRAY [REAL_64]
			-- Left edge of each button.

	enabled_flags: ARRAY [BOOLEAN]

invariant
	scale_positive: scale > 0
	lefts_sized: lefts.count = Button_count and lefts.lower = 1
	flags_sized: enabled_flags.count = Button_count and enabled_flags.lower = 1
	hovered_known: hovered = 0 or hovered = Progress_hit or valid_button (hovered)
	tooltip_needs_target: is_tooltip_shown implies hovered /= 0
	progress_in_range: progress >= 0 and progress <= 1

end
