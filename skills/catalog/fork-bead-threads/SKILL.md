---
name: fork-bead-threads
description: Fork one isolated Codex worktree thread per Beads issue and start each with a dependency-aware completion contract. Use when the user asks to start, fork, split, parallelize, or create separate chats for beads, tickets, issues, or a backlog with the goal of fixing them all.
---

# Fork Bead Threads

Turn a Beads work surface into clearly named, isolated Codex threads that own outcomes through verification, closure, commit, and push.

## Build the launch set

1. Read every requested issue with `br show <id>` and inspect native dependencies.
2. Search recent Codex threads for each bead ID. Reuse an existing active owner; never launch two owners for one bead.
3. Include missing concrete prerequisite beads required to unblock the requested work.
4. Skip umbrella issues and epics unless they contain independent implementation work.
5. Record the frontier:
   - ready issues start immediately
   - blocked issues get their blocker issue and owning thread ID

Do not flatten dependencies merely to maximize parallelism.

## Fork isolated worktrees

Use `codex_app__fork_thread` with `environment.type = "worktree"` for implementation work. Use a same-directory fork only for read-only work or when the user explicitly wants a shared checkout.

Omit `threadId` to fork the calling thread. A fork copies completed history only: the active turn is absent. Always send a fresh follow-up prompt after forking.

Fork one thread per bead. Add one thread per missing prerequisite needed for the requested set to make progress.

## Name for humans

Rename every thread with `codex_app__set_thread_title` using:

```text
<Outcome-focused phrase> · <bead-id>
```

Examples:

- `Restore Amos Cron Scheduling · workspace-rtl.1`
- `Add Blogwatcher to Radar · workspace-by1`
- `Fix Hermes Timer Health Reporting · workspace-i1q`

Lead with the desired result, use 3–7 words, and keep the bead ID last for traceability. Avoid ID-first titles, generic verbs, and copied issue titles when a clearer human phrase exists.

## Send the completion contract

Send each child a bead-specific prompt with `codex_app__send_message_to_thread`. Preserve this contract while tailoring ownership, source repos, validation, deployment, and blockers:

```text
Own bead <id>: <human title>.

Goal: fully fix the bead, not merely investigate or plan.

Start with `br show <id>`, read applicable AGENTS.md files, inspect current source and live state, and preserve unrelated changes.

Dependency contract: <ready now | blocker bead, owner thread ID, and recheck instruction>.

Execution contract:
- Claim/update the bead only when genuinely actionable.
- Work in canonical source; honor repo and infrastructure ownership boundaries.
- Follow required regression/TDD workflow for behavior bugs.
- Deploy through the documented path when acceptance requires live state.
- Verify every acceptance criterion with fresh tests, diffs, deploy output, logs, artifacts, and natural-run evidence as applicable.
- Do not manually trigger behavior whose acceptance criterion requires a natural run.
- Keep changes task-shaped. Commit and push owned changes; never overwrite another thread or force-push.
- Update/close the bead only after all acceptance criteria are proven.
- If externally blocked, leave it open with exact evidence and the smallest unblocker.
- Do not stop at a plan. Continue autonomously until complete or truly blocked.
- Final handoff: issue status, commits/branches, changed repos, tests, deployment evidence, live evidence, and remaining blocker.
```

Tell blocked workers not to duplicate their prerequisite owner's work. They may orient and wait, then continue after the blocker lands.

## Coordinate shared surfaces

Worktree isolation protects Git files, not live systems.

- Serialize deployments that target the same host or service.
- Keep profile-specific changes separate when possible.
- Let each worker own its tracker update; avoid root-thread status churn that will conflict during integration.
- Give dependent workers the exact prerequisite bead and thread IDs.
- Do not close umbrella issues until every child acceptance contract is verified.

## Verify the launch

After title and prompt calls succeed, re-read authoritative thread state with `codex_app__list_threads`.

Confirm for every requested bead:

- exactly one thread exists
- the outcome-focused title is correct
- status is active
- implementation threads have distinct worktree paths
- each blocker has an owner or an explicit external blocker

Do not claim success from mutation responses alone.

## Report

Return a compact mapping of bead ID to thread ID, note any added prerequisite threads, and state whether every thread is active. Keep implementation results separate: launching threads is complete before the child fixes are complete.
