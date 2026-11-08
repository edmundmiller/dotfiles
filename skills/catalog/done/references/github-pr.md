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
4. Subscribe the existing owner thread to exact-head CI and PR comments/reviews
   through the runtime's native event tools. Confirm the subscriptions are active;
   a returned ID can refer to a paused listener. Persist their IDs, exact SHA,
   branch, workflow, remaining authority, and next action in the existing receipt.
   When checks or approvals remain, checkpoint `pr_merge_pending` and end active
   waiting within 60 seconds if no independent work remains. Use no CI watcher,
   sleep loop, or keep-alive polling. Missing event support is a recoverable
   blocker, not permission to lose follow-through. If higher-priority runtime
   instructions require synchronous waiting, report that capability blocker.
   Do not enable deferred auto-merge. On an event, re-read the current PR head,
   latest check attempts, approvals, policy, and authorization before any write.
   A stale event is not merge authority. For a clearly task-caused failure, allow
   one bounded repair after focused proof, publish, and replace the exact-head
   subscription and checkpoint. Duplicate events first recheck whether the
   requested merge already happened.
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
