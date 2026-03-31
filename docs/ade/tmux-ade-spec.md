# Tmux-First ADE Spec

Status: Draft 1

## Summary

This document defines the first spec for a **tmux-centered Agentic Development
Environment (ADE)** for this dotfiles repo.

The core idea is simple:

> tmux should act as the primary interaction layer where humans, agents,
> projects, worktrees, and task context meet.

This repo already has many of the raw ingredients:

- tmux as the daily driver multiplexer
- `sesh` / `opensessions` session navigation
- custom tmux layouts (`tml`, `nic`, `nicx`, `nicc`, etc.)
- Ghostty integration
- AI tool launchers living inside tmux panes
- worktree-aware helper logic

What is missing is a single written model that says what the system is trying to
be.

This spec is meant to provide that model so both **humans and agents** can make
changes that converge instead of drift.

---

## Problem Statement

The current tmux workflow is powerful, but it has grown from multiple good local
optimizations:

- session switching via `sesh`
- project sidebars via `opensessions`
- agent-centric layouts via `tml`/`nic`
- ad hoc aliases like `tm`, `t`, and popup bindings

That gives a lot of capability, but not always a clear mental model.

The main risks are:

1. **Too many entry points** for similar intents
2. **Implicit conventions** that live in chat or memory instead of docs
3. **Workflow drift** between what humans expect and what agents automate
4. **Weak coupling between worktrees, sessions, and task state**
5. **Uneven parity** between local and remote tmux workflows

The goal of this spec is to define a clean target state.

---

## Vision

The ADE should make the following flow feel natural:

1. Pick a project or worktree
2. Enter the canonical tmux session for it
3. Land in a predictable layout
4. See enough context to know what is happening
5. Launch or resume human/agent work without ceremony
6. Preserve enough structure that another human or agent can continue later

In short:

> **one project/worktree, one session, low-friction entry, visible state**

---

## Design Principles

### 1. Tmux is the control plane

Tmux is not just a terminal multiplexer here. It is the shared operating surface
for development sessions.

### 2. One project or worktree should map to one canonical session

Humans and agents should not need to invent session names on the fly. Session
identity should come from the repo/worktree whenever possible.

### 3. Attach-or-create should be the default behavior

The common path should be:

- if the session exists, attach or switch to it
- if it does not exist, create it with the right cwd/layout

### 4. Layouts should express roles, not just panes

Panes should represent roles like:

- agent
- editor
- git review
- shell
- logs

### 5. Hidden magic should be minimized

Automation is good, but it should remain inspectable and debuggable. A human or
agent should be able to read the config and understand why a session behaves the
way it does.

### 6. Local and remote workflows should rhyme

Remote tmux usage should mirror local tmux usage closely enough that context
switching is cheap.

### 7. Human-agent handoff should be first-class

A good session should make it obvious:

- what project it belongs to
- what worktree/branch it belongs to
- what tool or agent is active
- where the user should continue

---

## Audience

This spec is for four actors:

### Human operator

The primary user working interactively in Ghostty/tmux.

### Foreground coding agent

An agent running in an interactive pane or overlay that needs predictable session
structure.

### Background or helper agent

An agent that may create worktrees, update files, or coordinate tasks without
being the currently focused pane.

### Future maintainer

A human or agent trying to understand why the tmux workflow is shaped the way it
is.

---

## Current Building Blocks in This Repo

These are the main existing implementation touchpoints.

### Tmux configuration

- `config/tmux/config`
- `modules/shell/tmux/default.nix`

These define keybindings, popup behavior, plugin wiring, Ghostty integration,
and Nix-managed tmux setup.

### Session selection

- `config/tmux/sesh-picker.sh`
- `config/tmux/sesh-all.sh`
- `config/tmux/zoxide-list.sh`

These provide the current session picker and source aggregation for tmux
sessions, configured sessions, and zoxide entries.

### Project layouts

- `config/tmux/omarchy.zsh`

This contains layout-oriented commands like:

- `tml`
- `tmlm`
- `nic`
- `nicx`
- `nicc`
- `niccx`

### Shell entrypoints

- `config/tmux/aliases.zsh`

This currently defines `t`, `tm`, `ta`, `tl`, and related helpers, but those
names are not all stable from the user's interactive shell perspective:

- `t` is later re-aliased to `todo.sh` in `config/zsh/.zshrc`
- `tm` is currently a special-purpose `termius` / Obsidian / Pi launcher, not a
  generic current-project attach/create helper

