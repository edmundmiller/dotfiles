---
purpose: Define the single-outcome operating loop exposed by Pi goal prompts.
applies_to: Broad Pi work that must continue without routine user re-prompts.
entrypoint: Use goalize to start and goal-continue-audit to resume.
verification: Inspect deployed Pi prompts and map every requirement to fresh proof.
update_when: Shared completion rules, goal prompts, or landing behavior changes.
---

# Pi goal patterns

Use one durable goal for one active outcome. Pi continues until the outcome is proved and landed when authorized, or a genuine blocker requires one human action.

## Copy-paste contract

```text
Outcome: <the single requested end state>
Done when: <the observable stopping condition>
Proof: <commands, diffs, runtime checks, logs, screenshots, or artifacts>

Keep exactly one active outcome. Park unrelated discoveries and resume it.
Continue without waiting for a “kick” while another agent action can advance the outcome.
Return only:
- Landed: every requirement is verified, authorized landing is proved, and runtime evidence is named.
- Blocked: tools, access, or a required decision prevent progress; name exactly one smallest human action.
```

Planning, a clean feature worktree, and passing local checks are not terminal proof when implementation, runtime verification, or authorized landing remains.

## Operating loop

1. Create exactly one goal with `Outcome`, `Done when`, and `Proof`.
2. Derive repository facts; ask only for missing product intent or authority.
3. Execute the next low-risk step and inspect fresh evidence.
4. Resolve each requirement to `verified`, `unverified`, `parked`, or `blocked`.
5. Park tangents, then resume the active outcome without waiting for `continue`.
6. Return `Landed` only with verification, or `Blocked` with exactly one required action.

## Source of truth

Prompt templates in `config/pi/prompts/` are linked into `~/.pi/agent/prompts/` by the Pi Nix module:

| Template                 | Use                                               |
| ------------------------ | ------------------------------------------------- |
| `goalize.md`             | Create the one active goal and start execution.   |
| `goal-continue-audit.md` | Audit fresh evidence and continue unless blocked. |

Shared behavior lives in `config/agents/rules/16-autonomous-goal-progress.md`. The reusable procedure lives in `skills/catalog/autonomous-agent-loop/SKILL.md`. Do not create a parallel checklist or task store.

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
