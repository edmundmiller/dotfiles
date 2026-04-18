# Managing agents in tmux

Status: Draft 2
Audience: human operators and coding agents working in this dotfiles repo

## Why this doc exists

The old flow overfit to a specific tool stack (Hermes + Hunk) and a specific phrase ("cockpit").

The durable need is simpler:

- keep tmux session identity at the repo level
- launch new focused windows for branch/task work
- optionally include review sidecars
- keep naming/tooling flexible

## Recommended user-facing term

Use: "new work window"

Why:

- neutral across Hermes/pi/opencode/claude
- neutral across sidecars (Hunk/critique/lazygit/none)
- describes behavior instead of implementation details

If we later pick a better name, keep this as the fallback concept.

## User model (what to expect)

1. Session identity is repo-level

- Example session: `dotfiles`
- Not: one session per worktree slug

2. Window identity is task/branch-level

- Example window: `test`
- Not: `dotfiles-test-cockpit`

3. Worktree is implementation detail for isolation

- You can still create sibling worktrees
- But top-level tmux navigation should stay repo-first

4. Layout is role-based

- main work pane (agent/editor/shell)
- optional review sidecar pane
- optional opensessions sidebar

## Layered architecture

### Layer 0: Identity resolution (invariants)

Purpose: normalize paths and naming.

Owned by:

- `bin/git-worktree-cwd`
- `bin/tmux-project-root`
- `bin/tmux-project-name`
- `bin/tmux-lib.sh`

Contract:

- deterministic naming
- no UI-specific behavior

### Layer 1: Lifecycle primitives (boring core)

Purpose: create/switch/remove repo/worktree state.

Owned by:

- `bin/tmproj` (attach/create canonical session)
- `bin/tw` (create sibling worktree)
- `bin/twd` (remove sibling worktree + cleanup)

Contract:

- small and composable
- no tool-specific pane logic

### Layer 2: Work-window launcher (composed behavior)

Purpose: launch a new task/branch window in the repo session and apply a layout.

Inputs should be:

- `name` (task/branch label)
- tool command (hermes/pi/opencode/...)
- optional sidecar command
- layout preset

Contract:

- session target should come from repo root (`checkout_root`)
- window target should come from requested branch/task label
- no identity leakage from worktree path into session naming

### Layer 3: UX surfaces

Purpose: discoverability and shortcuts.

Owned by:

- tmux keybinds (`config/tmux/config`)
- tmux-which-key (`config/tmux/which-key.yaml`)
- aliases (`config/tmux/aliases.zsh`, `config/tmux/omarchy.zsh`)
- opensessions menus

Contract:

- call shared backend/launcher code
- avoid duplicating lifecycle logic
- aliases are accelerators, not source of truth

## Naming and behavior rules

1. Repo session stays stable

- launcher should switch/create `dotfiles`-style session from repo root

2. New window name uses branch/task label

- launcher prompt should ask for a branch/task window name
- sanitize labels, but keep user intent (`test`, `bugfix-auth`, etc.)

3. Tool-specific words should be second-order

- avoid top-level names like "Hermes/Hunk cockpit"
- keep tool details in profile/config, not concept label

## What this means for current flow

Current keybinds and scripts can stay, but behavior should be:

- `prefix + Z` (or menu equivalent) => prompt for branch/task label
- create sibling worktree if needed
- target repo-level tmux session
- open a window named after requested label
- apply layout with main work pane + optional sidecar(s)

## Success criteria

This model is working when:

- tmux session list is repo-oriented and stable
- windows communicate current branch/task intent clearly
- changing agent tool does not require changing session identity logic
- docs and runtime behavior stay in sync

## Related docs

- `docs/ade/tmux-ade-spec.md`
- `modules/shell/tmux/README.md`
- `config/tmux/config`
- `config/tmux/which-key.yaml`
