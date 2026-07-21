---
name: batch
compatibility: portable
description: Coordinate a sweeping mechanical change across independent work units and pull requests.
---

# Batch: Parallel Work Orchestration

You are orchestrating a large, parallelizable change across this codebase.

## User Instruction

(The user's instruction goes here — passed as the skill argument.)

## Phase 1: Research and Plan

Use the runtime's planning surface when available.

1. **Understand the scope.** Inspect the repository, patterns, call sites, and applicable conventions. Use research agents only when the user authorized delegation and the runtime supports it.

2. **Decompose into independent units.** Break the work into the smallest useful set of self-contained units. Each unit must:
   - Be independently implementable in an isolated git worktree (no shared state with sibling units)
   - Be mergeable on its own without depending on another unit's PR landing first
   - Be roughly uniform in size (split large units, merge trivial ones)

   Scale the count to the work and the runtime's concurrency limit. Prefer per-directory or per-module slicing over arbitrary file lists.

3. **Determine the e2e test recipe.** Figure out how a worker can verify its change actually works end-to-end — not just that unit tests pass. Look for:
   - An available browser-automation tool (for UI changes: click through the affected flow, screenshot the result)
   - A `tmux` or CLI-verifier skill (for CLI changes: launch the app interactively, exercise the changed behavior)
   - A dev-server + curl pattern (for API changes: start the server, hit the affected endpoints)
   - An existing e2e/integration test suite the worker can run

   If no concrete e2e path exists, ask the user with 2–3 repository-grounded options. Do not invent a verification claim.

   Write the recipe as a short, concrete set of steps that a worker can execute autonomously. Include any setup (start a dev server, build first) and the exact command/interaction to verify.

4. **Write the plan.** In your plan file, include:
   - A summary of what you found during research
   - A numbered list of work units — for each: a short title, the list of files/directories it covers, and a one-line description of the change
   - The e2e test recipe (or "skip e2e because …" if the user chose that)
   - The exact worker instructions you will give each agent (the shared template)

5. Present the plan for approval before creating workers or external pull requests.

## Phase 2: Spawn Workers (After Plan Approval)

Once the plan is approved, use the runtime's isolated worktree or thread mechanism. Keep active workers within the runtime's concurrency limit. If isolated workers are unavailable, process units sequentially in isolated worktrees.

For each agent, the prompt must be fully self-contained. Include:

- The overall goal (the user's instruction)
- This unit's specific task (title, file list, change description — copied verbatim from your plan)
- Any codebase conventions you discovered that the worker needs to follow
- The e2e test recipe from your plan (or "skip e2e because …")
- The worker instructions below, copied verbatim:

```
After you finish implementing the change:
1. **Simplify** — Follow the `simplify` skill to review and clean up your changes.
2. **Run unit tests** — Run the project's test suite (check for package.json scripts, Makefile targets, or common commands like `npm test`, `bun test`, `pytest`, `go test`). If tests fail, fix them.
3. **Test end-to-end** — Follow the e2e test recipe from the coordinator's prompt (below). If the recipe says to skip e2e for this unit, skip it.
4. **Land only as authorized** — Commit, push, or create a PR only when the user authorized those actions. Otherwise report the isolated branch or worktree.
5. **Report** — End with the unit status, verification evidence, and PR URL or branch when applicable.
```

## Phase 3: Track Progress

After launching all workers, render an initial status table:

| #   | Unit    | Status  | PR  |
| --- | ------- | ------- | --- |
| 1   | <title> | running | —   |
| 2   | <title> | running | —   |

As worker results arrive, re-render the table with updated status and PR or branch links. Keep a brief failure note for incomplete units.

When all agents have reported, render the final table and a one-line summary (e.g., "22/24 units landed as PRs").
