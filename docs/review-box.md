---
purpose: Document promotion and recovery of GitHub pull requests as Herdr Review Boxes.
applies_to: Using ghui or the review-box CLI with configured repositories.
entrypoint: Select a pull request in ghui and run Promote/resume Review Box, or invoke review-box directly.
verification: Run pkg-check ghui, pkg-check review-box, hey check, and the manual example below.
update_when: The ghui action, bridge JSON contract, manifest schema, tabs, or resume behavior changes.
---

# Review Box

A Review Box promotes one GitHub pull request into one Herdr workspace. ghui sends the selected pull request to `review-box`; the bridge revalidates it with one read-only `gh pr view`, resolves the configured repository root, and delegates workspace creation or recovery to pi-herdr.

The workspace contains **Hunk**, **Critique**, **OMP Review**, and **Approve** tabs. Repeating promotion resumes the existing workspace. A changed head SHA refreshes it; a missing workspace or worktree is restored from the surviving state.

## Invoke the bridge

The installed configuration maps `edmundmiller/dotfiles` to `/Users/emiller/.config/dotfiles`. This command promotes or resumes PR #216:

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

```sh
pkg-check ghui
pkg-check review-box
hey check
```

After `hey re`, `~/.config/ghui/config.json` must contain an executable `reviewBoxCommand`, and `~/.config/review-box/config.json` must contain the repository mapping used above.
