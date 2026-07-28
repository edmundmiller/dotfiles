---
name: agent-ci
description: Run GitHub Actions CI locally with Agent CI only when explicitly requested.
license: MIT
compatibility: Requires Node.js 18+ and Docker
metadata:
  author: redwoodjs
  version: "1.0.0"
---

# Agent CI

Run the full CI pipeline locally only after an explicit user request. For ordinary testing, validation, or pre-push work, use the repository's focused checks instead.

## Run

```bash
npx @redwoodjs/agent-ci run --quiet --all --pause-on-failure
```

## Retry

When a step fails, the run pauses automatically. Fix the issue, then retry:

```bash
npx @redwoodjs/agent-ci retry --name <runner-name>
```

To re-run from an earlier step:

```bash
npx @redwoodjs/agent-ci retry --name <runner-name> --from-step <N>
```

Repeat until all jobs pass. Do not push to trigger remote CI when agent-ci can run it locally.
