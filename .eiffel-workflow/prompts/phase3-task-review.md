# Task Completeness Review (optional)

Review `.eiffel-workflow/tasks.md` against `src/**/*.e` for:
- Features marked "Phase 4" in src/ not covered by a task (cross-check: `grep -rn "Phase 4" src`)
- Missing dependencies between tasks
- Tasks too large (should be split) or too small (should be combined)
- Review findings (synopsis.md) not carried into a task: M9-M14, M23, L17-L21, L25

Output: a list of gaps or issues.
