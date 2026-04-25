---
purpose: Write spec and regression tests using a two-commit red/green bug-fix workflow.
---

# Testing Philosophy

Write two kinds of tests:

1. **Spec tests** — intended behavior
2. **Regression tests** — bugs that actually happened

Skip speculative edge-case farms that add noise without real signal.

## Behavior changes: Red/Green/Refactor

1. **Red:** write/adjust a test first and verify it fails for the expected reason
2. **Green:** make the smallest change that passes
3. **Refactor:** improve code/tests with the suite still green

## Bug fixes: two-commit regression flow

1. Add a regression test that asserts the correct behavior.
2. Keep CI green in the test commit using an expected-failure marker (or an explicit failure assertion if the framework has no marker).
3. Commit the test alone.
4. Implement the fix and remove/flip the marker.
5. Commit the fix.

## Guardrails

- Never commit a red suite.
- Prefer strict expected-failure behavior (unexpected pass should fail CI).
- Keep framework-specific marker syntax in the `tdd` skill, not this global rule.
