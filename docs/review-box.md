---
purpose: Record the retired legacy Review Box bridge and its source contract.
applies_to: Maintaining retained legacy sources, not native Herdr operation.
entrypoint: Use config/herdr/README.md for native herdr-app and hc workflows.
verification: Run the retained Pi package tests and native Herdr checks.
update_when: Native review routing or the retained legacy source contract changes.
---

# Review Box

The legacy Review Box is no longer packaged or installed by Nix. Git's ghui
configuration no longer supplies a Review Box command or repository mapping.
Native Herdr uses `herdr-app` and `hc`, not the old TUI workspace protocol.
Use `herdr-dev open /path/to/checkout` for an existing checkout and Hunk tab.
It selects `$DEFAULT_CODING_AGENT`, with Pi as the fallback. MacTraitor-Pro
defaults to Amp and Seqeratop to Pi. An explicit `--agent` overrides that choice.

The remaining sections describe retained legacy source behavior, not an
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

## Source verification

```sh
cd packages/pi-packages
bun test pi-herdr/extensions pi-review-box/test
```

Nix does not expose a `review-box` package or install this command. Native hosts
also filter the legacy Pi packages. See [Herdr](../config/herdr/README.md) for
native configuration and verification.
