# Opensessions-First Tmux ADE Spec

Status: Draft 7

## Summary

This document defines the current spec for an **opensessions-first,
tmux-centered Agentic Development Environment (ADE)** for this dotfiles repo.

The core idea is simple:

> tmux is the shared runtime substrate, and opensessions is the primary
> human-facing control plane where humans, agents, projects, worktrees, and
> task context meet.

This repo already has many of the raw ingredients:

- tmux as the daily driver multiplexer
- `opensessions` sidebar + command-table navigation
- `sesh` session picking and recovery flows
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

- direct session entry via `tmproj`
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

1. Open or focus opensessions
2. Pick a project or worktree from the primary sidebar / command-table surface
3. Enter the canonical tmux session for it
4. Land in a predictable layout
5. See enough context to know what is happening
6. Launch or resume human/agent work without ceremony
7. Preserve enough structure that another human or agent can continue later

In short:

> **one project/worktree, one session, opensessions-first navigation, visible
> state**

---

## Design Principles

### 1. Tmux is the runtime substrate; opensessions is the primary control plane

Tmux is not just a terminal multiplexer here. It is the shared operating surface
for development sessions. But the primary human-facing navigation surface should
be opensessions whenever it is enabled.

### 2. One project or worktree should map to one canonical session

Humans and agents should not need to invent session names on the fly. Session
identity should come from the repo/worktree whenever possible.

### 3. Shared helpers should own attach/create and lifecycle behavior

The common path should still be attach-or-create:

- if the session exists, switch or attach
- if it does not exist, create it with the right cwd/layout

But opensessions should call into shared helpers for that behavior rather than
reimplementing its own parallel naming or lifecycle logic.

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
sessions, configured sessions, and zoxide entries. In the ADE model this picker
is the secondary switch/discovery layer; dismissing it without a choice should
fall back to `tmproj` for the current pane directory when available.

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

This now provides a minimal, clearer command layer around tmux entry:

- `tp` is the short alias for `tmproj`, the canonical current-project
  attach/create helper
- `tvault` is the explicit `termius` / Obsidian / Pi launcher rooted in
  `~/obsidian-vault`
- `tm` remains only as a temporary deprecation shim that points users toward
  `tvault` or `tmproj`
- `tl` and the other raw tmux helpers remain available

`config/zsh/.zshrc` intentionally keeps `t` and `ta` for `todo.sh`, so tmux no
longer competes for those short names.

### Dynamic layout management

- `config/tmux/toggle-tml.sh`

Toggles the `tml` layout on/off from a keybinding (`prefix T`). Creates the
three-pane layout when only one pane exists, tears down extras when multiple
panes exist.

### Window naming hooks

- `config/zsh/tmux-hooks.zsh`

This hook file exists and appears intended to fire `$TMUX_WINDOW_NAME_SCRIPT`
on every `chpwd`, keeping window names in sync with the working directory.

It is now explicitly sourced from `config/zsh/.zshrc`, but remains intentionally
lightweight: zsh only requests a refresh when running inside tmux and when the
smart-name refresh script is actually available.

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

### 1. Opensessions-first ownership is not yet fully reflected in runtime UX

The repo now has the primitives for an opensessions-first ADE, but the runtime
experience is still somewhat hybrid across docs, keybindings, and helper
surfaces.

### 2. Opensessions does not yet expose the backend helper stack directly

`tmproj`, `tw`, and `twd` exist, but opensessions is not yet the obvious place
to invoke or discover those lifecycle actions.

### 3. Ghostty bootstrap vs opensessions-first landing is not fully decided

Ghostty still lands in a stable `home` tmux session. The remaining question is
how strongly startup should steer users into opensessions after that bootstrap.

### 4. Session roles are still somewhat implicit

Layouts like `tml` are useful, but the repo does not yet have a written concept
of role-based pane layouts as part of the ADE.

### 5. Human-agent alignment is partially accidental

