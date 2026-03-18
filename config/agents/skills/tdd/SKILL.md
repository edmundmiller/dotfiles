---
name: tdd
description: Use when asked to use TDD, Red/Green/Refactor, or test-first development for behavior changes and bug fixes.
---

<!-- TDD skill: enforce Red/Green/Refactor loop with regression-test-first bug fixes. -->

# Red/Green TDD

Default loop for behavior changes:

1. **Red**: write focused test first; verify failure reason.
2. **Green**: smallest change to make test pass.
3. **Refactor**: improve design with suite still green.

## Bug-fix variant

1. Reproduce bug with regression test first.
2. Mark expected-failure (`test.failing`, `xfail(strict=True)`, `@PendingFeature`) when supported.
3. Commit test alone.
4. Implement fix; remove expected-failure marker.
5. Commit fix alone.

## Guardrails

- Never commit a red suite.
- One behavior per TDD cycle when possible.
- Keep tests deterministic and readable.
