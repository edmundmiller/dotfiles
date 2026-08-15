---
purpose: Complete a policy-required GitHub pull-request closeout without exceeding authority.
applies_to: Done closeout when direct default publication is forbidden or review is required.
entrypoint: Verify GitHub identity and repository targets immediately before writes.
verification: Merged task patch proof and authoritative default-tip readback.
update_when: GitHub authentication, checks, merge, or branch-cleanup policy changes.
---

# Required GitHub PR path

Full `done` authorizes the required PR flow. A narrower request remains limited
to its requested publish, PR, merge, or verification stages.

1. Immediately before each write, verify the active GitHub account,
   organization, repository, remote URL, base branch, and head branch. Abort on
   any mismatch.
2. Push only the proven task-owned branch. Create or update one PR, persist its
   returned number and URL in the receipt, and retry creation only after an
   unambiguous failure.
3. Use the repository's configured default merge method unless the user named
   squash, merge, rebase, or fast-forward explicitly.
4. Poll checks and approvals for at most 15 minutes total, with status updates.
   Do not enable deferred auto-merge. If one clearly task-caused check fails,
   allow one bounded repair commit after focused local proof, update the PR,
   and continue within the same wait budget.
5. Merge only when policy, checks, and approvals permit. Otherwise checkpoint
   `pr_merge_pending` with the exact gate and leave the receipt open.

After merge, fetch the default and prove exact ancestry, per-commit patch
equivalence, or aggregate task-range patch equivalence for squash. Then compare
the local proved default with the authoritative remote tip. Delete the remote
head branch only when the receipt or created PR proves this invocation owns it
and the landed default contains its changes.

For a non-GitHub provider, use it only when authenticated tooling exposes the
same identity, target, policy, merge, and readback guarantees. Otherwise report
an unsupported-provider blocker; do not invent a generic mutation path.
