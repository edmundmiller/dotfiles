---
name: pr-review-handoff
description: >-
  Prepares intended GitHub pull requests from today's Codex tasks for a concise
  human review handoff. Use when asked to find today's PRs, make PRs or a PR
  stack review-ready, audit current-head checks and reviews, improve PR
  titles/bodies, or draft or send a Slack review handoff.
---

# PR Review Handoff

Turn the user's same-day Codex work into a verified human-review handoff.
`Review-ready` means ready for human review. It does not mean `merge-ready`.

## Boundaries

- Treat Codex tasks as evidence of user intent and GitHub as the source of live PR state.
- Never reply to or resolve human review threads. Never submit a review or approval.
- Never merge, enable auto-merge, or change merge queues unless separately requested.
- Send Slack only when the user explicitly requests sending; otherwise produce a draft.
- Keep all edits, pushes, metadata changes, and messages within the identified scope.

These boundaries override any routed specialist skill.

## Route Specialists

Load matching specialist skills when available:

- Use Codex task tools to list and read today's tasks.
- Use `pr-review` for diff inspection only.
- Use `stack-maintenance` for stack mapping, ancestry, and safe restacking only.
- Use `gh-fix-ci` or the repository's CI workflow for current-head failures.
- Use the Slack skill only for the final draft or explicitly authorized send.

## 1. Identify Intended PRs

1. Resolve "today" in the user's timezone.
2. List bounded Codex tasks created or active today, then read relevant task messages and outcomes.
3. Extract explicit PR URLs/numbers, repositories, branches, stack relationships, and intended actions.
4. Deduplicate PRs and record why each belongs. Exclude incidental mentions.
5. Ask before writes when task evidence leaves PR ownership or scope materially ambiguous.

## 2. Capture Live Evidence

For every in-scope PR, fetch:

- Repository, number, URL, author, state, draft state, title, and full body.
- `baseRefName`, `baseRefOid`, `headRefName`, `headRefOid`, mergeability, and merge-state status.
- Current-head check runs, required checks, conclusions, and check `headSha`.
- Review decision, submitted approvals/changes requested, and requested reviewers.
- All paginated GraphQL `reviewThreads`, including resolution state and participants.

Accept a check only when its SHA equals the current `headRefOid`. Treat older runs as stale.
Count only GitHub-effective approvals; inspect dismissal state and the reviewed commit.
Record dependencies from both the body and actual branch ancestry.

## 3. Repair Bottom-Up

1. Confirm the exact PR-head checkout, branch ownership, clean state, and repository rules before editing.
2. Work from the bottom of the stack. Fix code, tests, CI, conflicts, and actionable feedback with the smallest scoped change.
3. Run focused tests. Push only the authorized PR head; use force-with-lease for an authorized history rewrite.
4. After every push, refresh `headRefOid`, rerun or await checks for that SHA, and re-audit reviews.
5. Leave human threads untouched. Map addressed feedback to commits for the reviewer.

For each parent-to-child edge, verify all three:

- The child's `baseRefName` equals the parent's `headRefName`.
- The child's `baseRefOid` equals the parent's current `headRefOid`.
- The parent's `headRefOid` is an ancestor of the child's `headRefOid`.

Repair or report any mismatch before calling the stack review-ready.

## 4. Make PR Metadata Train-Readable

Use the repository's title convention. Make each title state the concrete outcome
and scope, even when read outside the stack. Avoid agent/process narration and
titles whose only meaning is sequence.

Re-read the live body immediately before editing. Preserve useful human context
and concurrent changes. Keep the body concise:

```markdown
## Summary

- <concrete outcome>
- <important constraint or impact>

## Verification

- `<exercised command or current-head check>`

## Stack

- Position: <n>/<total>
- Depends on: <PR link or none>
- Followed by: <PR link or none>
```

Re-read title, full body, state, base, and head after editing.

## 5. Decide Readiness

A PR is review-ready only when its current head is exercised, required checks are
green, mergeability against its declared base is acceptable, metadata is clear,
and stack dependencies are accurate. Unaddressed actionable feedback blocks
readiness.

An addressed but unresolved human-owned thread may remain for reviewer
confirmation. Report it explicitly; do not resolve it. Approval is not required
for review-ready. `Merge-ready` additionally requires current required approvals,
repository merge gates, and satisfied dependency order.

Use this compact audit:

```text
PR <link> — REVIEW-READY | BLOCKED
Head/base/stack: <sha> / <base> / <position>
Checks/tests: <current-head result>; <local evidence>
Reviews: <decision and approvals>; <unresolved thread summary>
Dependency/blocker: <verified dependency or exact blocker>
```

## 6. Handoff Once

Immediately before handoff, re-read every PR's live body, state, head SHA,
current-head checks, reviews, review threads, base/head ancestry, and
dependencies. If any intended PR is blocked, do not send a review request;
report the blocker instead.

When sending was explicitly requested, resolve the user-named reviewer and
destination, then send exactly one concise Slack message:

```text
Ready for review: <stack/change>
Order: <PR links in review order>
<PR title> — <one-line purpose>
Verified at current heads: checks green; stack/dependencies and live PR bodies audited. Human threads: <status>.
```

Do not call it merge-ready unless separately verified. Verify the one message in
the intended Slack conversation after sending.