Some pieces are agent-aware, but there is no top-level spec that says what
agents should assume about sessions, naming, or discoverability.

### 6. Opensessions stability is on the critical path

As long as opensessions is optional, runtime issues are isolated annoyances. In
an opensessions-first ADE, bugs like the resize-loop tracked in `dotfiles-9bvd`
become blockers for the primary interaction model.

---

## Known Mismatches with Current Implementation

This section exists to keep the spec honest. These are not objections to the ADE
direction; they are places where the intended model and current implementation
still diverge.

### 1. `t` intentionally belongs to `todo.sh`, not tmux

The collision has been resolved by removing tmux-side `t` / `ta` aliases.

The interactive shell now intentionally treats:

- `t` as `todo.sh`
- `ta` as `t add`

The spec should not talk about `t` as a tmux entry command unless that policy
changes later.

### 2. `tm` is only a temporary compatibility shim

Generic project-session entry is now `tmproj`, with `tp` as the short alias.

`tm` no longer defines the command model. It prints a deprecation message and
delegates to `tvault`, the explicitly named workflow-specific launcher rooted in
`~/obsidian-vault` and defaulting to `pi; zsh`.

### 3. Metadata ownership should stay explicit

The current metadata contract is now:

- `tmux-smart-name` is authoritative for tmux window naming, per-window
  `@smart_title_context`, and the exported `TMUX_WINDOW_NAME_SCRIPT` refresh
  command
- `config/zsh/tmux-hooks.zsh` is sourced by `config/zsh/.zshrc`, but only does
  anything when a shell is actually running inside tmux and
  `TMUX_WINDOW_NAME_SCRIPT` is present
- Ghostty still boots into a fixed `home` tmux session, but that is treated as
  a landing/bootstrap session rather than the canonical ADE project-session
  identity

This keeps ownership split cleanly: tmux-smart-name computes metadata, zsh only
requests refreshes on directory changes, and Ghostty remains responsible solely
for getting the user into tmux.

### 4. Tmux popup helpers should stay wrapper-based

The tmux popup bindings now point at wrapper scripts rather than older
`bd-*`-named helpers:

- `br-capture`
- `br-find-all`

Compatibility shims may still exist under the older `bd-*` names, but tmux now
talks to the wrapper layer instead of preserving the legacy naming in the UI.

### 5. The repo is still more hybrid than the target model

The repo now has the necessary primitives for an opensessions-first ADE, but the
implemented UX is still transitional:

- `tmproj` is fully implemented and documented
- `tw` / `twd` exist for worktree lifecycle
- opensessions integration already owns `prefix s`, `prefix S`, and `prefix o`
  when enabled
- but the spec and surrounding docs previously centered `tmproj` + `sesh` more
  heavily than opensessions

This draft pivots the written target state so the control-plane hierarchy is
explicit: opensessions first, shared tmux helpers underneath, sesh as fallback.

---

## Target State

The tmux ADE should provide the following capabilities.

## 1. Opensessions as the primary human-facing control plane

The default human-facing ADE surface should be opensessions.

That means:

- sidebar and command-table navigation should be the normal way to switch
  sessions
- project/worktree selection should be visible and discoverable without
  memorizing helper names
- Ghostty + tmux startup should be able to land in a stable bootstrap session
  while still making opensessions the first-class navigation surface after
  entry
- opensessions should use the same canonical naming/session rules as the rest
  of the ADE rather than inventing a competing identity model

This does **not** mean opensessions should duplicate session lifecycle logic.
It means the primary UX should live there, while shared shell helpers remain the
backend primitives.

## 2. Canonical project session identity

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

## 3. Shared backend session primitives

There should be a small, boring set of backend helpers for:

- current directory → canonical session
- worktree creation + entry
- worktree removal + session cleanup

These are the primitives that scripts, agents, and opensessions actions should
call.

The current implementation includes:

