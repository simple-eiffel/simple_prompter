# Queued skill improvements (Skill Version Lock: not applied mid-workflow)

## eiffel-contracts (found 2026-10-05, simple_prompter Phase 1)
1. **Compile commands are obsolete.** The skill says `ec.sh -batch -config ... -c_compile`; the wrapper rejects raw
   flags. Use `ec.sh check -config X.ecf -target X_tests`, then `ec.sh test ...` (CLAUDE.md, memory ec-sh-blocks-raw-flags).
2. **Test folder and base class.** The skill writes `test/` with `EQA_TEST_SET`; the ecosystem standard is `testing/`
   with `TEST_SET_BASE` (simple_testing) plus `test_app.e` / `lib_tests.e` (oracle Testing Standard).
3. **Per-target assertions.** The ECF template must repeat `<option><assertions .../>` in every extending target
   (oracle gotcha: extending targets don't inherit them).
4. **Don't trust the last line of `ec.sh check`.** It printed "Syntax and type check passed" after VUOT errors; grep for
   `Error code` and require `System Recompiled.`.
5. **Compile the test target before declaring the library clean.** VAPE (precondition export) errors only appeared when
   a client called the feature.
6. **SCOOP consumer test:** creating a separate object while passing local reference arguments is a traitor error; the
   template should use expanded arguments only (or a factory on the target processor).
7. **MML models are not ITERABLE**: templates using `across model as ic` don't compile; use index loops.

## /eiffel.verify (queued 2026-10-05, Phase 5 of simple_prompter)
- Step 4 still shows `ec.sh -batch ... -c_compile` and a W_code exe; the wrapper rejects raw
  flags and only builds F_code. Use `ec.sh test` and EIFGENs/<target>/F_code/<exe>.
- Step 4 should also run the lean binary from `ec.sh release`: it is the shipping build. Tests
  that check contract refusals need a helper that skips them when contracts are off
  (simple_prompter PT_TEST_SET.assert_refused), or every behavior assertion after the first
  refusal check goes unverified in the lean run.
- Add a step: replay real recorded data through the whole pipeline, not just units. In
  simple_prompter, 12 analyzer defects passed every synthetic test and were found only by
  replaying larry_read_01.
- Coverage measure that worked: exported features named by a test (coverage.py in the session
  scratchpad) - fast, honest, and it points straight at the untested features.
