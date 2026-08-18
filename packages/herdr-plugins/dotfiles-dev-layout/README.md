---
purpose: Document the local Herdr checkout-layout plugin.
applies_to: Changes to OMP/Hunk tab bootstrap or Hunk actions.
entrypoint: Edit dev_layout.py and herdr-plugin.toml.
verification: Run python3 -m unittest dev_layout_test.py.
update_when: Plugin actions, events, layout, or requirements change.
---

# Dotfiles Dev Layout

Creates OMP, and Hunk for Git checkout workspaces, when the bootstrap action is
run explicitly. New workspaces get no tabs automatically.
Review Box workspaces skip the generic tabs so the Review Box launcher can own
its Hunk, Critique, agent, and approval layout. The plugin detects Review
Boxes from the hook context (`HERDR_PLUGIN_CONTEXT_JSON`): a `workspace_label`
prefixed with `PR #` or a `workspace_cwd` / `worktree.checkout_path` beneath
`/.pi/worktrees/`. The `HERDR_REVIEW_BOX=1` environment variable is kept as a
belt-and-suspenders fallback, but herdr 0.8.0 does not propagate `workspace
create --env` to plugin hooks, so the context-based signals are the primary
detection mechanism.

## Install

```bash
herdr plugin install edmundmiller/dotfiles/packages/herdr-plugins/dotfiles-dev-layout
```

## Entrypoints

- Action: `dotfiles.dev-layout.bootstrap`
- Action: `dotfiles.dev-layout.hunk-split`
- Action: `dotfiles.dev-layout.hunk-tab`
- Prelaunch: optional repo-local QMD index seeding before Codex starts

No creation events are registered, so ordinary new workspaces stay plain. Run
`dotfiles.dev-layout.bootstrap` to set up OMP and Hunk on demand. The Review Box
builds its own Hunk, Critique, and agent tabs, so it needs nothing from here.

## Requirements

- Herdr `0.7.0` or newer
- `python3`
- Required: `omp`, plus `hunk` or `bunx hunkdiff`
