note
	description: "[
		Forward-biased, bounded-window aligner (spec D-009). Scores the most
		recent heard words against the script window [position - Window_back,
		position + Normal_ahead] by LCS (which absorbs the recognizer revising
		itself across overlapping windows). Only anchored (non-stop) matches may
		move the position; big jumps need more anchors; moving backward needs
		strong evidence (DR-016, DR-017).
		The reader is always on the words the pill shows, or off script (Larry, 2026-10-11:
		"Period. Full stop."): when the prompter tells it the fully visible words, the
		search covers exactly them (and never less than `Window_back' words behind the
		position), so a phrase being read beats its echo further down the page. Only words
		heard since the last move can move the position again (a re-heard sentence once
		moved the text to its echo two lines down). 0.5.2 and 0.5.3 also bounded a move by
		the count of new words heard; the recognizer's buffer keeps about half the words
		said, so that bound stopped the text for whole takes (0.5.4 removes it). Words
		spoken before a reanchor (a restart, a nudge) are dropped by their own times, so
		the rest of that decode window counts at once. Since 0.5.5 each decode speaks for
		its whole window (`buffer_heard'), and "new" is judged by each word's time.
	]"
	author: "Larry Rix"

class
	PT_ALIGNER

create
	make

feature {NONE} -- Initialization

	make (a_revision: PT_SCRIPT_REVISION; a_matcher: PT_WORD_MATCHER)
			-- Aligner over `a_revision', positioned before the first word.
		do
			revision := a_revision
			matcher := a_matcher
			confidence := 1.0
			create last_alignment.make (0, 1.0, 0, 0, 0.0, 0)
			create recent_words.make (Recent_heard * 2)
			create recent_starts.make (Recent_heard * 2)
			consumed_t := -1.0
			create match_cache.make (256)
		ensure
			revision_set: revision = a_revision
			matcher_set: matcher = a_matcher
			at_start: position = 0
			certain: confidence = 1.0
		end

feature -- Constants

	Window_back: INTEGER = 3
	Context_back: INTEGER = 10
			-- Words behind the position searched when the visible words are not known, so that a
			-- phrase being read is matched whole and beats its echo further on (0.5.5).
	Normal_ahead: INTEGER = 40
			-- Forward search. (0.5.2: the wide search for a skipped paragraph is gone; the text
			-- never skips. Reel 2, 2026-10-11.)
	Recent_heard: INTEGER = 10
			-- Heard words aligned per update (6 was too few for function-word-heavy sentences:
			-- real-voice replay stuck at a closing paragraph; review of larry_read_01).
	Small_jump: INTEGER = 4
	Backward_evidence: INTEGER = 3

feature -- Access

	revision: PT_SCRIPT_REVISION
	matcher: PT_WORD_MATCHER

	position: INTEGER
			-- Words already read: the last word confirmed read (0 = none yet). The next word
			-- to read is position + 1 (one convention with PT_FOLLOWER.target, review H1).

	reanchored_at: INTEGER_64
			-- Sample-clock position of the last `reanchor'; decode windows starting before it
			-- are stale (review H3).

	confidence: REAL_64
			-- Confidence in `position', 0..1.

	heard_tail: ARRAYED_LIST [STRING_32]
			-- The heard words the next alignment starts from, oldest first (a fresh list).
		do
			Result := recent_tail
		ensure
			bounded: Result.count <= Recent_heard
		end

	last_alignment: PT_ALIGNMENT
			-- Estimate produced by the last `update' or `reanchor'.

	last_proposed: INTEGER
			-- Where the last `update''s best match ended (the move it proposed; `position' when
			-- there was no anchored match). For the follow trace.

	last_needed: INTEGER
			-- Anchors the last `update''s forward move needed (0 for a move of at most `Small_jump').

	visible_first: INTEGER
			-- First script word fully shown on the pill (0 = not known).

	visible_last: INTEGER
			-- Last script word fully shown on the pill (0 = not known: search `Normal_ahead' words on).

	last_fresh_anchors: INTEGER
			-- Anchored matches of the last `update''s best match among words heard since the
			-- last move (only these may move the position).

	last_new_words: INTEGER
			-- Words heard since the last move, as the last `update' weighed them.

	fresh_words: INTEGER
			-- Buffered words heard since the position last moved (or the newest words were
			-- explained there): starting more than `Restamp_slack' after `consumed_t'.
		do
			across recent_starts as ic loop
				if ic > consumed_t + Restamp_slack then
					Result := Result + 1
				end
			end
		ensure
			bounded: Result >= 0 and Result <= recent_words.count
		end

	spoken_distance (a_from, a_to: INTEGER): INTEGER
			-- Words in `a_from' + 1 .. `a_to' that can be spoken (cue text is never read aloud, so
			-- moving past a cue is not a jump; approved by Larry 2026-10-06).
		require
			ordered: a_from <= a_to
			inside: a_from >= 0 and a_to <= revision.word_count
		local
			i: INTEGER
		do
			from i := a_from + 1 until i > a_to loop
				if not revision.word (i).is_cue then
					Result := Result + 1
				end
				i := i + 1
			end
		ensure
			bounded: Result >= 0 and Result <= a_to - a_from
		end

	required_anchors (a_jump: INTEGER): INTEGER
			-- Anchored matches needed to move forward by `a_jump' words.
		require
			positive: a_jump > 0
		do
			if a_jump <= Small_jump then
				Result := 1
			elseif a_jump <= 3 * Small_jump then
				Result := 2
			else
				Result := 3
			end
		ensure
			tiers: Result >= 1 and Result <= 3
			small: a_jump <= Small_jump implies Result = 1
		end

feature -- Element change

	update (a_heard: PT_HEARD_WORDS)
			-- Incorporate a decode result.
		local
			l_heard: ARRAYED_LIST [STRING_32]
			l_k, l_lo, l_hi, l_new, l_anchors, l_matched, l_anchorable: INTEGER
			l_rate, l_dt: REAL_64
		do
			l_rate := last_alignment.rate_wps
			last_proposed := position
			last_needed := 0
			last_fresh_anchors := 0
			if a_heard.window_end > reanchored_at then
				buffer_heard (a_heard)
				last_new_words := fresh_words
				l_heard := recent_tail
				l_k := l_heard.count
				l_lo := (position - Context_back + 1).max (1)
				if visible_last > 0 then
					l_lo := (position - Window_back + 1).max (1).min (visible_first.max (1))
					l_hi := visible_last.max (position).min (revision.word_count)
				else
					l_hi := (position + Normal_ahead).min (revision.word_count)
				end
				if l_k > 0 and l_lo <= l_hi then
						-- Rows from `l_k - fresh_words + 1' on are new; the rest already moved the text
						-- (Reel 2, 2026-10-11: a re-heard "got it half right" moved on to the echo
						-- "got it exactly half right" 23 words later).
					best_alignment (l_heard, l_lo, l_hi, (l_k - fresh_words + 1).max (1))
					l_anchors := best_anchors
					l_matched := best_matched
					last_fresh_anchors := best_fresh
					if l_anchors > 0 then
						l_new := best_end
						last_proposed := l_new
						if best_fresh > 0 then
							if l_new < position then
								if l_anchors >= Backward_evidence then
									move_to (l_new)
								end
							elseif l_new > position then
								if spoken_distance (position, l_new) > Small_jump then
									last_needed := required_anchors (spoken_distance (position, l_new))
								end
								if l_anchors >= required_anchors (spoken_distance (position, l_new)) then
									move_to (l_new)
								end
							else
								consume
							end
						end
						across l_heard as ic loop
							if not matcher_stop (ic) then
								l_anchorable := l_anchorable + 1
							end
						end
						confidence := (l_anchors / l_anchorable.max (1)).min (1.0)
					else
						confidence := confidence * 0.8
					end
					if position > last_move_position then
						l_dt := (a_heard.window_end - last_move_sample) / 16_000
						if l_dt > 0.2 then
							if l_rate = 0 then
								l_rate := ((position - last_move_position) / l_dt).min (Max_rate)
							else
								l_rate := (0.7 * l_rate + 0.3 * ((position - last_move_position) / l_dt)).min (Max_rate)
							end
							last_move_position := position
							last_move_sample := a_heard.window_end
						end
					end
				end
			end
			create last_alignment.make (position, confidence, l_matched, l_anchors, l_rate, a_heard.window_end)
		ensure
			stale_ignored: a_heard.window_end <= reanchored_at implies (position = old position and confidence = old confidence)
			within_script: position >= 0 and position <= revision.word_count
			window_bound: visible_last = 0 implies position <= old position + Normal_ahead
			on_the_page: visible_last > 0 implies position <= visible_last.max (old position)
			forward_bias: position < old position implies last_alignment.anchor_count >= Backward_evidence
			stop_words_inert: last_alignment.anchor_count = 0 implies position = old position
			jump_evidence: position > old position and then spoken_distance (old position, position) > Small_jump implies
					last_alignment.anchor_count >= required_anchors (spoken_distance (old position, position))
			new_words_only: position /= old position implies last_fresh_anchors >= 1
			moved_consumes: position /= old position implies fresh_words = 0
			confidence_range: confidence >= 0.0 and confidence <= 1.0
			alignment_consistent: last_alignment.word_index = position
			proposed_in_script: last_proposed >= 0 and last_proposed <= revision.word_count
		end

	set_visible (a_first, a_last: INTEGER)
			-- The pill fully shows script words `a_first'..`a_last' (0, 0 = not known).
		require
			in_script: a_first >= 0 and a_last >= 0 and a_last <= revision.word_count
			ordered: a_last > 0 implies (a_first >= 1 and a_first <= a_last)
			both_or_neither: (a_first = 0) = (a_last = 0)
		do
			visible_first := a_first
			visible_last := a_last
		ensure
			set: visible_first = a_first and visible_last = a_last
		end

	reanchor (a_words_read: INTEGER; a_at_sample: INTEGER_64)
			-- Restart: `a_words_read' words count as read (caret k gives k - 1) as of sample `a_at_sample'.
		require
			valid: a_words_read >= 0 and a_words_read <= revision.word_count
			sample_non_negative: a_at_sample >= 0
		do
			position := a_words_read
			confidence := 1.0
			reanchored_at := a_at_sample
			recent_words.wipe_out
			recent_starts.wipe_out
			consumed_t := -1.0
			last_move_position := a_words_read
			last_move_sample := a_at_sample
			create last_alignment.make (a_words_read, 1.0, 0, 0, last_alignment.rate_wps, a_at_sample)
		ensure
			placed: position = a_words_read
			certain: confidence = 1.0
			stamped: reanchored_at = a_at_sample
			nothing_new: fresh_words = 0
			alignment_consistent: last_alignment.word_index = a_words_read
		end

