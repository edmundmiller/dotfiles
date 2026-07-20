---
name: done
description: Lands finished Git worktrees or jj workspaces, publishes, proves remote equality, and cleans up.
---

# Done

Close the current repository task completely. Preserve unrelated work.

## Completion invariant

A task is done only when:

1. Task changes are shaped into reviewable, green Git commits or jj changes.
2. The task revision is an ancestor of the repository's actual default branch/bookmark.
3. When a writable remote exists, the authoritative remote default tip equals the local default tip.
4. The task worktree/workspace and feature branch/bookmark are removed only after proof passes.

Commit/change shaping, integration, publication, proof, and cleanup are separate states. Never report `done` from a clean feature workspace alone.

## Select the backend

Run `jj root --ignore-working-copy`. If it succeeds, use the jj path. Otherwise use Git. Never initialize jj during closeout.

Honor an explicit PR, local-only, no-push, squash, merge, or fast-forward request. Honor repository rules that require review or forbid direct pushes. Otherwise, **Default to direct landing** on the actual default branch/bookmark and publish it. A bare `done` authorizes this closeout; do not ask PR versus direct merge again.

Discover the remote and default destination from live state. Prefer remote symbolic HEAD, hosting metadata, or jj's `trunk()`/tracked bookmarks. Fall back to `main` or `master` only when the ref exists. Do not assume the remote is `origin`.

## Git closeout

1. **Snapshot.** Record root, path, branch/detached state, worktrees, task tip, default branch, remotes, status, and ahead/behind counts. Identify unrelated files.
2. **Commit task work.** Split distinct intents. Leave unrelated dirt unstaged. Run focused checks.
3. **Refresh.** Fetch the chosen remote. Reconcile destination local-only commits and remote tip. Rebase the feature when safe; rerun checks after changed content or commit IDs.
4. **Integrate.** Prefer a fast-forward on the default branch, using its clean checkout or a temporary integration worktree. Never reset, overwrite, or blindly stash unrelated dirt.
5. **Publish.** Push the default branch, not merely the feature branch. Do not bypass hooks.
6. **Prove.** After a final fetch, run:

   ```bash
   bash "${HOME}/.agents/skills/done/scripts/verify-landing.sh" \
     "$integration_tip" "$default_branch" "$remote"
   ```

   If the installed verifier is unavailable, require both `git merge-base --is-ancestor "$integration_tip" "$default_branch"` and equality between `git rev-parse "$default_branch"` and `git ls-remote "$remote" "refs/heads/$default_branch"`.

7. **Clean up last.** Recheck tracked/untracked files. Remove no dirty worktree. Delete a feature branch only after Git proves it is contained by the destination.

## jj closeout

`@` is workspace-local. Other workspaces share the repository and operation log, not the same working-copy commit. Never use repository-wide `jj undo` or `jj op restore` as routine recovery while other agents may be active.

1. **Snapshot.** Record `jj root`, `jj workspace root`, `jj workspace list`, `jj status`, `jj op log -n 1`, `jj git remote list`, and `jj log -r '@-::@ | trunk()'`. Identify unrelated files and the task's stable change ID.
2. **Shape task work.** Resolve conflicts, describe each meaningful change, run focused checks, then create an empty successor with `jj new`. Record the completed task change ID explicitly; do not blindly assume every `@-` belongs to this task.
3. **Refresh.** Run `jj git fetch --remote "$remote"`. Determine the actual default bookmark and tracked remote bookmark. If the remote advanced, rebase only the task's explicit change range onto the fresh remote destination and rerun checks.
4. **Integrate.** Move the local default bookmark to the rebased task tip only after proving the intended task range. Do not move unrelated bookmarks.

   ```bash
   jj bookmark set "$default_bookmark" -r "$task_change_id"
   ```

5. **Publish.** Push that bookmark through jj. Raw `git push` and `jj_vcs align_push` bypass this proof contract.

   ```bash
   jj git push --remote "$remote" --bookmark "$default_bookmark"
   jj git fetch --remote "$remote"
   ```

6. **Prove.** Use the stable task change ID; sign-on-push may rewrite its commit ID.

   ```bash
   bash "${HOME}/.agents/skills/done/scripts/verify-jj-landing.sh" \
     "$task_change_id" "$default_bookmark" "$remote"
   ```

   The verifier requires no task conflict, task containment by the local default bookmark, and equality among local, tracked-remote, and authoritative Git remote tips.

7. **Clean up last.** Confirm the task workspace is empty and contains no unrelated files. Forget and remove only that workspace. Preserve other workspaces and bookmarks.

Do not remove the worktree or workspace before proof and dirt checks pass.

## Receipt

If `agent-start` produced a receipt, finish it only after proof. Record the proved local and authoritative remote tips:

```bash
hey agent-complete "$receipt" \
  --revision "$task_revision" \
  --local-tip "$local_tip" \
  --remote-tip "$remote_tip"
```

A mismatch records `false_done` and fails. Do not edit the receipt to turn it green.

## Final report

Report backend, default destination, task revision, local/remote tip, checks, linked work, cleanup, receipt, and unrelated files preserved. If any invariant is unproved, say `blocked` or `local only`, keep recovery state, and give the exact next action.
