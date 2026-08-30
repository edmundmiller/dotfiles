---
name: test-quality
compatibility: portable
description: Write, change, review, or remove automated tests with independent expectations and observable public behavior; reject tautological, vacuous, implementation-coupled, and mock-only coverage.
---

# Test quality

Use this skill whenever automated tests are written, changed, reviewed, or
removed. Read the nearest `CODING_STANDARDS.md` first when one exists; its
project-specific standards apply.

Keep the test's contract independent from the implementation:

- Derive expected values from the behavior contract, domain examples, or an
  independently chosen oracle—not from the helper, fixture, constant, or code
  path being tested.
- Prefer observable behavior at a public boundary (API, CLI, UI, persisted
  output, or other externally visible result). Test structure only when that
  structure is itself the contract.
- A mock may isolate an external dependency, but the assertion must still
  prove a meaningful result at the system boundary; a mock returning exactly
  what the test configured is not evidence.

Identify and correct weak coverage:

- **Tautological:** the assertion restates the implementation or only checks
  that configured input came back unchanged.
- **Vacuous:** the test has no meaningful assertion, observes no result, or
  would pass when the behavior is broken.
- **Implementation-coupled:** it locks private calls, incidental ordering, or
  internal representation instead of a documented contract.
- **Mock-only:** every relevant value comes from stubs or mocks, leaving no
  independently verifiable behavior.

Replace weak tests with meaningful behavioral coverage using independent
inputs and expected outcomes. If the code has no unique contract worth
protecting, remove the test rather than preserving a coverage count. Follow
the repository's existing test command and TDD workflow; this skill governs
test quality, not the full development process.
