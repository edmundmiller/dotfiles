---
name: agent-friendly-cli
description: Run test/build tools in AI-agent-friendly modes by setting AGENT=1, CLAUDECODE=1, and related environment flags when available.
---

# Agent-Friendly CLI Output

Use this skill when running tests, builds, linters, or long-running project commands from an AI coding agent.

## Principle

Prefer tool output modes designed for non-human/agent consumers: concise progress, structured failures, stable text, and no interactive UI.

## Environment flags

When invoking tools, add these environment variables when appropriate:

```bash
AGENT=1
CLAUDECODE=1
```

Use `AGENT=1` as the generic signal. Use `CLAUDECODE=1` for tools that specifically key off Claude Code-compatible behavior.

## Bun test

Bun has explicit AI agent integration. Prefer:

```bash
AGENT=1 bun test
```

If running under Claude Code-compatible tooling or a wrapper that detects Claude Code, use:

```bash
CLAUDECODE=1 bun test
```

These modes make Bun's test output friendlier for agents: less noisy, easier to parse, and better suited to automated diagnosis.

## General command pattern

For one-off commands:

```bash
AGENT=1 <command>
```

For nested scripts:

```bash
AGENT=1 CLAUDECODE=1 npm test
AGENT=1 CLAUDECODE=1 bun test
AGENT=1 CLAUDECODE=1 hey re
```

## When not to use

Do not set these flags if the user is explicitly asking to inspect the exact human-facing output, colors, progress bars, or interactive UI behavior.

## Checklist

- [ ] Set `AGENT=1` for tests/builds where supported.
- [ ] Set `CLAUDECODE=1` when Claude Code-compatible output is useful.
- [ ] Prefer non-watch, non-interactive command variants.
- [ ] Prefer concise failure output over full verbose logs unless debugging requires logs.
