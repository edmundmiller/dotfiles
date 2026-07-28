---
purpose: Document the local Herdr checkout-layout plugin.
applies_to: Changes to Codex/Hunk tab bootstrap or Hunk actions.
entrypoint: Edit dev_layout.py and herdr-plugin.toml.
verification: Run python3 -m unittest dev_layout_test.py.
update_when: Plugin actions, events, layout, or requirements change.
---

# Dotfiles Dev Layout

Creates an idempotent two-tab task workspace: Codex and Hunk, with Codex focused.

## Install

```bash
herdr plugin install edmundmiller/dotfiles/packages/herdr-plugins/dotfiles-dev-layout
```

## Entrypoints

- Action: `dotfiles.dev-layout.bootstrap`
- Action: `dotfiles.dev-layout.hunk-split`
- Action: `dotfiles.dev-layout.hunk-tab`
- Events: `workspace.created` and `worktree.created` (serialized per workspace)

## Requirements

- Herdr `0.7.0` or newer
- `python3`
- Required: `codex`, plus `hunk` or `bunx hunkdiff`
