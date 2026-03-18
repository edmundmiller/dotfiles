<!-- Testing workflow rule: default to red/green/refactor TDD for behavior changes. -->

# Red/Green TDD

- Default to Red/Green/Refactor for behavior changes.
- **Red:** write the test first; verify it fails for the expected reason.
- **Green:** implement the smallest change that makes the test pass.
- **Refactor:** improve code/tests with the suite still green.
- Never commit a red suite; for bug-capture commits, use expected-failure markers from Testing Philosophy.
