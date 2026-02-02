# Testing Philosophy

Write two kinds of tests:

1. **Spec tests** - Document intended feature behavior (what the feature should do)
2. **Regression tests** - Reproduce and prevent actual bugs that occurred

**Skip:** Hypothetical edge cases and exhaustive coverage that bloat context windows.

Tests are living documentation of what should work and what broke before, not comprehensive safety nets for every possibility.

## Bug Fix Workflow

When a bug is reported, don't start by trying to fix it. Instead:

1. **Write a failing test** - Reproduce the bug in a test that fails
2. **Delegate the fix** - Have subagents attempt the fix
3. **Prove with passing test** - The fix is only valid when the test passes

This ensures every bug becomes a regression test and fixes are verifiable.
