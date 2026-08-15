---
purpose: Land explicit Git task revisions without publishing or damaging unrelated work.
applies_to: Done closeout after jj backend detection fails.
entrypoint: Snapshot first, then classify explicit task revisions against the fetched default.
verification: verify-landing.sh plus authoritative remote-tip equality.
update_when: Git reconciliation, dirty-checkout, or proof policy changes.
---

# Git closeout

## Snapshot and classification

Record the task base, every explicit task commit, task tip, current local
default tip, and later local-only commits before fetching. A remote advance is
an expected reconciliation event, not a blocker.

After fetch, run the closeout classifier with the saved snapshot and each
explicit task revision. It uses exact ancestry or stable patch equivalence and classifies exact, patch-equivalent,
aggregate-patch-equivalent, and unlanded work. A matching subject is not proof.
Skip landed equivalents rather than duplicating them.

Treat later local-only commits as a separate publication scope. If any are without publication authority, stop before landing. Do not publish them, replay them,
or infer authority from their presence on local default. When the user
explicitly authorizes named later commits, pass each as an allowed local
revision and replay only those commits in oldest-first order.

For full closeout, unauthorized local-default commits always make the outcome
`Blocked`, even if external work already landed patch-equivalent task commits.
This is scope ambiguity, not workspace cleanup deferral.

## Concurrent default advancement

Reconcile the first remote advance automatically. If a normal push is rejected
by one further advance, fetch, classify, reconcile, and retry once. A second
race is `Blocked`; preserve every original commit.

Resolve a replay conflict only when the combined text preserves every
non-conflicting hunk and both evident intents, introduces no product choice,
survives resolved-diff review, and passes affected checks. Otherwise abort the
replay and report conflicting paths. Never discard either side because the
result appears simpler.

Do not use `--force` or `--no-verify`, reset the default branch, rewrite
unrelated commits, or weaken hooks. If an identity hook scans and rejects an
unrelated local ref, preserve the reconciled commits and report the exact hook
blocker; do not delete that ref without authority.

## Dirty default checkout integration

Unrelated dirt is not itself a blocker after task work is committed:

1. Capture a secret-safe fingerprint of status, staged diff, unstaged diff,
   and untracked-file hashes.
2. Create a clean temporary integration worktree at the fetched remote default.
3. Replay only explicit unlanded task commits there.
4. Run `git -C "$default_checkout" merge --ff-only "$integration_tip"`.
5. If it succeeds, verify that unrelated dirt is byte-for-byte unchanged.

Report `Blocked` only when Git refuses because dirty paths overlap, the
authorized reconciliation conflicts, or task/publication scope cannot be
proved. Include Git's refusal. Never move that checkout to a preservation branch
or create one to free the default branch. Except for a proven targeted
`git rebase --autostash --onto` of explicitly authorized later commits, never
stash, reset, commit its unrelated dirt, or update its branch ref directly.
Require autostash to reapply fully with no new stash entry.

Unrelated dirt in a non-default task worktree does not block landing already
committed task revisions through a clean integration path. Preserve it and
defer that worktree's cleanup.

## Direct landing and proof

Prefer fast-forward integration. Push the default branch normally, fetch again,
then run:

```bash
bash "${HOME}/.agents/skills/done/scripts/verify-landing.sh" \
  "$integration_tip" "$default_branch" "$remote"
```

If the installed verifier is unavailable, require both
`git merge-base --is-ancestor "$integration_tip" "$default_branch"` and
equality between `git rev-parse "$default_branch"` and
`git ls-remote "$remote" "refs/heads/$default_branch"`.

When squash landing combines multiple task commits, compare the aggregate
task-base-to-tip patch with the landed PR commit's parent-to-commit patch. A
provider merged flag without this proof is insufficient.
