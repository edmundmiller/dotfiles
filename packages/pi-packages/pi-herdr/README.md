---
purpose: Describe the Pi extension that exposes Herdr control and PR-review tools.
applies_to: Installing, using, or changing packages/pi-packages/pi-herdr.
entrypoint: Read extensions/herdr.ts and run its Bun tests.
verification: Run bun test and bun run check in this package.
update_when: Herdr CLI contracts, exposed tools, or PR-review topology changes.
---

# pi-herdr

Pi package that adds Herdr tools for inspecting and controlling a running Herdr server from Pi.

## Tools

- `herdr_status` — check Herdr client/server/socket status.
- `herdr_list` — list workspaces, tabs, or panes.
- `herdr_read_pane` — read visible/recent pane output or route detection-buffer reads through the agent facade.
- `herdr_run_in_pane` — send a command to a pane and press Enter.
- `herdr_wait` — wait through `pane wait-output` or semantic `agent wait`.
- `herdr_pr_review_workspace` — create a review worktree, run Hunk in a pane, start OMP through Herdr's agent facade, and leave review submission manual.

## Command

- `/herdr ...` — run a Herdr CLI command, for example `/herdr pane list`.

## Install locally

```bash
pi install /Users/emiller/.config/dotfiles/packages/pi-packages/pi-herdr
```

Or add the package path to Pi settings.

## Requirements

- `herdr` on `PATH`.
- Herdr 0.7.5 or newer with a running compatible server (`herdr status`).
