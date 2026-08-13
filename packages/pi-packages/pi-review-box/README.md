# pi-review-box

Thin CLI adapter bridging ghui PR JSON to pi-herdr's shared `openReviewBox`
decision flow.

## Purpose

The `review-box` bridge receives a PR JSON object on stdin (from ghui's
"Promote/resume Review Box" action), revalidates the PR via one read-only
`gh pr view` call, and delegates to pi-herdr's shared
`openReviewBox` flow — which owns the per-PR manifest, lockfile, worktree,
Herdr workspace, tabs, and focus.

The bridge does **not** own a manifest or reimplement decision logic. All
state lives in pi-herdr's per-PR manifest
(`$XDG_STATE_HOME/pi-herdr/review-boxes/<owner>-<repo>-pr-<n>.json`).

## Usage

```sh
echo '{"repository":"owner/repo","number":42,"headRefOid":"abc...","headRefName":"branch","title":"Title","url":"https://github.com/owner/repo/pull/42"}' | review-box
```

### Subcommands

- `review-box` (default) — promote or resume a Review Box
- `review-box prune` — remove manifest files whose workspace AND worktree
  are both gone
- `review-box --help` / `review-box -h` — print usage

### Exit codes

| Code | Meaning                                                          |
| ---- | ---------------------------------------------------------------- |
| 0    | success (created/resumed/restored/refreshed)                     |
| 2    | input/usage error                                                |
| 3    | PR is closed or merged                                           |
| 4    | gh failure (non-zero exit, timeout, missing fields)              |
| 5    | repo-root config class failure (unmapped repo, malformed config) |
| 6    | herdr/git runtime failure or timeout                             |

### Config

Config discovery uses `XDG_CONFIG_HOME` (fallback `~/.config`), file
`review-box/config.json`. The config maps repository names to repo root
paths:

```json
{ "edmundmiller/dotfiles": "/Users/emiller/.config/dotfiles" }
```

`REVIEW_BOX_REPO_ROOT` environment variable is **not** honored (R7).
