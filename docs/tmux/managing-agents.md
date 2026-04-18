# Managing agents in tmux

Status: Draft 1
Audience: human operators and coding agents working in this dotfiles repo

## Why this doc exists

The tmux workflow has grown powerful but easy to overfit to whatever tool is hot this week.

Right now that toolchain is often Hermes + Hunk, but the long-term need is broader:

- launch any agent quickly
- in the right project/worktree session
- with optional review sidecars (Hunk, critique, lazygit, none)
- without memorizing fragile aliases

This doc lays out the user-facing model and the clean architecture layers behind it.

## User-first workflow (what people actually want)

Most requests boil down to one of these intents:

1. "Take me to this project/worktree"

- Use: `tmproj` (alias `tp`)
- Behavior: attach/create canonical session for current path

2. "Create a new worktree and start working"

- Use: `tw <name>`
- Behavior: create sibling worktree + enter canonical session

3. "Delete a finished worktree cleanly"

- Use: `twd <name-or-path>`
- Behavior: remove worktree + kill matching tmux session

4. "Launch an agent workspace here"

- Use: launcher profile (currently via tmux keybinds and aliases)
- Behavior: start agent pane(s) and optional sidecars in current canonical session

5. "Review changes while coding"

- Use persistent right-pane review (`]`, `}`, `{`) or profile layout
- Behavior: keep review context visible (unstaged/staged/branch-committed)

The key UX rule: users should choose intent, not remember internals.

## Mental model

Think in this order:

1. Workspace identity

- Which repo/worktree am I in?

2. Session identity

- Which canonical tmux session maps to that workspace?

3. Window role

- Is this a project shell window, an agent window, or review window?

4. Pane role

- Agent pane, review sidecar, shell/editor helper

5. Tool choice

- Hermes/pi/opencode/claude for agent
- Hunk/critique/lazygit/none for review

If these are separated, the system stays composable.

## Clean architecture layers

### Layer 0: Identity resolution (no UI, no agent assumptions)

Owns path/session naming invariants.

Key scripts:

- `bin/git-worktree-cwd`
- `bin/tmux-project-root`
- `bin/tmux-project-name`
- `bin/tmux-lib.sh`

Contract:

- given any path, resolve a usable checkout
- derive deterministic tmux-safe names
- avoid duplicate naming logic elsewhere

### Layer 1: Workspace lifecycle primitives

Owns create/switch/remove session and worktree behavior.

Key commands:

- `bin/tmproj`
- `bin/tw`
- `bin/twd`

Contract:

- boring and deterministic
- no opinionated pane layout decisions
- callable from humans, tmux scripts, opensessions, and agents

### Layer 2: Agent launch orchestration (generic)

Owns layout composition and command wiring.

Current state:

- includes tool-specific launcher (`worktree-hermes-hunk.sh`)

Target state:

- generic launcher abstraction (for example `worktree-agent-launch.sh`) that accepts:
  - workspace mode (`current` or `new-worktree`)
  - worktree name (optional)
  - agent command (`hermes`, `pi`, `opencode`, etc.)
  - review sidecar command (`hunk`, `critique`, `lazygit`, `none`)
  - layout preset (`single`, `tml`, `cockpit`)

Contract:

- composes Layer 0 + Layer 1, does not replace them
- one implementation path for all UI entry points

### Layer 3: UX surfaces (discoverability + shortcuts)

Owns how users trigger workflows.

Surfaces:

- tmux keybinds in `config/tmux/config`
- tmux-which-key menu in `config/tmux/which-key.yaml`
- shell aliases/functions in `config/tmux/aliases.zsh` and `config/tmux/omarchy.zsh`
- opensessions navigation

Contract:

- never duplicate lifecycle logic
- call backend primitives and launch orchestration
- aliases are accelerators, not source of truth

## How to think about `nic` and friends

`nic`, `nicx`, `nicc`, etc. should be treated as profile shortcuts, not architectural primitives.

Good framing:

- `nic` = profile: `agent=pi`, `review=lazygit`, `layout=tml`
- `nicx` = profile: `agent=opencode`, `review=lazygit`, `layout=tml`
- `nicc` = profile: `agent=pi`, `review=critique`, `layout=tmlc`

This keeps muscle memory while letting backend behavior evolve safely.

## Current tool-specific flow and how it should evolve

Current:

- `prefix + Z` launches a new worktree cockpit wired to Hermes + Hunk.

Desired evolution:

- keep `Z` as "agent launch" concept
- tool-specific behavior comes from a selected/default profile
- keep compatibility wrappers so existing habits do not break

Practical migration path:

1. Add generic launcher script
2. Keep `worktree-hermes-hunk.sh` as wrapper profile
3. Rename user-visible labels from "Hermes + Hunk" to "Agent cockpit"
4. Move more aliases/binds onto generic launcher profiles
5. Keep `tmproj/tw/twd` unchanged as stable primitives

## User-facing command model (recommended)

Primary mental split:

- choose/switch workspace
- launch work style in that workspace

### Choose/switch workspace

- `tp` / `tmproj`
- `tw <name>`
- `twd <name-or-path>`
- opensessions picker

### Launch work style

- agent profile (single pane, tml, cockpit)
- optional persistent review sidecar (`]`, `}`, `{`)

Avoid combining everything into one opaque alias unless it is a profile wrapper.

## Hunk integration expectations

For sustained review, keep Hunk in a persistent pane and support:

- unstaged diff
- staged diff
- committed-on-branch diff

For agent behavior, default expectation is proactive read/review support, not only reactive interaction:

- read code from current context
- use review surface where available
- produce comments with clear scope (unstaged/staged/committed)

## Design guardrails

1. One canonical implementation per concern

- naming logic once
- lifecycle logic once
- launch orchestration once

2. Discoverability over alias memorization

- every canonical flow should be reachable from tmux UI surfaces

3. Backward-compatible wrappers

- old aliases can stay while internals converge

4. Role-based naming

- prefer labels like "agent launch" / "review sidecar" over specific tool names in top-level UX

5. Keep "boring core" stable

- `tmproj`, `tw`, `twd` should stay small and predictable

## Success criteria

This architecture is working when:

- users can explain the workflow in terms of intent, not script names
- swapping Hermes to another agent does not require rewriting lifecycle logic
- keybinds and aliases call shared launch primitives instead of custom forks
- agent + review layouts remain persistent and predictable
- docs match runtime behavior closely

## Related docs

- `docs/ade/tmux-ade-spec.md`
- `modules/shell/tmux/README.md`
- `config/tmux/config`
- `config/tmux/which-key.yaml`
