---
description: Turn a rough idea or ready issue into durable, orchestrated, verified work.
---

Treat the request below as a rough outcome, not a pre-approved implementation.

Request:

$ARGUMENTS

1. Inspect the current repository, loaded rules and skills, and existing issue state before choosing the smallest implementation.
2. If `.beads/` exists and the request is non-empty, search before creating. Reuse a matching issue; otherwise create one P2 task whose description contains the normalized outcome, constraints, and observable acceptance evidence. Claim the selected issue with `br update <id> --claim --actor omp` before editing. Never create a duplicate because Beads reports stale state.
3. If `.beads/` exists and the request is empty, run `br scheduler --robot --limit 5`, choose the first ready recommendation, inspect it, and claim it. If there is no tracker, no ready issue, stale state, or a conflicting live claim, stop with the exact blocker; never use `--allow-stale`.
4. Outside a Beads repository, use non-empty input as the outcome and OMP Todo only for session-local tracking. Empty input stops with `no Beads queue and no outcome supplied`; do not invent Todo selection or another durable tracker.
5. For broad or high-risk dotfiles work, follow `AGENT_WORKFLOW.md`: create a worklog, run the plan gate, keep evidence current, and run the full landing gate. Smaller work still requires focused behavioral evidence.
6. Decompose by real dependencies. Launch one Task batch for independent research or non-overlapping edits; use read-only scout agents when file scope is unknown. The main agent owns shared files, integration, commits, rebase/push, and issue closure. Parallel workers never commit or push.
7. Continue after partial failures without user kicks. Close with `br close <id> --reason done --suggest-next` only after every acceptance criterion has fresh evidence and the branch is current upstream.
8. If blocked, leave the issue open or in progress and report attempted paths, the exact blocker, unmet criteria, and the smallest needed input.
