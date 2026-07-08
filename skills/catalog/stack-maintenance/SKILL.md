---
name: stack-maintenance
description: Maintains stacked GitHub PRs and branches. Triggers on "fix stacked PRs", "merge this PR stack", "restack branches", "turn on auto-merge", `gh stack`, `gh pr`, `jj spr`, wrong PR bases, merge queues, or force-pushing stack repairs.
---

# Stack Maintenance

Keep stacked GitHub pull requests boring: map the real stack, act from the bottom, verify after every remote action, and rewrite branches only with a lease.

Use this skill for PR chains, dependent branches, branch retargeting, merge queues, stale parent branches, and review/merge triage. Prefer existing stack tools (`gh stack`, `gh pr stack`, `jj spr`) when the repository has them; fall back to plain `gh` and `git` only after confirming the tool is unavailable or insufficient.

## Rules From Prior Stacked PR Incidents

- Trust fresh GitHub metadata, not memory. Fetch `baseRefName`, `headRefName`, `mergeStateStatus`, `mergeable`, `reviewDecision`, checks, and auto-merge state before acting.
- Stacked PRs usually merge bottom-up. A child can become conflicted after its parent merges; expect to rebase or retarget it before merging.
- `gh pr merge --auto --squash` can merge immediately for intermediate stack branches. Re-read the PR afterward; do not infer from command text.
- Main may use a merge queue. If GitHub says the merge strategy is controlled by the queue, retry without an explicit strategy, then re-read `state`, `mergedAt`, and `mergeCommit`.
- Do not approve a PR before reviewing its diff and running the relevant local check. "Clean" only means mergeable, not reviewed.
- Use `--delete-branch=false` for stack branches unless the user explicitly asks to prune. Other PRs may still depend on them.
- Use `git push --force-with-lease`, never plain force, after rebasing a PR branch.
- Stop before rewriting someone else's branch unless ownership and permission are clear.

## Map The Stack First

Start with the current checkout and remote state:

```sh
git status --short --branch
git fetch origin --prune
```

List open PRs with the fields that matter:

```sh
gh pr list --state open --limit 100 \
  --json number,title,author,baseRefName,headRefName,isDraft,mergeable,mergeStateStatus,reviewDecision,autoMergeRequest,statusCheckRollup,url
```

Classify PRs into four buckets:

1. **Merge candidates**: non-draft, `MERGEABLE`, `CLEAN`, no failing checks, not `CHANGES_REQUESTED`.
2. **Review candidates**: clean but unapproved; inspect before approving.
3. **Stack repair**: wrong base, conflicted, stale parent, or child branch blocked by a parent merge.
4. **Leave alone**: draft, changes requested, branch owned by someone else, or unclear intent.

For a focused PR, inspect the exact relationship:

```sh
gh pr view <n> --json number,title,author,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision,autoMergeRequest,statusCheckRollup,url
```

## Merge Or Queue Safely

Merge bottom-up. After each merge, re-read the next child because the base may have changed.

For intermediate stack branches:

```sh
gh pr merge <n> --auto --squash --delete-branch=false
```

For a main-branch PR with merge queue behavior:

```sh
gh pr merge <n> --auto --delete-branch=false
```

Verify immediately:

```sh
gh pr view <n> --json number,state,mergedAt,mergedBy,mergeCommit,mergeStateStatus,autoMergeRequest,url,title
```

If the command reports an error that implies a race, stale base, or already-merged PR, re-read the PR before retrying. GitHub may have completed the merge while the CLI reported a confusing GraphQL error.

## Review Before Approval

For a clean but unapproved PR:

```sh
gh pr diff <n> --name-only
gh pr diff <n> --patch
```

Run the smallest relevant check in a clean checkout or temporary worktree. Approve only after the diff and check match the intended change:

```sh
gh pr review <n> --approve --body "Reviewed diff and validated with <command>."
```

Then merge or queue it using the rules above.

## Repair A Conflicted Child

Prefer stack tooling when available:

```sh
gh stack view
gh stack sync
gh stack submit
```

If using plain Git, repair in a throwaway worktree:

```sh
pr=123
base_branch=parent-branch
head_branch=child-branch
git fetch origin "$base_branch" "$head_branch"
tmp=$(mktemp -d "/tmp/gradient-pr${pr}.XXXXXX")
git worktree add -B "fix-pr${pr}" "$tmp" "origin/$head_branch"
cd "$tmp"
git rebase "origin/$base_branch"
```

Resolve conflicts, choosing the final intended content rather than mechanically taking either side:

```sh
git status --short
git add <file>
git rebase --continue
```

Run the relevant check. Push back with a lease:

```sh
git push --force-with-lease origin "fix-pr${pr}:$head_branch"
```

Re-read the PR. Merge only when it returns to `MERGEABLE` and `CLEAN`.

Clean temporary worktrees after use:

```sh
git worktree remove --force "$tmp"
```

## Retarget Wrong Bases

If the commits are correct but the PR targets the wrong parent:

```sh
gh pr edit <n> --base <correct-base-branch>
gh pr view <n> --json number,baseRefName,headRefName,mergeable,mergeStateStatus,url
```

If retargeting introduces conflicts, repair the branch against the new base before merging.

## Done Criteria

- Every acted-on PR has fresh `gh pr view` evidence after the action.
- Merged PRs show `state: MERGED`, `mergedAt`, and a merge commit.
- Queued PRs show auto-merge or merge-queue state expected by the repository.
- Rewritten branches were pushed with `--force-with-lease`.
- Local temporary worktrees are removed.
- Final report lists merged, queued, repaired, and intentionally skipped PRs separately.