### Dynamic layout management

- `config/tmux/toggle-tml.sh`

Toggles the `tml` layout on/off from a keybinding (`prefix T`). Creates the
three-pane layout when only one pane exists, tears down extras when multiple
panes exist.

### Window naming hooks

- `config/zsh/tmux-hooks.zsh`

This hook file exists and appears intended to fire `$TMUX_WINDOW_NAME_SCRIPT`
on every `chpwd`, keeping window names in sync with the working directory.

However, current code review suggests it is **not obviously auto-sourced** by
the generic zsh module loader. Treat this as an intended integration point that
should be explicitly wired or documented before the ADE relies on it.

### Theme and appearance

- `config/tmux/theme.conf`
- `config/tmux/theme-dark.conf`
- `config/tmux/theme-light.conf`

Auto dark/light mode via `tmux-dark-notify`. These control the "visible state"
layer that surfaces session context.

### Critique layouts

- `tmlc` / `nicc` / `niccx` in `config/tmux/omarchy.zsh`

Variant of `tml` that replaces lazygit with split critique panes (unstaged +
staged). Relevant to the review-oriented layout preset and best understood as
the sustained-review counterpart to the popup critique bindings in
`config/tmux/config`.

### Adjacent project/session tooling

- `packages/dmux/`
- `packages/opensessions/`
- tmux smart naming and status integrations loaded from `modules/shell/tmux`

---

## Current Gaps

### 1. Session entry is not yet canonical

The repo has multiple strong ways to enter tmux, but not one documented default
for:

- current project
- current worktree
- remote target

### 2. Worktree lifecycle is not yet a first-class tmux concept

There is worktree awareness, but not yet a clearly documented contract like:

- create worktree
- create matching session
- clean both up together

### 3. Session roles are implicit

Layouts like `tml` are useful, but the repo does not yet have a written concept
of role-based pane layouts as part of the ADE.

### 4. Human-agent alignment is partially accidental

Some pieces are agent-aware, but there is no top-level spec that says what
agents should assume about sessions, naming, or discoverability.

### 5. Some task/issue integration still reflects older tooling

The repo has migrated from `bd` to `br`, but parts of the tmux integration still
reference older `bd`-named helpers. That should be treated as follow-up work as
the ADE is tightened.

---

## Known Mismatches with Current Implementation

This section exists to keep the spec honest. These are not objections to the ADE
direction; they are places where the intended model and current implementation
still diverge.

### 1. `t` is not currently a reliable tmux entrypoint

`config/tmux/aliases.zsh` defines `t` as a tmux attach/create shortcut, but
`config/zsh/.zshrc` later redefines `t` for `todo.sh`.

That means the spec should not talk about `t` as if it is currently the user's
canonical tmux entry command.

### 2. `tm` is not generic project-session entry

`tm` currently launches a specific `termius` session rooted in
`~/obsidian-vault`, defaulting to `pi; zsh`.

That makes it a useful workflow-specific launcher, but not a drop-in synonym for
the future `tmproj` concept.

### 3. Window naming hook wiring is unclear

`config/zsh/tmux-hooks.zsh` exists, but it is not yet clearly sourced by the
normal zsh module path loading. The spec should treat automatic `chpwd` window
renaming as an intended integration, not a guaranteed current behavior.

### 4. Tmux popups still reference older `bd` helpers

At time of writing, the tmux popup bindings still call commands like:

- `bd-capture`
- `bd-find-all`

The repo-level task system has already moved to `br`, so this should remain an
explicit migration item rather than a vague future cleanup.

---

## Target State

The tmux ADE should provide the following capabilities.

## 1. Canonical project session identity

Each project or worktree should have a deterministic session identity derived
from the working directory or worktree root.

Properties:

- stable
- shell-friendly
- tmux-safe
- predictable to both humans and agents

Examples:

- repo basename
- worktree basename
- optional namespace for remote hosts when needed

Currently session naming is computed in at least three different ways:

- `basename "$PWD"` in `omarchy.zsh`
- `#{pane_current_path}` + `git-worktree-cwd` in `toggle-tml.sh`
- hardcoded `"Work"` in `aliases.zsh` (`t` alias)

The implemented naming contract is now:

- `bin/tmux-project-root <path>` first normalizes with `bin/git-worktree-cwd`
- if the normalized path is inside a git worktree, it resolves to that
  checkout's top-level directory
