---
name: ci-watch
description: Watch GitHub Actions runs when CI determines whether work is complete.
alwaysApply: true
---

## GitHub Actions watch

- After pushing, or when a current-HEAD GitHub Actions run determines whether the task is complete, use `github run_watch` and wait for the run to finish.
- Use `/green` when CI should be watched, fixed, pushed, and re-watched autonomously until green.
- Do not stop after merely reporting that CI is pending.
