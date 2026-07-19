---
name: done
description: Lands finished Git worktrees on the default branch, publishes, verifies, and cleans up.
---

# Done

Close the current repository task completely. Preserve unrelated work.

## Completion invariant

A worktree task is done only when:

1. Task changes are committed in reviewable, green commits.
2. The integration commit is an ancestor of the repository's actual default branch.
3. When a writable remote exists, the remote default branch equals the local default branch.
4. The task worktree and feature branch are removed only after those checks pass.

Commit, integration, publication, and cleanup are separate states. Never report
`done` from a clean feature worktree alone.

## Choose the landing path

Honor an explicit PR, local-only, no-push, squash, merge, or fast-forward request.
Honor repository rules that require review or forbid direct pushes. Otherwise,
**Default to direct landing** on the actual default branch and publish it. A bare
`done` invocation authorizes this normal closeout; do not pause to ask PR versus
direct merge again.

Discover the remote and default branch from live Git state. Prefer the remote's
symbolic HEAD or hosting metadata. Fall back to `main` or `master` only when that
ref actually exists. Do not assume the remote is named `origin`.

## Closeout procedure

1. **Snapshot state.** Record repository root, current path, current branch or
   detached HEAD, worktree list, task tip, default branch, remotes, status, and
   ahead/behind counts. Identify unrelated tracked and untracked files before
   mutation.
2. **Commit only task work.** Review all remaining changes. Split distinct
   intents into atomic commits. Leave unrelated dirt unstaged. Run focused checks
   that exercise the changed artifacts.
3. **Refresh references.** Fetch the chosen remote. Reconcile the destination's
   local-only commits and its remote tip before integrating. In a feature
   worktree, rebase onto that reconciled destination when safe, resolve
   conflicts, and rerun checks if commit IDs or content changed. On detached
   HEAD, retain the task tip explicitly before switching contexts.
4. **Integrate.** For direct landing, prefer a fast-forward onto the default
   branch. Use its existing checkout or a temporary clean integration worktree.
   Preserve unrelated dirt; never overwrite, reset, or blindly stash it. If the
   destination advanced concurrently, fetch, reconcile, and retry from fresh
   state. For a PR path, push the feature branch and follow repository policy;
   an open PR is not a merged task.
5. **Publish.** Push the default branch, not merely the feature branch, unless
   the requested PR path is still awaiting merge. Do not bypass failing hooks.
6. **Prove landing.** After the final fetch, verify the integration tip is
   contained by the default branch. Prefer the verifier at the canonical global
   skill installation path:

   ```bash
   bash "${HOME}/.agents/skills/done/scripts/verify-landing.sh" \
     "$integration_tip" "$default_branch" "$remote"
   ```

   If the installed script path is unavailable, run its two checks directly:

   ```bash
   git merge-base --is-ancestor "$integration_tip" "$default_branch"
   ```

   When a remote exists, read its authoritative head and require equality with
   the local destination:

   ```bash
   local_tip=$(git rev-parse "$default_branch")
   remote_tip=$(git ls-remote "$remote" "refs/heads/$default_branch" | awk 'NR == 1 { print $1 }')
   test -n "$remote_tip" && test "$local_tip" = "$remote_tip"
   ```

   A successful push response alone is not proof.

7. **Close linked work.** Mark a linked issue or task complete only after its
   acceptance criteria and landing state are verified. Do not close a broader
   tracking issue merely because this slice landed.
8. **Clean up last.** Recheck tracked and untracked files in the task worktree.
   **Do not remove the worktree** while it contains uncommitted, untracked, or
   unrelated files. Preserve them or report the exact blocker. Delete the
   feature branch only when Git proves it is an ancestor of the destination.
   Never use forced worktree removal to manufacture a clean result.

## Final report

Report the default branch, integration tip, remote tip or no-remote boundary,
checks run, linked-issue state, worktree/branch cleanup, and unrelated files
preserved. If any invariant is unproved, say `blocked` or `local only`, keep the
worktree recoverable, and give the exact next action.
