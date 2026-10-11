note
	description: "[
		Measure on its own processor (0.6.0; Larry: "These buttons need to launch SCOOP'd
		processes"): the window creates a worker with the take's files and a fresh slot,
		calls `run' and goes on; the worker runs PT_SYNC_MEASURER (seconds of ffmpeg and
		clap searching) and puts its progress and result into the slot, holding the slot
		only for each short report.
	]"
	author: "Larry Rix"

class
	PT_MEASURE_WORKER

create
	make

feature {NONE} -- Initialization

	make (a_ffmpeg, a_raw, a_tee, a_work_dir: separate READABLE_STRING_32; a_slot: separate PT_MEASURE_SLOT)
			-- A worker for the take recorded in `a_raw' (microphone copy `a_tee'), reporting to `a_slot'.
		do
			create ffmpeg.make_from_separate (a_ffmpeg)
			create raw.make_from_separate (a_raw)
			create tee.make_from_separate (a_tee)
			create work_dir.make_from_separate (a_work_dir)
			slot := a_slot
		end

feature -- Access

	ffmpeg, raw, tee, work_dir: STRING_32
	slot: separate PT_MEASURE_SLOT

feature -- Execution

	run
			-- Measure, then report.
		local
			l_measurer: PT_SYNC_MEASURER
			l_first: REAL_64
		do
			if ffmpeg.is_empty or raw.is_empty or tee.is_empty then
				report_result (slot, False, 0, -1, {STRING_32} "this take's recording files are missing")
			else
				create l_measurer.make (ffmpeg)
				l_measurer.set_on_progress (agent tell)
				l_measurer.run (raw, tee, work_dir)
				l_first := -1
				if not l_measurer.measure.claps.is_empty then
					l_first := l_measurer.measure.claps.first
				end
				report_result (slot, l_measurer.measure.is_found, l_measurer.measure.delay_ms, l_first, l_measurer.summary)
			end
		end

feature {NONE} -- Reporting

	tell (a_fraction: REAL_64)
		do
			report_progress (slot, a_fraction)
		end

	report_progress (a_slot: separate PT_MEASURE_SLOT; a_fraction: REAL_64)
		do
			a_slot.put_progress (a_fraction)
		end

	report_result (a_slot: separate PT_MEASURE_SLOT; a_found: BOOLEAN; a_delay_ms: INTEGER; a_first: REAL_64; a_summary: STRING_32)
		do
			a_slot.put_result (a_found, a_delay_ms, a_first, a_summary)
		end

end
