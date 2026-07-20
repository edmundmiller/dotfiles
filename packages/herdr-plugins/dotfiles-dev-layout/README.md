---
purpose: Document the local Herdr checkout-layout plugin.
applies_to: Changes to OMP/Hunk tab bootstrap or Hunk actions.
entrypoint: Edit dev_layout.py and herdr-plugin.toml.
verification: Run python3 -m unittest dev_layout_test.py.
update_when: Plugin actions, events, layout, or requirements change.
---

# Dotfiles Dev Layout

Creates an idempotent two-tab task workspace: OMP and Hunk, with OMP focused.

## Install

```bash
herdr plugin install edmundmiller/dotfiles/packages/herdr-plugins/dotfiles-dev-layout
```

## Entrypoints

- Action: `dotfiles.dev-layout.bootstrap`
- Action: `dotfiles.dev-layout.hunk-split`
- Action: `dotfiles.dev-layout.hunk-tab`
- Events: `workspace_created` and `worktree_created`

## Requirements

- Herdr `0.7.0` or newer
- `python3`
- Required: `omp`, plus `hunk` or `bunx hunkdiff`
