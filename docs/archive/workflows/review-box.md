---
purpose: Record the retired legacy Review Box bridge and its source contract.
applies_to: Historical Review Box state and recovery evidence.
entrypoint: Use config/herdr/README.md for native herdr-app and hc workflows.
verification: Historical record only; the implementation and tests are removed.
update_when: Historical recovery evidence needs clarification.
---

# Review Box

The legacy Review Box implementation and tests have been removed. Git's ghui
configuration no longer supplies a Review Box command or repository mapping.
Native Herdr uses `herdr-app` and `hc`, not the old TUI workspace protocol.
Use `herdr-dev open /path/to/checkout` for an existing checkout and Hunk tab.
It selects `$DEFAULT_CODING_AGENT`, with Pi as the fallback. MacTraitor-Pro
defaults to Amp and Seqeratop to Pi. An explicit `--agent` overrides that choice.

The remaining sections describe the retired implementation, not an
installed native workflow. Existing manifests, worktrees and sessions are left
untouched. No automatic conversion to native spaces is provided.

A legacy Review Box promotes one GitHub pull request into one Herdr workspace. The bridge revalidates it with one read-only `gh pr view`, resolves the configured repository root, and delegates workspace creation or recovery to pi-herdr.

The workspace contains **Hunk**, **Critique**, an agent review tab (`$DEFAULT_CODING_AGENT`, default Pi), and **Approve** tabs. MacTraitor-Pro defaults to Amp and Seqeratop to Pi. Repeating promotion resumes the existing workspace. A changed head SHA refreshes it; a missing workspace or worktree is restored from the surviving state.

A changed review agent, including a legacy OMP manifest, rebuilds the workspace's
tabs on the next promotion. With an unchanged PR head, this leaves the checkout
and uncommitted edits untouched. Subsequent promotions resume those new tabs.

## Legacy bridge contract

An independently configured legacy bridge accepts this input for PR #216:

```sh
gh pr view 216 --repo edmundmiller/dotfiles \
  --json number,headRefOid,headRefName,title,url |
  jq '. + {repository: "edmundmiller/dotfiles"}' |
  review-box
```

Success prints one JSON object with `status`, `workspaceId`, `worktreePath`, and `headRefOid`. `status` is `created`, `resumed`, `restored`, or `refreshed`.

Input is one JSON object on stdin with `repository`, positive integer `number`, `headRefOid`, `headRefName`, `title`, and `url`. The latter four values are hints; GitHub is authoritative.

## State

pi-herdr owns one manifest per repository and pull request at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/pi-herdr/review-boxes/<owner>-<repo>-pr-<n>.json
```

The manifest is mode `0600`, written atomically, and contains exactly:

- `schemaVersion` (`1`)
- `repoRoot`
- `prNumber`
- `prUrl`
- `headRefOid`
- `worktreePath`
- `workspaceId`
- `diffTarget`
- `agent`
- `updatedAt`

`review-box prune` removes manifests only when both their Herdr workspace and worktree are gone.

## Exit codes

| Code | Meaning                                                             |
| ---: | ------------------------------------------------------------------- |
|    0 | Created, resumed, restored, or refreshed successfully.              |
|    2 | Invalid stdin or command usage.                                     |
|    3 | GitHub reports the pull request closed or merged.                   |
|    4 | `gh` is unavailable, times out, fails, or returns invalid data.     |
|    5 | Repository mapping is absent or the Review Box config is malformed. |
|    6 | `git` or Herdr is unavailable, times out, or fails.                 |

Errors produce a JSON object on stdout and a diagnostic on stderr.

## Verification

The retired package tests are no longer available. See
[Herdr](../../../config/herdr/README.md) for supported native configuration
and verification. Do not use the historical commands above for native sessions.
