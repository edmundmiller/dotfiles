---
name: ci-watch
description: Watch GitHub Actions runs when CI determines whether work is complete.
condition: "(?m)(?:^|[;&|]\\s*)(?:git\\s+push|jj\\s+git\\s+push|gh\\s+(?:pr\\s+checks|run\\s+watch))\\b"
scope: "tool:bash"
interruptMode: "never"
---

## GitHub Actions watch

After an authorized push, watch the current-HEAD GitHub Actions run when CI
determines completion. Use `/green` when the requested outcome includes fixing,
pushing, and re-watching until green. Pending CI is not completion.
