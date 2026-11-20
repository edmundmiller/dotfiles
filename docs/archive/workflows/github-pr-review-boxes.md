---
purpose: Preserve the retired Review Box workflow and state locations.
applies_to: Historical inspection and recovery of existing Review Boxes.
entrypoint: Use docs/github-pr-cli-tools.md for supported review tools.
verification: Historical record only; its packages and commands are retired.
update_when: Recovery evidence needs clarification.
---

# GitHub PR review workflow

Historical only. The legacy Herdr integration and `/review-box` are removed.
Existing worktrees and manifests are preserved, not automatically migrated or deleted.
The instructions below describe the retired implementation, not supported commands.

GitHub is the source of truth for queue and review state. Use GitHub Inbox or
`ghui` to triage PRs across repositories. Promotion is explicit: copy the PR
number or URL into `/review-box` from OMP or Pi.

## Review Box

A Review Box is one Herdr workspace for one repository and pull-request number.
It uses an isolated detached worktree under the repository's shared
`.pi/worktrees` directory and opens these tabs:

- **Hunk** for the primary diff and inline findings.
- **Critique** for an independent visual diff.
- An agent review tab for preparation: `--agent <command>`, else `$DEFAULT_CODING_AGENT`, else Pi.
- **Approve** for visible, human-triggered `gh pr review` commands.

```text
/review-box 4306
/review-box https://github.com/nf-core/tools/pull/4306 --agent pi
```

Repeating the command focuses the existing Review Box. If GitHub reports a new
head SHA, the bridge refreshes the checkout and rebuilds the tabs as a new
review pass. If Herdr lost the workspace but the checkout remains, the command
restores it. Manifests are written atomically under
`$XDG_STATE_HOME/pi-herdr/review-boxes`, falling back to
`~/.local/state/pi-herdr/review-boxes`.

## Queue and submission boundaries

The current working slice uses `ghui` for queue discovery and `/review-box` for
promotion. ghui 0.7.1 does not expose an external-action hook, so focus-sensitive
key automation is intentionally absent.

Only the human submits `COMMENT`, `APPROVE`, or `REQUEST_CHANGES`. The extension
does not create a GitHub pending review, merge, or mutate queue state.

MDR remains the revision-DAG surface for existing Jujutsu workspaces. A Review
Box is a detached Git checkout; initializing Jujutsu there solely to run MDR
would violate repository workflow rules and is not part of this path.

## Verification

```sh
cd packages/pi-packages/pi-herdr
bun test extensions/herdr.test.ts
bun run check
printf '{"type":"get_commands","id":"commands"}\n' |
  timeout 8 pi --mode rpc --no-session --offline --no-extensions --no-skills \
    --no-prompt-templates --extension ./extensions/herdr.ts
```
