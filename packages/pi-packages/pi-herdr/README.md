---
purpose: Operate and verify the Pi/OMP integration for Herdr workspaces and PR Review Boxes.
applies_to: Changes to the pi-herdr extension, Review Box lifecycle, or runtime packaging.
entrypoint: Run `/review-box <pr-number|url|branch>` from Pi or OMP.
verification: Run the focused Bun test, typecheck, and Pi RPC command-discovery smoke test.
update_when: Review Box tabs, persistence, commands, or runtime package wiring changes.
---

# pi-herdr

Pi package that adds Herdr tools for inspecting and controlling a running Herdr server from Pi.

## Tools

- `herdr_status` — check Herdr client/server/socket status.
- `herdr_list` — list workspaces, tabs, or panes.
- `herdr_read_pane` — read visible or recent pane output.
- `herdr_run_in_pane` — send a command to a pane and press Enter.
- `herdr_wait` — wait for output match or agent status transition.
- `herdr_pr_review_workspace` — create or resume an isolated Review Box for a GitHub PR.

## Command

- `/herdr ...` — run a Herdr CLI command, for example `/herdr pane list`.
- `/review-box <pr>` — create or resume one PR-keyed Herdr workspace.
- `/review-box <pr> --agent pi` — use Pi instead of the default OMP review tab.

The Review Box contains Hunk, Critique, agent-review, and manual approval tabs.
Its manifest lives under `$XDG_STATE_HOME/pi-herdr/review-boxes` (or
`~/.local/state/pi-herdr/review-boxes`). Repeating the command focuses the
existing workspace. A new PR head refreshes the checkout and rebuilds its tabs.
The approval tab only prints `gh pr review` commands; it never submits a review.

## Install locally

```bash
pi install /Users/emiller/.config/dotfiles/packages/pi-packages/pi-herdr
```

Or add the package path to Pi settings.

## Requirements

- `herdr` on `PATH`.
- A running compatible Herdr server (`herdr status`).
