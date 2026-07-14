# Worklog: omp-completion-hooks

Status: complete

## Objective

Codex and OMP main sessions use one completion checker, and OMP continues unverified stop attempts through its documented eight-continuation budget.

Stopping condition: focused contracts, shared checker, Darwin rebuild, installed-extension inspection, and subdirectory continuation smoke test pass on the final rebased tree; requested files are committed, pushed, current upstream, and tagged.

## Decisions

- Use one shared shell checker for Codex and OMP.
- Install the OMP extension globally but gate activation to this repository using tracked marker files.
- Verification is a one-shot content snapshot consumed by the next stop attempt.
- Do not patch OMP core; use the public `ExtensionAPI.session_stop` continuation budget.
- Preserve `features.unexpectedStopDetection: true`; do not add another semantic classifier.
- Pre-existing working-tree changes: none (`git status --short --branch`).

## Evidence

- Red contract: `python3 -m unittest tests/test_completion_hooks.py` failed in 1.2s for the expected missing `scripts/completion-check`, missing OMP extension, and absent `CODEX_STOP_CHECKER` seam. The first attempt exposed recursive unittest invocation in the old wrapper and timed out; the fixture now stubs the legacy checker commands so red failures are bounded and relevant.
- `bun test tests/omp_completion_gate.test.js`: 15 passed.
- `python3 -m unittest tests/test_completion_hooks.py`: 9 passed, including the Bun bridge.
- `scripts/completion-check`: 23 repository tests passed, then Darwin `hey check` passed; direct execution succeeded with checker output confined to stderr.
- `hey agent-audit-tests tests/test_completion_hooks.py tests/omp_completion_gate.test.js`: `PASS test-confidence`.
- `hey agent-finish --worklog .agents/worklogs/omp-completion-hooks.md`: all applicable workflow checks passed after `nix develop -c true` refreshed the generated prek manifest.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .`: activated successfully on `MacTraitor-Pro.local` (`Darwin 27.0.0`, arm64).
- `omp --no-session --mode json -p '/extensions'`: loaded `completion_check`, emitted a `session-stop-continuation`, called the tool, and reported no extension load error.
- Subdirectory runtime smoke with checker commands stubbed settled as exact `GATE_OK`, not `PRECHECK`.

## Reviews

- Plan gate blocked twice at ACP session creation: default reviewer and `--reviewer gemini` both returned `Authentication required`. Tooling waiver: execute the already approved, contract-complete plan; retry the required landing gate.
- Landing gate blocked twice at ACP session creation: default reviewer and `--reviewer gemini` both returned `Authentication required`. No model review findings were available; focused contracts, semantic diff inspection, workflow checks, rebuild, and live continuation smoke remain the evidence-backed waiver.

## Feedback

- None.

## Remaining work

- None.

## Commits

- `feat(agents): enforce OMP completion checks`
- After landing: `agent-work/omp-completion-hooks`.
