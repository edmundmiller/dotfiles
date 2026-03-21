# pi-bash-live-view

When agents emit tool calls calls for build systems, those calls can take a long time.
Often they have really nice visualizations of progress.
I cannot see those in pi, making me blind to what is happening.

This extension provides a PTY-backed live terminal tool as `bash_live_view` (plus `/bash-pty` command) for conflict-free use alongside other `bash` wrappers.

[![Demo](assets/demo.gif)](https://github.com/lucasmeijer/pi-bash-live-view/releases/download/readme-assets/Screen.Recording.2026-03-20.at.22.27.36.web.mp4)

_Open the full demo video:_
https://github.com/lucasmeijer/pi-bash-live-view/releases/download/readme-assets/Screen.Recording.2026-03-20.at.22.27.36.web.mp4

## Install

```bash
pi install npm:pi-bash-live-view
```

## Local vendor notes (dotfiles)

This copy is vendored in `~/.config/dotfiles/pi-packages/pi-bash-live-view` until upstream catches up.

Local patches applied:

- Registers tool name `bash_live_view` (instead of `bash`) to avoid conflict with `pi-non-interactive`.
- Accepts optional abort signals in PTY execution path (`AbortSignal | undefined`) and normalizes internally.

Upstream tracker: see `config/pi/settings.jsonc` FIXME comment.
