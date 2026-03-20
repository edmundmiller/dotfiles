---
name: tdd
description: Handles /tdd, Red/Green, behavior changes + two-commit regression tests.
---

# Red/Green TDD

1. **Red**: write intended-behavior spec test or failing test; verify failure for expected reason.
2. **Green**: make the smallest change that passes.
3. **Refactor**: clean up with the suite still green.

## Bug fixes

1. Regression test: reproduce bug, assert correct behavior.
2. Use strict xfail so XPASS fails, or assert failure explicitly; commit stays green; CI green every commit before the fix.
3. Commit so it runs; type-only changes okay; logic changes wait for fix commit.
4. Commit test alone; reviewers verify it fails.
5. Fix; keep regression test, remove xfail/flip to success, verify pass, commit fix.

## Guardrails

- No red suite/red test without expected-failure marker
- Show red→green progression; commits
- Deterministic; skip hypothetical edge cases.
