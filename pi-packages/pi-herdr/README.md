# pi-herdr

Pi package that adds Herdr tools for inspecting and controlling a running Herdr server from Pi.

## Tools

- `herdr_status` — check Herdr client/server/socket status.
- `herdr_list` — list workspaces, tabs, or panes.
- `herdr_read_pane` — read visible or recent pane output.
- `herdr_run_in_pane` — send a command to a pane and press Enter.
- `herdr_wait` — wait for output match or agent status transition.

## Command

- `/herdr ...` — run a Herdr CLI command, for example `/herdr pane list`.

## Install locally

```bash
pi install /Users/emiller/.config/dotfiles/pi-packages/pi-herdr
```

Or add the package path to Pi settings.

## Requirements

- `herdr` on `PATH`.
- A running compatible Herdr server (`herdr status`).
