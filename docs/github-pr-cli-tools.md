---
purpose: Describe supported terminal tools for GitHub PR review.
applies_to: Reviewing GitHub PRs with ghui, gh-dash, Hunk, or agents.
entrypoint: Triage in ghui or gh-dash, then review the intended checkout.
verification: Check the live review source before submitting findings.
update_when: Queue selection or review tooling changes.
---

# GitHub PR review workflow

GitHub owns queue and review state. Use GitHub Inbox, `ghui`, or `gh-dash` to
triage PRs. Open the intended checkout before reviewing. In native Herdr,
`herdr-dev hunk` opens Hunk beside the focused local terminal, while
`herdr-dev open /path/to/checkout` opens an agent and Hunk.

Use `hunk session get --repo /absolute/worktree --json` to confirm the live
review source. Only submit a GitHub comment, approval or change request with
the user's authorization. Opening a diff does not submit a review.

The old `/review-box` integration is retired. Existing worktrees and state are
not deleted or migrated. See the [historical recovery record](archive/workflows/github-pr-review-boxes.md)
for their locations. Do not initialize jj inside an existing detached Git
worktree to imitate the retired workflow.