- `bin/tmproj` — attach/create canonical session for a path/project
- `bin/tw` — create sibling worktree, then enter it via `tmproj`
- `bin/twd` — remove worktree and clean up the canonical tmux session

Contract:

- `tmproj [path]` resolves the canonical project root via `bin/tmux-project-root`
- it derives the canonical session name via `bin/tmux-project-name`
- when the session already exists it switches inside tmux and attaches outside
  tmux
- when the session does not exist it creates a plain tmux session rooted at the
  canonical project path, then switches or attaches

This keeps lifecycle behavior boring and composable. Opensessions can sit on top
of these primitives without becoming a second implementation of session naming
or worktree semantics.

## 3.5. A clear metadata contract

The implemented metadata contract is now:

- canonical tmux **session identity** comes from the worktree/project helpers
  (`tmux-project-name`, `tmproj`, `tw`)
- canonical tmux **window naming and title metadata** comes from
  `tmux-smart-name`
- `config/tmux/config` renders terminal titles as either `session` or
  `session · subtitle`, where the subtitle is `@smart_title_context`
- `config/zsh/tmux-hooks.zsh` is a lightweight `chpwd` refresh hook, not an
  independent naming system
- Ghostty's fixed `home` session is only the bootstrap entrypoint; opensessions
  should become the primary human-facing navigation layer after startup, while
  `tmproj` / `tp` remain direct helper paths

This avoids three competing sources of truth. Session helpers choose _which_
session you are in; tmux-smart-name decides _how windows and titles are
presented_ once you are there.

## 4. Layout presets with role semantics

The ADE should support a small set of role-oriented layouts, such as:

- **project** — shell-first general development session
- **agent** — agent pane + git/review pane + shell pane
- **editor** — editor-first startup
- **review** — critique/lazygit-focused layout

The point is not just pane geometry. The point is predictable intent.

## 4a. Popups as a distinct UI primitive

The tmux config already uses ~15 popup bindings for transient, focused
interactions: critique, issue capture, daily notes, file picking, git TUI, and
session config editing.

Popups and persistent panes serve different roles:

- **Persistent panes** — continuous context that stays visible (agent, editor,
  git sidebar, shell)
- **Transient popups** — focused interruptions that dismiss on completion
  (capture, file picking, session switching)

Future layout and agent work should respect this distinction. Agents and scripts
should not open persistent panes for transient tasks, and should not use popups
for context that needs to remain visible.

## 4b. Quick review vs sustained review

The current tmux UX already suggests two review modes, and the ADE should make
that distinction explicit:

- **Quick review** — use popup critique bindings for fast, interruptible diff
  inspection
- **Sustained review** — use `tmlc` / `nicc` / `niccx` when review context
  should stay visible alongside an agent or shell

This keeps the popup-vs-pane model practical instead of purely conceptual.

## 5. Secondary picker and fallback paths

Once opensessions is treated as the primary human-facing control plane, other
navigation paths should remain valuable but secondary.

Fallback paths should remain excellent for:

- switching
- discovery
- recovery
- remote work

This means:

- `sesh` remains useful as a recovery/discovery picker and remote-friendly
  fallback
- `tmproj` remains the direct shell/agent attach-create escape hatch
- when a secondary picker is cancelled or produces no selection, it should fall
  back to the canonical `tmproj` path for the current pane directory instead of
  inventing picker-specific naming/session logic

The design goal is not to eliminate alternate paths. It is to make them clearly
secondary to the opensessions-centered flow.

## 6. Worktree-aware lifecycle commands

The ADE should eventually support commands in the spirit of:

- create worktree + matching session
- remove worktree + matching session
- list project worktrees as session candidates

This is one of the highest-leverage additions because it ties source isolation
and workspace isolation together.

The current implementation now includes:

- `tw <name>` — creates a sibling worktree using a deterministic repo-stem +
  slug naming rule, creates or reuses the matching branch, then enters the new
  workspace via `tmproj <worktree-path>`
