# Dotfiles Dev Layout

Herdr plugin for my dotfiles workspace layout.

## Install

```bash
herdr plugin install edmundmiller/dotfiles/config/herdr/plugins/dotfiles-dev-layout
```

## Entrypoints

- Action: `dotfiles.dev-layout.bootstrap`
- Action: `dotfiles.dev-layout.hunk-split`
- Action: `dotfiles.dev-layout.hunk-tab`
- Event: `worktree.created`

## Requirements

- Herdr `0.7.0` or newer
- `python3`
- Optional: `pi`, `hunk` or `bunx hunkdiff`, `nvim`
