# Testing Philosophy

Write two kinds of tests:

1. **Spec tests** — document intended feature behavior (what the feature should do)
2. **Regression tests** — reproduce and prevent actual bugs that occurred

**Skip:** hypothetical edge cases and exhaustive coverage that bloat context windows.

Tests are living documentation of what should work and what broke before, not comprehensive safety nets for every possibility.

## Bug Fix Workflow

When a bug is reported, don't start by trying to fix it. Instead:

1. **Write a failing test** — reproduce the bug with an expected-failure marker (see below) that asserts the _correct_ behavior
2. **Commit the test alone** — `test(scope): regression test for <bug>`
3. **Implement the fix** — remove the expected-failure marker, verify the test now passes
4. **Commit the fix** — `fix(scope): <what was fixed>`

This two-commit pattern ensures every bug becomes a regression test with verifiable git history. Reviewers can checkout the test commit and confirm it fails, then see the fix commit make it pass.

### Expected-failure syntax by framework

#### Bun / Vitest — `test.failing()`

Use `test.failing()` — **not** `it.fails` (doesn't exist). Inverts test result: failing test passes, passing test fails with a notice to remove `.failing()`.

```ts
// Test commit: .failing() because bug exists
test.failing("shift+tab toggles composer mode", () => {
  expect(handler({ key: "tab", shift: true })).toBe(true);
  expect(setMode).toHaveBeenCalled();
});

// Fix commit: remove .failing(), same assertions now pass
test("shift+tab toggles composer mode", () => {
  expect(handler({ key: "tab", shift: true })).toBe(true);
  expect(setMode).toHaveBeenCalled();
});
```

#### pytest — `@pytest.mark.xfail(strict=True)`

**Always use `strict=True`** — without it, an unexpected pass (XPASS) won't fail the suite, defeating the purpose.

```python
# Test commit: xfail because bug exists
@pytest.mark.xfail(strict=True, reason="shift+tab handler not wired up")
def test_shift_tab_toggles_mode():
    assert handler(key="tab", shift=True) is True

# Fix commit: remove xfail decorator
def test_shift_tab_toggles_mode():
    assert handler(key="tab", shift=True) is True
```

Set `xfail_strict = true` in `pytest.ini` / `pyproject.toml` to make strict the project-wide default.

#### Spock — `@PendingFeature`

Test runs; failures are reported as skipped. If the test _passes_, it's reported as a failure — alerting you to remove the annotation. Supports `reason` and `exceptions` params.

```groovy
// Test commit: @PendingFeature because bug exists
@PendingFeature(reason = "shift+tab handler not wired up")
def "shift+tab toggles composer mode"() {
    expect:
    handler.handle(key: 'tab', shift: true) == true
}

// Fix commit: remove @PendingFeature
def "shift+tab toggles composer mode"() {
    expect:
    handler.handle(key: 'tab', shift: true) == true
}
```

#### nf-test

No built-in xfail mechanism. Assert the failure explicitly in the test commit, flip to assert success in the fix commit. Add a `// BUG:` comment to flag intent.

```groovy
// Test commit: assert the process/workflow fails (BUG: missing index input)
then {
    assert process.failed        // BUG: should succeed once fixed
    assert process.exitStatus == 1
}

// Fix commit: flip to assert success
then {
    assert process.success
    assert process.exitStatus == 0
}
```

For workflow-level tests, use `workflow.failed`, `workflow.exitStatus`, and `workflow.errorReport.contains("...")` similarly.

### Practical notes

- **Test must compile.** Minimal type-only production changes (e.g. adding interface fields) go in the test commit so it runs. Handler/logic changes go in the fix commit.
- **Delegate fixes to subagents** when possible — they attempt the fix, the failing test validates it.
- **Never commit a red test without an expected-failure marker.** CI must stay green on every commit.
