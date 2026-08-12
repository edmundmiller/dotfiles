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
4. After proof, remove a task worktree/workspace and feature branch/bookmark. Use the owning launcher for its active worktree; never delete the agent's original directory directly.

Commit/change shaping, integration, publication, proof, and cleanup are separate states. Never report `done` from a clean feature workspace alone.

## Select the backend

Run `jj root --ignore-working-copy`. If it succeeds, use the jj path. Otherwise use Git. Never initialize jj during closeout.

Honor an explicit PR, local-only, no-push, squash, merge, or fast-forward request. Honor repository rules that require review or forbid direct pushes. Otherwise, **Default to direct landing** on the actual default branch/bookmark and publish it. A bare `done` authorizes this closeout; do not ask PR versus direct merge again.

Discover the remote and default destination from live state. Prefer remote symbolic HEAD, hosting metadata, or jj's `trunk()`/tracked bookmarks. Fall back to `main` or `master` only when the ref exists. Do not assume the remote is `origin`.

## Git closeout

### Concurrent default-branch advancement

Concurrent remote advancement is expected reconciliation work, not a blocker.
Before fetching, record the explicit task base, task commits, task tip, and the
then-current local default tip. Do not infer the task range from every ancestor
of the task tip. Commits after the recorded task tip on the local default are
later local-only commits and must be classified separately.

After fetching the remote default branch:

1. Compare each explicit task commit and each later local-only commit with the
   refreshed remote. Exact ancestry or stable patch identity is proof that a
   change is already landed; commit subjects alone are not. `git cherry` or
   `git patch-id --stable` can provide the patch comparison.
2. Create a clean temporary integration worktree at the refreshed remote tip
   and replay the classified remainder there as a preflight. Replay, in original
   order, only explicit task commits without a remote equivalent and later
   local-only commits without a remote equivalent. If the task commits are
   already landed under corrected or rebased IDs, do not duplicate them.
3. If the local default has diverged only through remote-equivalent task commits
   followed by the explicit later commits, rebase that later range onto the
   remote tip with `git rebase --onto "$remote/$default_branch" "$task_tip"
"$default_branch"`. With unrelated dirt, the only permitted stash mechanism
   is that same command's `--autostash`, after the clean preflight and dirty-file
   fingerprint. Never create a named/manual stash or use autostash for an
   unclassified range.
4. If the local default is already an ancestor of the integration tip, use the
   ordinary fast-forward path instead. Push without force, fetch, and prove
   task containment plus local/remote equality.

Before integration, fingerprint every unrelated dirty path's status, mode, and
bytes. Re-read the same paths after the fast-forward and after publication;
any change is a failed preservation check, not success.

Block only on an actual replay conflict, autostash restoration conflict,
dirty-path overlap refused by Git, or missing authority to replay or publish a
local-only commit. Abort a conflicted preflight in the temporary worktree and
leave the original checkout untouched. If autostash restoration conflicts,
stop before push, preserve Git's recovery ref, and report it exactly. A changed
remote tip, divergent commit IDs, or already-landed equivalent task changes are
not blockers.

Pre-push identity hooks may scan all local refs rather than only the ref being
pushed. If such a hook rejects an offending local ref, report that hook and ref
as a separate blocker from ordinary remote advancement. Preserve the ref and
first prove whether its finished work is contained or patch-equivalent on the
remote; do not delete or rewrite user-owned refs without authority. Never
bypass, weaken, or skip the hook to publish.

### Dirty default checkout integration

Unrelated dirt in the default branch's existing checkout is not itself a
blocker after task changes are committed. Preserve it and first try the normal
safe Git path:

1. Fetch the remote and create a clean temporary integration worktree at the
   remote default tip.
2. Rebase or cherry-pick only the explicit task commits there. Never absorb
   other commits merely because they are ancestors of the task tip.
3. Run `git -C "$default_checkout" merge --ff-only "$integration_tip"`.
   Git will refuse before overwriting overlapping tracked or untracked work.
4. When it succeeds, push the default branch without force, fetch again, and
   prove local/remote equality.

Report `Blocked:` only for the conflicts, overlaps, or missing authority defined
above. In this dirty-checkout path, report overlap only when Git refuses the
fast-forward; include its refusal as evidence. Never move
that checkout to a preservation branch, or create a preservation branch to free
the default branch. Except for that bounded autostash, never
stash, reset, commit its unrelated dirt, or update its checked-out branch ref.
The exception applies only to an explicitly classified later range. A bare
`done` does not authorize changing the branch meaning of another checkout.

Unrelated dirt in a non-default task worktree does not block landing its already
committed task revision through a clean default checkout. Preserve the dirt and
defer that worktree's cleanup.

