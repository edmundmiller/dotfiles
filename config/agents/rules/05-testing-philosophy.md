# Testing Philosophy

Write two kinds of tests:

1. **Spec tests** - Document intended feature behavior (what the feature should do)
2. **Regression tests** - Reproduce and prevent actual bugs that occurred

**Skip:** Hypothetical edge cases and exhaustive coverage that bloat context windows.

Tests are living documentation of what should work and what broke before, not comprehensive safety nets for every possibility.
