# QMD Extension Snapshot Spec (DIY)

> Status: current snapshot blueprint
> Scope: replicate `extensions/qmd` behavior in a new repo

## 1) Product intent

Implement a repo-local QMD integration that manages indexing **infrastructure and workflow**, while keeping retrieval as direct CLI usage by the agent.

### In scope

- Repo binding detection and marker reconciliation
- Markdown freshness detection from git history
- `/qmd` command family and panel UX
- Deterministic onboarding + confirmed init execution
- Workflow-scoped `qmd_init` tool activation
- Runtime prompt guidance and quiet footer behavior

### Out of scope

- always-on QMD retrieval tool
- automatic query interception/rewrites
- full-text search UI inside the panel
- mirrored QMD config files in repo

## 2) User-facing behavior snapshot

### Commands

- `/qmd` → open panel (`ctx.hasUI`) or plain-text summary fallback
- `/qp` → alias to `/qmd`
- `Ctrl+Alt+Q` → panel toggle
- `/qmd status` → plain-text current-repo status only
- `/qmd update` → update **current repo collection only**
- `/qmd init` → deterministic onboarding flow + confirmation + scoped tool execution

### Panel states

- indexed + fresh
- indexed + stale
- indexed + unknown freshness
- not indexed
- unavailable
- updating
- applying (file toggle changes being applied)

### File tree toggle

The files view shows ALL `.md` files from the filesystem (including dot-directories like `.pi/`), overlaid with indexed state from QMD:

| Indicator | Meaning                                       |
| --------- | --------------------------------------------- |
| `●`       | Indexed (no pending change)                   |
| `○`       | Not indexed (no pending change)               |
| `◉`       | Pending add (will be indexed on apply)        |
| `◎`       | Pending remove (will be deactivated on apply) |

- `space` toggles a file or directory's inclusion
- `enter` expands/collapses directories
- `a` applies all pending changes (batch operation)
- Directory toggle: if any descendant is effectively included → remove all; otherwise add all
- Directories show aggregate indicators (`●` all, `◐` some, `○` none)

### Runtime behavior

- On session lifecycle hooks: refresh binding/freshness state
- Footer shown only when indexed (fresh/stale/unknown)
- Silent footer when not indexed or unavailable
- Inject short `qmd query/search/get` guidance before agent start when indexed

## 3) Source-of-truth model

- QMD store is source of truth for collections + contexts
- `.pi/qmd.json` is source of truth for repo binding + freshness marker only

### Marker schema

```ts
{
  schema_version: 1,
  repo_root: string,
  collection_key: string,
  last_indexed_at: string,
  last_indexed_commit: string,
  created_at: string,
  extra_paths?: string[],  // dot-path files explicitly added by the user
}
```

`extra_paths` stores filesystem-relative paths with dot-segments (e.g. `.pi/tracks/summary.md`) that the user chose to index. QMD's reindexer skips dot-prefixed path segments, so these must be re-indexed after every `update_collection()` call.

### Canonical identity

- Canonical repo identity is normalized absolute `repo_root`
- Collection key is deterministic path-derived encoding
- One binding per repo root

## 3b) Dot-path file handling

QMD's `reindexCollection` skips dot-prefixed path segments (`dot: false` in fastGlob + explicit hidden filter). This means files under `.pi/`, `.github/`, etc. are invisible to the scanner and get deactivated on every reindex.

**Workaround architecture:**

1. **Direct insertion via internal store APIs** — `insertDocument` / `insertContent` have no dot-path restriction. Use these for targeted file adds.
2. **Persistent `extra_paths` in marker** — dot-path files the user adds are saved in `.pi/qmd.json`. After every `update_collection()` call, re-index `extra_paths` to restore them.
3. **Path normalization** — QMD stores "handlized" paths (lowercased, special chars replaced with hyphens, leading dots stripped). The UI uses filesystem paths as canonical keys and translates at the store boundary via `handelize_path()`.

**Touch points that must re-index `extra_paths`:**

- `/qmd update` (`run_update`)
- `/qmd init` (`execute_init`) — automatically discovers and indexes all dot-path `.md` files
- File tree toggle (`on_toggle_files`) — updates `extra_paths` when dot-path files are added/removed

## 4) Architecture and boundaries

Dependency direction:

```text
Extension → UI → Core
Extension → Domain → Core → QMD SDK
```

### Layer responsibilities

- **core/**: typed errors, schemas/contracts, store wrapper
- **domain/**: repo binding, freshness, onboarding pipeline
- **extension/**: runtime hooks, commands, scoped tool lifecycle
- **ui/**: snapshot building + panel rendering + plain-text fallback

## 5) Required deterministic onboarding pipeline

1. Scan repo (bounded)
2. Build draft proposal deterministically
3. Ask agent to refine proposal (not reinvent)
4. Normalize/validate confirmed proposal
5. Execute init:
   - add collection
   - set contexts
   - update that collection only
   - embed only if needed
   - write marker

## 6) Freshness contract

Compare marker commit against `HEAD` using markdown-only diff.

Conceptual command:

```bash
git diff --name-only --diff-filter=ACMR <last_indexed_commit>..HEAD -- ':(glob)**/*.md'
```

Return:

- `fresh`
- `stale` (with changed files/count)
- `unknown`

## 7) Error model

Use agent-legible typed errors (or equivalent) for:

- QMD unavailable
- marker/store binding mismatch
- invalid confirmed init proposal

## 8) Minimal acceptance checklist

- `/qmd`, `/qp`, shortcut open/close panel correctly
- `/qmd status` reports indexed/not-indexed/unavailable accurately
- `/qmd update` updates current repo collection only
- `/qmd init` requires confirmation before execution
- `qmd_init` tool is inactive outside init workflow
- footer is silent when repo is not indexed
- marker never becomes duplicate config for contexts/paths

## 9) Verification targets

- unit tests for contracts and store wrapper
- tests for repo binding detection and mismatch handling
- tests for freshness states
- tests for runtime prompt/footer behavior
- tests for panel snapshot shaping and file tree behavior

## 10) Compatibility note

This blueprint targets the behavior represented by:

- `extensions/qmd/*`
- `.pi/tracks/agent-memory/specs/qmd-extension-v1.md`
- `.pi/tracks/agent-memory/exec-plans/qmd-extension-v1.md`

Use `references.md` for direct raw-file links.