- otherwise the normalized path itself is used
- `bin/tmux-project-name <path>` takes the basename of that resolved path and
  sanitizes it to a tmux-safe `[A-Za-z0-9_-]`-style name by collapsing other
  characters to `-`

Examples:

- `/src/dotfiles` → `dotfiles`
- `/src/dotfiles-pc4` → `dotfiles-pc4`
- bare worktree hub root → resolves to its usable checkout first, then names
  that checkout

This keeps naming boring: main checkouts use the repo basename, and named
worktrees keep their distinct basename when it differs.

## 2. A zero-friction session entry command

There should be one preferred helper for:

- current directory → canonical session

Behavior:

- attach if session exists
- create if session does not exist
- use the correct cwd
- optionally seed a default layout

This can coexist with more specialized entrypoints, but there should be a clearly
documented default.

## 3. Layout presets with role semantics

The ADE should support a small set of role-oriented layouts, such as:

- **project** — shell-first general development session
- **agent** — agent pane + git/review pane + shell pane
- **editor** — editor-first startup
- **review** — critique/lazygit-focused layout

The point is not just pane geometry. The point is predictable intent.

## 3a. Popups as a distinct UI primitive

The tmux config already uses ~15 popup bindings for transient, focused
interactions: critique, beads capture, daily notes, file picking, git TUI, and
session config editing.

Popups and persistent panes serve different roles:

- **Persistent panes** — continuous context that stays visible (agent, editor,
  git sidebar, shell)
- **Transient popups** — focused interruptions that dismiss on completion
  (capture, file picking, session switching)

Future layout and agent work should respect this distinction. Agents and scripts
should not open persistent panes for transient tasks, and should not use popups
for context that needs to remain visible.

## 3b. Quick review vs sustained review

The current tmux UX already suggests two review modes, and the ADE should make
that distinction explicit:

- **Quick review** — use popup critique bindings for fast, interruptible diff
  inspection
- **Sustained review** — use `tmlc` / `nicc` / `niccx` when review context
  should stay visible alongside an agent or shell

This keeps the popup-vs-pane model practical instead of purely conceptual.

## 4. Session picker as a secondary, not primary, entrypoint

The picker remains valuable, but the normal path should be direct entry into the
current project session. The picker should remain excellent for:

- switching
- discovery
- recovery
- remote work

`opensessions` does not necessarily disappear in this model. It may remain the
visual sidebar / dashboard / project-config layer while `tmproj` and `sesh`
handle the direct attach-or-create path.

## 5. Worktree-aware lifecycle commands

The ADE should eventually support commands in the spirit of:

- create worktree + matching session
- remove worktree + matching session
- list project worktrees as session candidates

This is one of the highest-leverage additions because it ties source isolation
and workspace isolation together.

## 6. Remote parity

Remote machines should expose a similar model:

- attach/create named session remotely
- choose remote sessions predictably
- preserve project naming conventions where practical

## 7. Session-visible context

A session should help answer questions like:

- What project is this?
- What branch/worktree is this?
- What agent/tool is active?
- What layout am I in?

This does not need to be noisy. It just needs to be discoverable.

## 8. Task-awareness without hard coupling

Tmux should integrate cleanly with task tooling like `br`, but tmux should not be
so tightly coupled that session management breaks when task tooling evolves.

That means:

- launchers and popups should be swappable
- naming should not depend on one tracker implementation
- task capture should feel native but remain optional

Concrete migration backlog items include replacing or renaming popup helpers
that still expose `bd`-era command names.

---

## Proposed Command Model

This section is not a final command commitment. It is the shape the workflow
should likely converge toward.

### Primary commands

- `tmproj` — attach/create canonical session for current project/worktree
- `tv` — attach/create canonical project session, starting in `nvim` if new
- `tp` or existing picker — fuzzy switcher across session sources

### Deprecation path

Once `tmproj` is stable, legacy aliases should converge:

- `t` should only become an alias for `tmproj` after resolving its current
  collision with `todo.sh` aliases in `config/zsh/.zshrc`
- `tm` should be split into either:
  - a clearly named replacement for the current `termius` / Obsidian / Pi flow
  - and a generic `tmproj`,
  - or removed if that special-purpose workflow is no longer needed
- `ta` can remain as a raw `tmux attach` escape hatch

