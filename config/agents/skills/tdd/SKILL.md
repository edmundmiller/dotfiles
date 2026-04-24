---
name: tdd
description: Hybrid TDD workflow: behavior-first tests, vertical slices, deep-module thinking, and two-commit regression discipline.
---

# Hybrid TDD

## Core principles

- Test **behavior** through public interfaces, not internals.
- Work in **vertical slices**: one test → one implementation.
- Keep CI green on every commit.
- No speculative tests or speculative code.

## Workflow

### 1) Plan with the user

Before coding, confirm:

1. Interface changes needed
2. Behaviors to test first (prioritized)
3. Good seams/deep-module opportunities
4. The first tracer bullet

### 2) Tracer bullet loop (feature work)

For each behavior:

1. **RED**: write one failing behavior test
2. **GREEN**: make the smallest change to pass
3. **MICRO-REFACTOR** (optional): only while green
4. Commit with a clear message showing progression

Rules:

- One test at a time
- Minimal code for current test only
- Prefer integration-style behavior tests
- Avoid coupling tests to implementation details

### 3) Bug-fix protocol (two commits)

1. Add regression test that reproduces the bug and asserts intended behavior.
2. Keep branch green by using strict `xfail` (XPASS must fail) or equivalent explicit expected-failure mechanism.
3. Commit the regression test first (reviewers can verify the bug is captured).
4. Implement the fix, remove expected-failure marker, verify test passes.
5. Commit the fix separately.

### 4) Refactor phase

After target behaviors are green:

- Extract duplication
- Deepen shallow modules behind simpler interfaces
- Run tests after each refactor step
- Never refactor while red

## Guardrails checklist

- [ ] Test describes observable behavior
- [ ] Test uses public interface
- [ ] Test survives internal refactor
- [ ] Code is minimal for this step
- [ ] No red suite without explicit expected-failure marker
- [ ] Deterministic tests; avoid hypothetical edge-case sprawl
