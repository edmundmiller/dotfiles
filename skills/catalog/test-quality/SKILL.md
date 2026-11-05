---
name: test-quality
compatibility: portable
description: Use when adding or editing test files, stubs, fakes or test doubles, writing failure-path, concurrency or subprocess tests, or before calling a suite green. Write, change, review, or remove automated tests with independent expectations and observable public behavior; reject tautological, vacuous, implementation-coupled, and mock-only coverage.
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

Choose checks that can expose plausible mistakes:

- Name a plausible wrong implementation and choose an input that distinguishes
  it from the required behavior. For a bug fix, show the regression test fails
  on the original code and passes with the fix when practical.
- When a trusted reference implementation exists, consider differential testing
  on the same inputs, especially both sides of behavioral boundaries. Resolve
  disagreements against the contract; the reference can also be wrong.
- For property-based or fuzz tests, generate valid domain inputs or event
  sequences alongside invalid cases. Check meaningful invariants and confirm
  the generator reaches the risky behavior, rather than mostly exercising input
  rejection. Preserve minimized failures as regression cases.

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
protecting, remove the test rather than preserving a coverage count.

Prefer existing libraries and small generators over custom testing frameworks.
Separate disposable investigation from permanent regression coverage; keep
tests that protect a meaningful contract, not every experiment used during
development.

Follow the repository's existing test command and any explicitly required
development workflow; this skill governs test quality, not the full development
process.