- `twd <name-or-path>` — resolves the matching worktree, kills its canonical
  tmux session if present, then removes the worktree

This keeps lifecycle behavior aligned with the same canonical naming/session
contract used by `tmproj`. In an opensessions-first ADE, those helpers should
be surfaced through opensessions actions rather than replaced.

## 7. Remote parity

Remote machines should expose a similar model:

- attach/create named session remotely
- choose remote sessions predictably
- preserve project naming conventions where practical

## 8. Session-visible context

A session should help answer questions like:

- What project is this?
- What branch/worktree is this?
- What agent/tool is active?
- What layout am I in?

This does not need to be noisy. It just needs to be discoverable.

## 9. Task-awareness without hard coupling

Tmux should integrate cleanly with task tooling like `br`, but tmux should not be
so tightly coupled that session management breaks when task tooling evolves.

That means:

- launchers and popups should be swappable
- naming should not depend on one tracker implementation
- task capture should feel native but remain optional

Concrete migration backlog items include replacing or renaming popup helpers
that still expose `bd`-era command names.

---

## Current Command Model

This is the command model the repo should converge toward.

### Primary interactive surface

- `opensessions` — sidebar + command-table session navigation when enabled
- the primary human-facing path should be to pick or switch work through
  opensessions, not to memorize a growing list of tmux entry commands

### Backend and fallback commands

- `tmproj` — direct attach/create primitive for the canonical
  project/worktree session
- `tp` — short alias for `tmproj`
- `tw` / `twd` — worktree lifecycle primitives that should eventually be
  surfaced through opensessions actions
- `sesh` / `config/tmux/sesh-picker.sh` — secondary discovery/recovery picker,
  especially useful when opensessions is unavailable or not the right tool for
  the moment
- `tvault` — explicit Obsidian / vault / Pi tmux entry flow

### Compatibility and legacy behavior

- `tm` — temporary deprecation shim that prints guidance, then runs `tvault`
- `t` / `ta` — intentionally belong to `todo.sh`, not tmux
- `tl` — raw `tmux ls` escape hatch

### Layering rule

- opensessions should call or reflect the canonical `tmproj` / `tw` / `twd`
  model rather than compete with it
- future helpers such as `tv` can still exist, but should layer on top of the
  same naming/session contract rather than define a parallel one

### Deprecation path

- keep `tm` only long enough to redirect muscle memory toward `tvault` and
  the opensessions-first model
- do not reintroduce tmux meanings for `t` or `ta` unless the todo command model
  changes first

The goal is to keep the backend small and the primary UX visible. New commands
must come with a plan to explain whether they are primary UI, backend
primitive, or compatibility shim.

### Layout commands

- `tml` — agent + git + shell layout
- `nic` / `nicx` / `nicc` — opinionated AI variants

### Lifecycle commands

- `tw <name>` — create worktree + session
- `twd <name>` — destroy worktree + session

Current behavior:

- `tw` creates a sibling worktree whose basename is derived from the repository
  stem plus the provided slug, then hands off to `tmproj`
- `twd` accepts either a slug or an explicit path, resolves the matching
  canonical session name with `tmux-project-name`, kills that session if it
  exists, and removes the worktree

### Remote commands

- `tms` — remote session picker / attach-create helper

The point is to separate:

- **choose or switch the workspace**
- **enter the canonical session**
- **choose the layout**
- **manage lifecycle**

instead of forcing a single command to do all three every time.

---

## Implementation Priorities

### Phase 1 — reframe the spec around opensessions

Goal: make the control-plane hierarchy explicit before changing more runtime
behavior.

Tasks:

- rewrite the ADE docs around opensessions-first ownership
- document tmux as runtime substrate plus control-plane host
- define which helpers are backend primitives vs fallback flows
- prune or rewrite older target-state language that assumed `tmproj` + `sesh`
  were the primary user path

### Phase 2 — opensessions-first navigation

Goal: make opensessions the default interactive navigation surface.

Current implementation status:

- opensessions integration already owns `prefix s`, `prefix S`, and `prefix o`
  when enabled
- `bin/tmproj` exists as the canonical attach/create backend primitive
- `config/tmux/sesh-picker.sh` already behaves as a fallback-oriented picker
- the remaining work is mostly about making the ownership boundary explicit in
  docs and runtime defaults

Likely touchpoints:

- `docs/ade/tmux-ade-spec.md`
- `config/tmux/config`
- `modules/shell/tmux/default.nix`
- opensessions integration points under `config/opensessions/`

### Phase 3 — expose backend helpers through opensessions

Goal: keep one backend session/lifecycle implementation while making it
available through the primary UI.

Likely touchpoints:

- opensessions config/plugins
- shell helpers under `bin/`
- tmux bindings and command-table integration

### Phase 4 — remote parity

Goal: make remote session management feel like a natural extension of the local
model.

### Phase 5 — richer session metadata

Goal: expose more state in titles, smart naming, status line, or pickers without
turning tmux into a dashboard gimmick.

---

## Success Criteria

The opensessions-first ADE is moving in the right direction if the following
become true:

1. A human can explain the default tmux workflow in a few sentences, with
   opensessions clearly identified as the main interactive surface
2. An agent can infer when to use opensessions, `tmproj`, `tw`, or `sesh` from
   repo docs alone
3. Project/worktree navigation becomes visible and near-zero-friction
4. Worktree and session sprawl decrease rather than increase
5. Remote work feels like the same system, not a separate one
6. Session naming becomes boring and predictable
7. Disabling or bypassing opensessions still leaves a sane fallback path

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

1. After Ghostty lands in the bootstrap `home` session, should opensessions be
   auto-focused immediately, or should that remain a manual action?
2. How long should the `tm` deprecation shim remain before removal?
3. Which layout should be the default for a freshly created project session:
   plain shell, editor-first, or agent-first?
4. How much session metadata should be visible in titles/status vs. only in the
   opensessions rows and picker surfaces?
5. Should remote sessions preserve the exact same names as local sessions, or
   include a host prefix?
6. How tightly should `br` capture/explore workflows be embedded in tmux popups?
7. Which opensessions actions should directly invoke `tmproj`, `tw`, and `twd`,
   and which should stay purely navigational?
8. How should `sesh` discover newly created worktrees that are not yet in
   zoxide's history, once it becomes a fallback rather than the main picker?
9. What role does `dmux` play in this model? Is it a complementary session
   manager or a competing one that should be reconciled?

---

## Immediate Follow-Up Ideas

Good next implementation candidates after this spec:

1. Route primary tmux navigation through opensessions explicitly
2. Expose `tmproj`, `tw`, and `twd` through opensessions actions
3. Decide when to remove the `tm` compatibility shim entirely
4. Clarify Ghostty bootstrap vs opensessions auto-focus behavior

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
- Draft 3: documented `bin/tmproj` as the current default attach/create helper
  for canonical project sessions, while leaving alias convergence for a later
  cleanup phase
- Draft 4: documented the post-cleanup command model: `tmproj`/`tp` for
  canonical project entry, `tvault` for the vault-specific workflow, `tm` as a
  temporary deprecation shim, and `t`/`ta` as intentional `todo.sh` commands
- Draft 5: clarified the metadata contract: tmux-smart-name owns window/title
  metadata, zsh now wires the `chpwd` refresh hook explicitly, and Ghostty's
  fixed `home` session is documented as a landing session rather than ADE
  project identity
- Draft 6: migrated tmux popup helper entrypoints from `bd-*` names to
  `br-*` wrappers, while keeping compatibility shims so shell muscle memory and
  older integrations do not break immediately
- Draft 7: pivoted the written ADE model to opensessions-first ownership,
  treating opensessions as the primary human-facing control plane while
  `tmproj`, `tw`, `twd`, and `sesh` are documented as backend or fallback paths