feature {NONE} -- Alignment

	Max_rate: REAL_64 = 8.0
			-- Words per second; faster estimates are noise.

	last_move_position: INTEGER
	last_move_sample: INTEGER_64

			-- Position and sample of the last rate measurement.

	consumed_t: REAL_64
			-- Start time of the newest heard word when the position last moved (or the newest
			-- words were explained where it stands): words up to it are spent as evidence, and so
			-- are their re-transcriptions stamped up to `Restamp_slack' later (-1 = none).

	Restamp_slack: REAL_64 = 0.25
			-- How much later an overlapping decode may stamp a word it heard before.

	consume
			-- Every word heard so far is spent.
		do
			across recent_starts as ic loop
				consumed_t := consumed_t.max (ic)
			end
		ensure
			spent: fresh_words = 0
		end

	move_to (a_new: INTEGER)
			-- Move the position to `a_new'; every word heard so far is spent.
		require
			in_script: a_new >= 0 and a_new <= revision.word_count
		do
			position := a_new
			consume
		ensure
			moved: position = a_new
			spent: fresh_words = 0
		end

	best_end: INTEGER
	best_anchors: INTEGER
	best_matched: INTEGER
	best_explains_tail: BOOLEAN
	best_fresh: INTEGER
			-- Result of `best_alignment' (tail: the newest heard word was matched; fresh: anchors
			-- among new heard words).

	fresh_row: INTEGER
			-- First heard row of the current `best_alignment' that is new.

	fresh_anchor (a_row, a_index: INTEGER): INTEGER
			-- Anchor value of script word `a_index' matched by heard row `a_row', counted only for new rows.
		do
			if a_row >= fresh_row then
				Result := anchor_of (a_index)
			end
		end


	matcher_stop (a_normalized: READABLE_STRING_32): BOOLEAN
		do
			Result := stop_words.has (a_normalized)
		end

	stop_words: PT_STOP_WORDS
		once
			create Result
		end

	recent_words: ARRAYED_LIST [STRING_32]
			-- Spoken words heard since the last reanchor, oldest first.

	recent_starts: ARRAYED_LIST [REAL_64]
			-- Start time (seconds) of each of `recent_words'.

	buffer_heard (a_heard: PT_HEARD_WORDS)
			-- Take the spoken words of `a_heard'. The newest decode speaks for its whole window
			-- (0.5.5) when it heard at least as many words there: buffered words that start inside
			-- it give way to its words, and older words stay before them as context. A sparser
			-- decode only adds its words that start after the newest held word. Non-speech
			-- tags such as *cough* or [BLANK_AUDIO] are dropped, and so are words that start before
			-- `reanchored_at' (said before a restart or nudge). Merging overlapping windows word by
			-- word (0.5.4 and before) kept about half the words said and doubled others ("the the
			-- the"), so the text waited about 3 s for each catch-up (Reel 2, 09:47 take).
		local
			l_from, l_start, l_after: REAL_64
			l_words: ARRAYED_LIST [STRING_32]
			l_starts: ARRAYED_LIST [REAL_64]
			i, l_held: INTEGER
		do
			l_from := a_heard.window_start / 16_000
			create l_words.make (a_heard.count)
			create l_starts.make (a_heard.count)
			from i := 1 until i > a_heard.count loop
				l_start := l_from + a_heard.word (i).t0
				if not a_heard.word (i).normalized.is_empty and then not is_non_speech (a_heard.word (i).text)
					and then l_start >= reanchored_at / 16_000 then
					l_words.extend (a_heard.word (i).normalized)
					l_starts.extend (l_start)
				end
				i := i + 1
			end
			if not l_words.is_empty then
				l_held := 0
				across recent_starts as ic loop
					if ic >= l_from then
						l_held := l_held + 1
					end
				end
				if l_words.count >= l_held then
						-- At least as full a hearing of its span: it replaces what was held there.
					from until recent_starts.is_empty or else recent_starts.last < l_from loop
						recent_starts.finish
						recent_starts.remove
						recent_words.finish
						recent_words.remove
					end
					l_after := -1.0
				elseif not recent_starts.is_empty then
						-- A sparser hearing (the stabilizer passes only agreed words): keep what was
						-- held and add only its words that start later.
					l_after := recent_starts.last + Restamp_slack
				else
					l_after := -1.0
				end
				from i := 1 until i > l_words.count loop
					if l_starts [i] > l_after then
						recent_words.extend (l_words [i])
						recent_starts.extend (l_starts [i])
					end
					i := i + 1
				end
				from until recent_words.count <= Recent_heard * 2 loop
					recent_words.start
					recent_words.remove
					recent_starts.start
					recent_starts.remove
				end
			end
		ensure
			bounded: recent_words.count <= Recent_heard * 2
			parallel: recent_starts.count = recent_words.count
		end

	recent_tail: ARRAYED_LIST [STRING_32]
			-- The last `Recent_heard' buffered words, oldest first (a fresh list; the buffer is untouched).
		local
			i: INTEGER
		do
			create Result.make (Recent_heard)
			from i := (recent_words.count - Recent_heard + 1).max (1) until i > recent_words.count loop
				Result.extend (recent_words [i])
				i := i + 1
			end
		ensure
			sized: Result.count = recent_words.count.min (Recent_heard)
			newest_last: not Result.is_empty implies Result.last = recent_words.last
		end

	is_non_speech (a_text: READABLE_STRING_32): BOOLEAN
		do
			Result := not a_text.is_empty and then (a_text [1] = '*' or a_text [1] = '[' or a_text [1] = '(')
		end

	weight (a_index: INTEGER): INTEGER
			-- Score for matching script word `a_index': 2 for content words, 1 for stop words.
		do
			if revision.word (a_index).is_stop_word then
				Result := 1
			else
				Result := 2
			end
		end

	anchor_of (a_index: INTEGER): INTEGER
		do
			if not revision.word (a_index).is_stop_word then
				Result := 1
			end
		end

	best_alignment (a_heard: ARRAYED_LIST [STRING_32]; a_lo, a_hi, a_fresh_row: INTEGER)
			-- Local alignment of `a_heard' against script words `a_lo'..`a_hi' that ends with the
			-- newest heard word; sets best_end, best_anchors, best_matched, best_fresh (heard rows
			-- from `a_fresh_row' on are new). Steps: one heard word ~ one script word;
			-- two heard words ~ one script word ("for example" ~ "e.g."); one heard token ~ two or
			-- three script words ("cpp" ~ "c p p"); skips cost 1.
		require
			fresh_row_valid: a_fresh_row >= 1
		local
			l_k, l_m, i, j, s, l_cand, l_best, l_pass: INTEGER
			l_score, l_anch, l_match, l_fresh: ARRAY2 [INTEGER]
			l_last_match: ARRAY2 [BOOLEAN]
			l_pair, l_joined: STRING_32
		do
			l_k := a_heard.count
			create l_last_match.make_filled (False, l_k + 1, a_hi - a_lo + 2)
			l_m := a_hi - a_lo + 1
			create l_score.make_filled (0, l_k + 1, l_m + 1)
			create l_anch.make_filled (0, l_k + 1, l_m + 1)
			create l_match.make_filled (0, l_k + 1, l_m + 1)
			create l_fresh.make_filled (0, l_k + 1, l_m + 1)
			fresh_row := a_fresh_row
			from i := 1 until i > l_k loop
				from j := 1 until j > l_m loop
					s := a_lo + j - 1
						-- local start (score 0) is the default
					keep (l_score, l_anch, l_match, l_fresh, i, j, l_score [i, j + 1] - 1, l_anch [i, j + 1], l_match [i, j + 1],
						l_fresh [i, j + 1])
					keep (l_score, l_anch, l_match, l_fresh, i, j, l_score [i + 1, j] - 1, l_anch [i + 1, j], l_match [i + 1, j],
						l_fresh [i + 1, j])
					if cached_match (a_heard [i], s) then
						keep (l_score, l_anch, l_match, l_fresh, i, j, l_score [i, j] + weight (s), l_anch [i, j] + anchor_of (s), l_match [i, j] + 1,
							l_fresh [i, j] + fresh_anchor (i, s))
						if l_score [i + 1, j + 1] = l_score [i, j] + weight (s) then
							l_last_match [i + 1, j + 1] := True
						end
					end
					if i >= 2 and then could_be_spoken_span (a_heard [i - 1], a_heard [i], revision.word (s)) then
						l_pair := a_heard [i - 1] + {STRING_32} " " + a_heard [i]
						if matcher.matches (l_pair, revision.word (s)) then
							keep (l_score, l_anch, l_match, l_fresh, i, j, l_score [i - 1, j] + weight (s), l_anch [i - 1, j] + anchor_of (s), l_match [i - 1, j] + 1,
								l_fresh [i - 1, j] + fresh_anchor (i, s))
						end
					end
					if j >= 2 and then a_heard [i].count >= revision.word (s - 1).normalized.count + revision.word (s).normalized.count
						and then a_heard [i].starts_with (revision.word (s - 1).normalized) then
						l_joined := revision.word (s - 1).normalized + {STRING_32} " " + revision.word (s).normalized
						if matcher.equivalences.are_equivalent (a_heard [i], l_joined) then
							keep (l_score, l_anch, l_match, l_fresh, i, j, l_score [i, j - 1] + weight (s - 1) + weight (s),
								l_anch [i, j - 1] + anchor_of (s - 1) + anchor_of (s), l_match [i, j - 1] + 2,
								l_fresh [i, j - 1] + fresh_anchor (i, s - 1) + fresh_anchor (i, s))
						end
					end
					if j >= 3 and then a_heard [i].starts_with (revision.word (s - 2).normalized)
						and then a_heard [i].count >= revision.word (s - 2).normalized.count + revision.word (s - 1).normalized.count + revision.word (s).normalized.count then
						l_joined := revision.word (s - 2).normalized + {STRING_32} " " + revision.word (s - 1).normalized
							+ {STRING_32} " " + revision.word (s).normalized
						if matcher.equivalences.are_equivalent (a_heard [i], l_joined) then
							keep (l_score, l_anch, l_match, l_fresh, i, j, l_score [i, j - 2] + weight (s - 2) + weight (s - 1) + weight (s),
								l_anch [i, j - 2] + anchor_of (s - 2) + anchor_of (s - 1) + anchor_of (s), l_match [i, j - 2] + 3,
								l_fresh [i, j - 2] + fresh_anchor (i, s - 2) + fresh_anchor (i, s - 1) + fresh_anchor (i, s))
						end
					end
					j := j + 1
				end
				i := i + 1
			end
				-- Best cell in the last heard row (rows/columns are offset by one).
			best_end := 0
			best_anchors := 0
			best_matched := 0
			best_explains_tail := False
			best_fresh := 0
			l_best := 0
				-- A match that takes in new words beats one made of old words only (0.5.5): with the
				-- whole page searched, already-read words would otherwise end the best match behind
				-- the reader whenever the newest word was garbled.
			from l_pass := 1 until l_pass > 2 or best_end > 0 loop
				from j := 1 until j > l_m loop
					l_cand := l_score [l_k + 1, j + 1]
					if (l_pass = 2 or l_fresh [l_k + 1, j + 1] > 0) and then (l_cand > l_best
						or else (l_cand = l_best and l_cand > 0 and l_anch [l_k + 1, j + 1] > best_anchors)) then
						l_best := l_cand
						best_end := a_lo + j - 1
						best_anchors := l_anch [l_k + 1, j + 1]
						best_matched := l_match [l_k + 1, j + 1]
						best_explains_tail := l_last_match [l_k + 1, j + 1]
						best_fresh := l_fresh [l_k + 1, j + 1]
					end
					j := j + 1
				end
				l_pass := l_pass + 1
			end
		end

	match_cache: HASH_TABLE [SPECIAL [NATURAL_8], STRING_32]
			-- Memo of matcher results per heard word: 0 = not computed, 1 = no, 2 = yes, indexed by
			-- script word. Heard words recur across overlapping windows and the revision is fixed for
			-- this aligner, so almost every lookup after the first is a hit.

	Max_cached_words: INTEGER = 4_096
			-- Distinct heard words remembered.

	cached_match (a_heard: STRING_32; a_index: INTEGER): BOOLEAN
			-- Does heard `a_heard' match script word `a_index' (memoized `matcher.matches')?
		require
			valid_index: a_index >= 1 and a_index <= revision.word_count
		local
			l_row: SPECIAL [NATURAL_8]
		do
			if attached match_cache.item (a_heard) as al_row then
				l_row := al_row
			else
				create l_row.make_filled (0, revision.word_count + 1)
				if match_cache.count < Max_cached_words then
					match_cache.put (l_row, a_heard)
				end
			end
			if l_row [a_index] = 0 then
				if matcher.matches (a_heard, revision.word (a_index)) then
					l_row [a_index] := 2
				else
					l_row [a_index] := 1
				end
			end
			Result := l_row [a_index] = 2
		ensure
			same_as_matcher: Result = matcher.matches (a_heard, revision.word (a_index))
		end

	could_be_spoken_span (a_first, a_second: READABLE_STRING_32; a_word: PT_WORD): BOOLEAN
			-- Could heard words `a_first' `a_second' together stand for `a_word' (a spoken abbreviation
			-- like "for example" for "e.g.", or a split compound like "post condition")?
		do
			Result := not a_word.is_cue and then
				(not matcher.equivalences.spoken_forms (a_word.normalized).is_empty
				or else (a_word.normalized.starts_with (a_first) and a_word.normalized.ends_with (a_second)))
		end

	keep (a_score, a_anch, a_match, a_fresh: ARRAY2 [INTEGER]; a_i, a_j, a_cand, a_anchors, a_matched, a_fresh_anchors: INTEGER)
			-- Cell (a_i, a_j) (stored at [a_i + 1, a_j + 1]) keeps the better of its value and the candidate.
		do
			if a_cand > a_score [a_i + 1, a_j + 1] or else (a_cand = a_score [a_i + 1, a_j + 1] and a_cand > 0 and a_anchors > a_anch [a_i + 1, a_j + 1]) then
				a_score [a_i + 1, a_j + 1] := a_cand
				a_anch [a_i + 1, a_j + 1] := a_anchors.max (0)
				a_match [a_i + 1, a_j + 1] := a_matched.max (a_anchors.max (0))
				a_fresh [a_i + 1, a_j + 1] := a_fresh_anchors.max (0).min (a_anchors.max (0))
			end
		end

invariant
	position_range: position >= 0 and position <= revision.word_count
	confidence_range: confidence >= 0.0 and confidence <= 1.0
	reanchor_non_negative: reanchored_at >= 0
	constants_sane: Window_back >= 0 and Normal_ahead >= 1 and Backward_evidence >= 2
	buffer_parallel: recent_starts.count = recent_words.count

end
