---
purpose: Preserve retired workflow designs and legacy recovery contracts.
applies_to: Historical investigation, not current agent or host operation.
entrypoint: Use AGENT_WORKFLOW.md or the current owning module before these records.
verification: Check current implementation and its scoped tests before reusing commands.
update_when: Another workflow record is retired or its current owner moves.
---

# Retired workflow records

These documents preserve old design decisions and recovery contracts. Their
commands and target-state claims are historical, not current instructions.

- `ade/` and `tmux/managing-agents.md` record the former tmux-first ADE plans.
- `tmux-cmux-strategy.md` records the retired tmux/cmux experiment.
- `review-box.md` and `github-pr-review-boxes.md` record the removed legacy
  bridge's state locations and recovery contract. Existing worktrees and state
  are preserved; the implementation is no longer deployed or packaged.

Current workflow authority is [AGENT_WORKFLOW.md](../../../AGENT_WORKFLOW.md).
[Herdr configuration](../../../config/herdr/README.md) documents native operation.
Tmux, cmux, Opensessions, Jmux, workmux and legacy Herdr configurations and
integrations are retired, including their former Mac selections.

Completed `.agents/worklogs/` remain evidence of recovery and prior decisions.
They are not a second operating manual.
