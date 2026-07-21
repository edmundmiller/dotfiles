---
purpose: Describe the repo-managed Herdr development-layout plugin.
applies_to: Installing, invoking, or changing dotfiles.dev-layout.
entrypoint: Read herdr-plugin.toml, then dev_layout.py.
verification: Run dev_layout_test.py and exercise a disposable worktree layout in Herdr.
update_when: Plugin actions, events, agent startup, or layout behavior changes.
---

# Dotfiles Dev Layout

Herdr plugin for my dotfiles workspace layout.

## Install

```bash
herdr plugin install edmundmiller/dotfiles/packages/herdr-plugins/dotfiles-dev-layout
```

## Entrypoints

- Action: `dotfiles.dev-layout.bootstrap`
- Action: `dotfiles.dev-layout.hunk-split`
- Action: `dotfiles.dev-layout.hunk-tab`
- Event: `worktree.created`

The bootstrap creates a tab for the configured coding agent and starts it through Herdr's semantic `agent start --kind ... --pane ...` facade. Hunk, Neovim, and shell tabs remain ordinary pane processes.

## Requirements

- Herdr `0.7.5` or newer
- `python3`
- Optional: `pi`, `hunk` or `bunx hunkdiff`, `nvim`
