---
purpose: Persist closeout outcomes, clean only owned task state, and report proof clearly.
applies_to: Done closeout after local or remote landing attempts.
entrypoint: Revalidate landing evidence before receipt completion or cleanup.
verification: Receipt state, cleanup verifier, and final user-visible proof line.
update_when: Receipt schemas, launcher ownership, cleanup, or reporting changes.
---

# Receipt, cleanup, and reporting

## Receipt lifecycle

Receipts are durable provenance, not proof by themselves. Schema v2 stores the
starting revision, destination-at-start, remote-at-start, authority envelope,
explicit task revisions, closeout evidence, and finite outcome. Existing v1
receipts remain readable and upgrade when checkpointed.

When no receipt exists, use `hey agent-adopt` only after explicitly proving the
start revision and task revisions. Record partial outcomes with
`hey agent-checkpoint`; they keep the receipt active. On resume, re-read local
and authoritative state and continue from the first unmet stage.

Use `hey agent-complete` only for `done` or `done_local`. A remote closeout
requires equal proved local and authoritative tips. A mismatch records
`false_done`; never edit the receipt to turn it green.

## Cleanup

Clean only the recorded task workspace and task-owned branches after proof.
Remove no dirty workspace. Before removing any candidate, run:

```bash
bash "${HOME}/.agents/skills/done/scripts/verify-workspace-cleanup.sh" \
  "$active_directory" "$candidate_path"
```

Never delete a candidate that contains `active_directory`, even after changing
directories. Route an active launcher-owned workspace through its launcher.
If task revisions land but the recorded task workspace contains unrelated
dirt, preserve it and return `Landed; cleanup deferred`, never `Done`.

For Herdr, require `HERDR_ENV=1`, `HERDR_WORKSPACE_ID`, clean recorded task
root, and structured ownership proof, then make teardown the last tool action:

```bash
bash "${HOME}/.agents/skills/done/scripts/teardown-herdr-worktree.sh" "$task_root"
```

The Herdr teardown must remove the owned worktree without `--force`.

For Codex Desktop, require `CODEX_THREAD_ID` and proof that the task root is the
calling thread's worktree under `${CODEX_HOME:-$HOME/.codex}/worktrees/`. Use
the current-thread `set_thread_archived` operation, omitting thread and host IDs.
Do not archive a same-directory/local-checkout thread, and never manually remove
an active Codex worktree. If ownership or the tool is unavailable, return
`Landed; cleanup deferred`.

For jj, forget by workspace name and remove only its corresponding physical
path. Preserve other workspaces and bookmarks. For Git, delete a local feature
branch only after containment proof and only when no preserved worktree checks
it out.

## Final report

Lead with the finite user-visible outcome and whether action is required. Then
give one compact proof line: `Landed on <destination>; remote verified; <checks>
passed.` Mention hashes, receipt paths, cleanup internals, and preserved files
only when requested or required for action. For a repeated bare `done`, state
that no additional product change was made and only closeout was reverified.
