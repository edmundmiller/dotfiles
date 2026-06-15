# Pi goal patterns

Use this page to reduce manual re-prompts. Keep the Pi UI small: two reusable prompt templates handle most cases, and project-specific details live in the goal text or this runbook.

- **What Edmund can say better**: give the agent one outcome, one stopping condition, and the evidence it must surface.
- **What Pi setup should enforce**: a small set of reusable prompts plus global rules that keep agents iterating without waiting for `continue`.

## What Edmund can do better in prompts

### Prefer a durable outcome over a task bundle

Weak:

```text
Look into why Obsidian and manuscript agents are rough.
```

Better:

```text
Create or continue a durable goal to make Obsidian capture reliable. Work until the configured capture path is verified by logs and a smoke note, or until you can name the exact blocker and input needed.
```

### Name the verification surface up front

Include the commands, files, logs, rendered artifacts, or screenshots that decide completion.

```text
Before saying done, show the changed files, commands run, test/build output, logs inspected, and exact evidence that proves the workflow works.
```

### Replace “continue” with an audit instruction

When an agent stops too early, avoid a vague kick.

```text
Audit the active goal against fresh evidence. If anything remains unverified, take the next low-risk step now instead of summarizing next steps.
```

### Separate exploration from execution

If you want a plan first, explicitly authorize execution after the plan.

```text
First inspect the repo and draft the plan. Then execute the plan unless you hit a real access, tool, or decision blocker.
```

### For creative/research/manuscript work, require a ledger

```text
End with a section/claim ledger that lists source material inspected, edits made, generated artifacts, validation commands, unresolved uncertainty, and blockers.
```

## What Pi setup now provides

Prompt templates in `config/pi/prompts/` are linked into `~/.pi/agent/prompts/` by the Pi Nix module and become reusable prompt commands after `hey re`.

| Template                 | Use when                   | What it does                                                     |
| ------------------------ | -------------------------- | ---------------------------------------------------------------- |
| `goalize.md`             | Starting broad work        | Creates/replaces one durable goal and starts execution           |
| `goal-continue-audit.md` | An agent stopped too early | Audits active goal evidence and continues the next concrete step |

Global rule `config/agents/rules/16-autonomous-goal-progress.md` and skill `skills/catalog/autonomous-agent-loop/SKILL.md` reinforce the same loop for future agents.

## Copy-paste base contract

```text
Create or continue a durable goal for this task. Do not stop at a plan.
Work until the verifiable end state is true.
After each failed or partial attempt, inspect fresh evidence, update the plan, and take the next low-risk useful step.
Before saying done, map every requirement to files, diffs, commands, logs, tests, screenshots, or artifact paths.
If blocked, report attempted paths, exact blockers, remaining unmet requirements, and what input would unblock progress.
```

## Project-specific clauses to add to `goalize`

### Dotfiles

```text
Dotfiles constraints: preserve unrelated user changes; use br for issue tracking if needed; validate with ./bin/hey check; deploy runtime config with hey re, not darwin-rebuild or home-manager directly; make reviewable commits after validation; smoke-check installed agent config under the home directory when prompts/rules/skills change.
```

### Obsidian vault

```text
Obsidian constraints: first discover current vault conventions, commands, and log locations from files or recent evidence; do not rely on stale memory alone; inspect relevant logs before and after workflow changes; verify obsidian-cli or current vault tooling exists before relying on it; produce a smoke artifact such as a test note, query output, sync dry-run, or log excerpt.
```

### Nascent manuscripts

```text
Manuscript constraints: preserve authorial intent, existing structure, citations, and unrelated user changes; build a concise section/claim ledger; separate confirmed edits from approximate reconstructions, style-only edits, blocked claims, and uncertainty; discover and run the repository's build/render/lint/check commands; inspect generated artifacts when rendering is possible.
```
