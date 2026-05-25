# QMD Extension Architecture

## Layers

- **UI**
  - `ui/panel.ts` — interactive TUI panel (overview, files, updating views)
  - `ui/data.ts` — snapshot builder, file tree, formatting helpers
  - `ui/constants.ts` — panel constants (width, shortcuts, icon)
  - `ui/plain-text.ts` — non-TUI fallback summary
- **Extension**
  - `extension/command.ts` — slash commands, alias, shortcut, panel lifecycle
  - `extension/runtime.ts` — session lifecycle hooks, footer, prompt injection
  - `extension/tool.ts` — workflow-scoped `qmd_init` tool
- **Domain**
  - `domain/repo-binding.ts` — repo root, collection key, marker I/O
  - `domain/freshness.ts` — git-based markdown freshness detection
  - `domain/onboarding.ts` — deterministic init pipeline
- **Core**
  - `core/qmd-store.ts` — SDK wrapper with lazy lifecycle
  - `core/types.ts` — Zod schemas and TypeBox tool params
  - `core/errors.ts` — agent-legible typed errors

Dependency direction stays one-way:

```
Extension → UI → Core
Extension → Domain → Core → QMD SDK
```

The `ui/` layer imports from `core/` (types, store) but never from `extension/` or `domain/`. Actions flow into the panel via callbacks, not imports.

## Core responsibilities

### `core/types.ts`

Runtime schemas and normalized types.
Zod is the runtime authority.
TypeBox is only used at the Pi tool-registration boundary (`QmdInitParams`).

### `core/errors.ts`

Agent-legible typed errors:

- `QmdUnavailableError` — store can't be opened
- `CollectionBindingMismatchError` — marker/store drift
- `InvalidInitProposalError` — bad onboarding input

### `core/qmd-store.ts`

Small wrapper around `@tobilu/qmd`:

- lazy store lifecycle (module-level singleton via `store_promise`)
- translated errors via `with_store()`
- narrow helpers: `list_collections`, `add_collection`, `set_contexts`, `list_contexts`, `update_collection`, `embed_pending`, `get_status`, `get_active_document_paths`, `get_index_health`, `close_store`

Note: `get_active_document_paths()` uses `store.internal.getActiveDocumentPaths()` — the low-level `InternalStore`, not the high-level `QMDStore`.

## Domain responsibilities

### `domain/repo-binding.ts`

- find normalized repo root
- derive path-based collection key
- read/write `.pi/qmd.json`
- reconcile marker and QMD store (legacy key fallback + repair warnings)

### `domain/freshness.ts`

- compare `last_indexed_commit` against `HEAD` with markdown-only diff
- return `fresh | stale | unknown`

### `domain/onboarding.ts`

Deterministic pipeline:

- scan repo (bounded traversal)
- build draft proposal
- build init prompt for agent refinement
- normalize confirmed proposal via Zod
- execute init via the store wrapper

## UI responsibilities

### `ui/data.ts`

Pure data layer — no TUI or Pi imports.

- `QmdPanelSnapshot` — flat, serializable struct with all panel data
- `build_qmd_panel_snapshot()` — gathers binding, freshness, store data into a snapshot
- `build_file_tree()` / `flatten_tree()` — hierarchical tree with single-child collapsing
- `format_relative_time()`, `group_paths_by_directory()`, `wrap_text()` — formatting helpers

### `ui/panel.ts`

Interactive TUI panel with three views:

- **Overview** — binding status, freshness, index stats, contexts, stale files
- **Files** — NERDTree-style collapsible file browser with vi-style navigation
- **Updating** — progress display during index updates

Actions are injected via `QmdPanelCallbacks` (get_snapshot, on_update, on_init, on_close).

### `ui/plain-text.ts`

Renders a `QmdPanelSnapshot` as plain text for non-TUI environments.

### `ui/constants.ts`

All panel magic values: command names, alias, shortcut, icon, width.

## Extension responsibilities

### `extension/command.ts`

User-facing commands and panel lifecycle:

- `/qmd` (no args) — opens the panel (or plain-text fallback)
- `/qmd status` — prints text status
- `/qmd update` — runs scoped update
- `/qmd init` — starts onboarding flow
- `/qp` — alias for `/qmd`
- `Ctrl+Alt+Q` — toggle shortcut

Manages panel open/close state and wires callbacks.

### `extension/runtime.ts`

- refresh binding/freshness on session lifecycle events (`session_start`, `session_switch`, `session_tree`, `session_fork`, `session_compact`)
- close panel on `session_start` and `session_switch`
- set quiet footer status (silent when not indexed)
- inject short QMD CLI guidance via `before_agent_start`
- close the store on `session_shutdown`

### `extension/tool.ts`

Workflow-scoped `qmd_init` tool.
It is registered at load time but removed from the active tool set by default.
`/qmd init` activates it and execution deactivates it in `finally`.

## Source-of-truth rule

Do not let `.pi/qmd.json` become a second config system.

- collections + contexts live in QMD
- `.pi/qmd.json` only tracks binding + freshness metadata