1. **Snapshot.** Before any `cd`, record `active_directory=$(pwd -P)` and never recompute it. Record root, path, branch/detached state, worktrees, explicit task base/commits/tip, the then-current default tip, default branch, remotes, status, and ahead/behind counts. Identify and fingerprint unrelated files.
2. **Commit task work.** Split distinct intents. Leave unrelated dirt unstaged. Run focused checks.
3. **Refresh.** Fetch the chosen remote. Apply the concurrent-advancement classification above to explicit task commits and later local-only commits. Replay only changes not already remote-equivalent; rerun checks after changed content or commit IDs.
4. **Integrate.** Prefer a fast-forward on the default branch. Use its clean checkout directly, or use a temporary integration worktree and then attempt `merge --ff-only` in a dirty default checkout as described above. Never reset, overwrite, or blindly stash unrelated dirt.
5. **Publish.** Push the default branch, not merely the feature branch. Do not bypass hooks.
6. **Prove.** After a final fetch, run:

   ```bash
   bash "${HOME}/.agents/skills/done/scripts/verify-landing.sh" \
     "$integration_tip" "$default_branch" "$remote"
   ```

   If the installed verifier is unavailable, require both `git merge-base --is-ancestor "$integration_tip" "$default_branch"` and equality between `git rev-parse "$default_branch"` and `git ls-remote "$remote" "refs/heads/$default_branch"`.

7. **Clean up last.** Recheck tracked/untracked files. Remove no dirty worktree.
   Do not remove the worktree before the cleanup verifier passes. Before
   removing any candidate worktree, require:

   ```bash
   if bash "${HOME}/.agents/skills/done/scripts/verify-workspace-cleanup.sh" \
     "$active_directory" "$candidate_worktree"
   then
     git worktree remove "$candidate_worktree"
   fi
   ```

   Never delete a candidate that contains `active_directory`, even after `cd`
   elsewhere. `cd`-ing out first only leaves the returning shell in a deleted
   CWD. Route a recognized launcher-owned current worktree through **Launcher
   teardown** after completing any receipt. Otherwise report cleanup deferred,
   not failed. Delete a feature branch only after Git proves containment and no
   preserved worktree still checks it out.

## jj closeout

`@` is workspace-local. Other workspaces share the repository and operation log, not the same working-copy commit. Never use repository-wide `jj undo` or `jj op restore` as routine recovery while other agents may be active.

1. **Snapshot.** Before any `cd`, record `active_directory=$(pwd -P)` and never recompute it. Record `jj root`, `jj workspace root`, `jj workspace list`, `jj status`, `jj op log -n 1`, `jj git remote list`, and `jj log -r '@-::@ | trunk()'`. Identify unrelated files, the task's stable change ID, and each cleanup candidate's workspace name and physical root separately.
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

7. **Clean up last.** Confirm the task workspace is empty and contains no unrelated files. Before forgetting or removing a workspace, require:

   ```bash
   bash "${HOME}/.agents/skills/done/scripts/verify-workspace-cleanup.sh" \
     "$active_directory" "$candidate_workspace_path"
   ```

   Forget by workspace name and remove only the corresponding physical path
   after the verifier succeeds. Never remove the workspace containing
   `active_directory`, even after `cd` elsewhere. Route a recognized
   launcher-owned current workspace through **Launcher teardown** after
   completing any receipt. Otherwise preserve it and report cleanup deferred.
   Preserve other workspaces and bookmarks.

## Receipt

If `agent-start` produced a receipt, finish it only after proof. Record the proved local and authoritative remote tips:

```bash
hey agent-complete "$receipt" \
  --revision "$task_revision" \
  --local-tip "$local_tip" \
  --remote-tip "$remote_tip"
```

A mismatch records `false_done` and fails. Do not edit the receipt to turn it green.

## Launcher teardown

Launcher teardown applies only after landing proof, receipt completion, and a
fresh check that the recorded task checkout has no tracked, untracked, or
conflicted files. Prepare the final report first. Do not manually remove the
active directory.

### Herdr

When `HERDR_ENV=1`, invoke the teardown script with the recorded task root as
the last tool action:

```bash
bash "${HOME}/.agents/skills/done/scripts/teardown-herdr-worktree.sh" \
  "$task_root"
```

The script requires `HERDR_WORKSPACE_ID`, proves the active directory and clean
Git root match the recorded task root, parses Herdr's structured worktree
provenance, and executes native worktree removal without `--force`. It never
closes a normal or parent Herdr workspace. Treat any refusal as deferred cleanup
and report its exact reason.

### Codex Desktop

When `CODEX_THREAD_ID` is set, first confirm the recorded task root is the
calling thread's Codex-owned worktree under
`${CODEX_HOME:-$HOME/.codex}/worktrees/`. Do not archive a same-directory or
local-checkout thread merely because the variable exists.

Use the current-thread `set_thread_archived` tool with `{ "archived": true }`,
omitting `threadId` and `hostId`. The background archive lets Codex Desktop own
thread and worktree cleanup. Never run `git worktree remove` against the active
Codex worktree. If the tool is unavailable or ownership cannot be proved,
report cleanup deferred and tell the user to archive the thread in Codex
Desktop.

## Final report

Lead with the user-visible result in plain language: what changed, whether it works, and whether the user needs to act. For a bare `done` after an earlier completion report, say explicitly that no additional product change was made; only closeout was re-verified.

Follow with one compact proof line: `Landed on <destination>; remote verified; <checks> passed.` Include hashes, local/remote tip equality, worktree, branch, receipt, and unrelated-file details only when the user asks or they require user action. Otherwise say only that unrelated work was preserved. Never lead with backend, branch cleanup, raw hashes, or other repository mechanics.

If any landing invariant is unproved, lead with `Blocked:` or `Local only:` and give the exact next action.