The goal is to reduce entry points, not add more. New commands must come with a
plan to retire the old ones they supersede.

### Layout commands

- `tml` — agent + git + shell layout
- `nic` / `nicx` / `nicc` — opinionated AI variants

### Lifecycle commands

- `tw <name>` — create worktree + session
- `twd <name>` — destroy worktree + session

### Remote commands

- `tms` — remote session picker / attach-create helper

The point is to separate:

- **enter the workspace**
- **choose the layout**
- **manage lifecycle**

instead of forcing a single command to do all three every time.

---

## Implementation Priorities

### Phase 1 — document and normalize

Goal: define the contract before expanding automation.

Tasks:

- create ADE docs
- document tmux as control plane
- define canonical session model
- identify command overlap and unclear entrypoints

### Phase 2 — canonical session entry

Goal: add one preferred current-project attach/create helper.

Likely touchpoints:

- `config/tmux/aliases.zsh`
- `config/tmux/omarchy.zsh`
- possibly `config/tmux/sesh-picker.sh`

### Phase 3 — worktree lifecycle

Goal: make worktree creation/removal align with session creation/removal.

Likely touchpoints:

- shell helpers under `config/tmux/`
- existing git/worktree helper scripts under `bin/`
- maybe `packages/dmux/` or adjacent custom tooling

### Phase 4 — remote parity

Goal: make remote session management feel like a natural extension of the local
model.

### Phase 5 — richer session metadata

Goal: expose more state in titles, smart naming, status line, or pickers without
turning tmux into a dashboard gimmick.

---

## Success Criteria

The tmux-first ADE is moving in the right direction if the following become true:

1. A human can explain the default tmux workflow in a few sentences
2. An agent can infer where to launch or resume work from repo docs alone
3. Project/worktree session entry becomes near-zero-friction
4. Worktree and session sprawl decrease rather than increase
5. Remote work feels like the same system, not a separate one
6. Session naming becomes boring and predictable

---

## Non-Goals

For now, this spec is **not** trying to do the following:

- replace every existing tmux helper immediately
- standardize every editor workflow
- invent a full distributed agent orchestration layer inside tmux
- force every workflow through one mega-command
- turn tmux into the only source of truth for task state

---

## Open Questions

These should guide future changes.

1. The current implementation uses a simple hybrid already: resolve the usable
   checkout root, then use that basename. This keeps main repos short while
   preserving distinct worktree names such as `dotfiles-pc4`.
2. Should the default attach/create helper replace the current `tm`, or should
   `tm` first be split into generic project entry vs. the existing
   `termius`/Obsidian/Pi workflow?
3. Which layout should be the default for a freshly created project session:
   plain shell, editor-first, or agent-first?
4. How much session metadata should be visible in titles/status vs. only in the
   picker?
5. Should remote sessions preserve the exact same names as local sessions, or
   include a host prefix?
6. How tightly should `br` capture/explore workflows be embedded in tmux popups?
7. What is the future role of `opensessions` if `tmproj` + `sesh` handle direct
   session entry? Does it remain the visual dashboard/sidebar layer?
8. How will `sesh` discover newly created worktrees that are not yet in zoxide's
   history?
9. What role does `dmux` play in this model? Is it a complementary session
   manager or a competing one that should be reconciled?

---

## Immediate Follow-Up Ideas

Good next implementation candidates after this spec:

1. Add a `tmproj` helper for current-project attach/create
2. Add a `tv` helper for editor-first project entry
3. Add `tw` / `twd` for worktree + session lifecycle
4. Update tmux task popups and helper names to fully reflect the `br` migration
5. Resolve the `t` alias collision before making a new canonical entrypoint
6. Either wire `config/zsh/tmux-hooks.zsh` explicitly or document why it should
   remain optional
7. Make picker cancellation fall back to the current project's canonical session

---

## Change Log

- Draft 0: initial written spec for a tmux-centered ADE, based on the current
  repo workflow and intended human/agent alignment goals
- Draft 1: tightened the spec against current implementation reality, including
  alias collisions, `tm`'s special-purpose behavior, popup-vs-pane review modes,
  window-hook wiring ambiguity, and concrete `bd` → `br` migration leftovers
- Draft 2: documented the canonical tmux project naming contract implemented by
  `bin/tmux-project-root` and `bin/tmux-project-name`, including worktree-aware
  basename preservation and tmux-safe sanitization
