---
name: acpx-claude
description: Hand off a bounded implementation or review pass to Claude through ACPX.
---

# ACPX Claude Delegation

Use this skill when the user asks to run `acpx claude`, wants a Claude ACP agent, or when a task would benefit from a second-agent implementation/review pass through Claude Code.

## Quick commands

One-shot prompt without a saved session:

```bash
acpx claude exec "review the recent changes and identify risks"
```

Persistent session for the current repo:

```bash
acpx claude "investigate this bug and propose a fix"
acpx claude prompt "continue with the smallest safe patch"
acpx claude status
```

Named session:

```bash
acpx claude -s backend "debug the failing API tests"
acpx claude -s backend prompt "apply the fix and summarize the diff"
```

## Permissions and safety

- `acpx claude` is allowed by the local Pi permission policy for this dotfiles setup.
- Still preserve normal guarded workflows: do not ask Claude to bypass `hey`, signing hooks, rebuild/deploy rails, or destructive Nix cleanup.
- Prefer explicit, bounded prompts: include the repo path, desired outcome, files to inspect, and whether edits are allowed.
- For risky or broad tasks, ask Claude to produce a plan or review first; only request edits after the plan is acceptable.

## When to use `exec` vs persistent prompts

Use `exec` for independent checks, summaries, or reviews where no session continuity is needed.

Use the persistent `acpx claude` / `prompt` flow for multi-step implementation where Claude should keep context between turns.

## Suggested prompt shape

```text
We are in /Users/emiller/.config/dotfiles. Goal: <specific outcome>.
Constraints: preserve existing Nix/hey safety rails; do not run direct rebuild/deploy commands.
Please inspect <files/commands>, make the minimal patch if appropriate, then summarize changes and validation.
```
