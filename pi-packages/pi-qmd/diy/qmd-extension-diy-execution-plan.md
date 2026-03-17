# QMD DIY Execution Plan

> Goal: rebuild the current QMD extension behavior from this blueprint
> Input spec: `./qmd-extension-snapshot-spec.md`

## Milestone 1 — Scaffold + contracts

- Create structure: `core/`, `domain/`, `extension/`, `ui/`, `docs/`, `__tests__/`
- Add typed errors for unavailable/mismatch/invalid-proposal paths
- Add runtime schemas for marker + onboarding payloads
- Add minimal tool boundary schema for `qmd_init`
- Implement QMD store wrapper with lazy lifecycle + translated errors

**Done when**

- Extension loads
- Schemas validate expected payloads
- Store wrapper handles open/close + error translation

## Milestone 2 — Repo binding model

- Normalize repo root and derive deterministic collection key
- Read/write `.pi/qmd.json`
- Implement binding detection:
  1. marker check
  2. store verification
  3. fallback store lookup by repo root
- Return indexed/not-indexed/unavailable + repair notes

**Done when**

- Indexed repos resolve reliably
- marker/store mismatch is explicit and actionable

## Milestone 3 — Freshness detection

- Compare `last_indexed_commit` vs `HEAD` for markdown-only changes
- Return `fresh | stale | unknown`
- Include stale file count/paths when available

**Done when**

- Markdown changes reliably flip status to stale
- Non-git/invalid cases return unknown cleanly

## Milestone 4 — Runtime wiring

- Hook lifecycle events to refresh binding/freshness
- Set quiet footer status only for indexed repos
- Inject short CLI guidance before agent start when indexed
- Close store on shutdown

**Done when**

- Indexed repos show status
- non-indexed/unavailable stays silent
- agent receives guidance only when useful

## Milestone 5 — Commands + panel

- Implement `/qmd`, `/qp`, `Ctrl+Alt+Q`
- Implement `/qmd status`, `/qmd update`, `/qmd init`
- Add snapshot builder + panel render states + file tree view
- Add plain-text fallback for non-TUI mode

**Done when**

- command routing matches snapshot behavior
- panel state and keyboard navigation are usable

## Milestone 6 — Scoped onboarding flow

- Build deterministic pipeline:
  - scan repo
  - draft proposal
  - init prompt context
  - normalize confirmed proposal
  - execute init
- Keep `qmd_init` inactive by default
- Activate only for init workflow; always deactivate in `finally`

**Done when**

- init requires explicit confirmation
- tool scope does not leak after success/failure

## Milestone 7 — File tree toggle + dot-path support

- Add `scan_filesystem_paths()` — walk repo for all `.md` files (including dot-dirs)
- Add `handelize_path()` — normalize filesystem paths to QMD's stored format
- Add `index_files()` — direct insertion via internal store APIs (bypasses scanner)
- Add `has_dot_segment()` — detect paths needing `extra_paths` persistence
- Build `ToggleState` class — pure toggle logic with `pending_adds`/`pending_removes` sets
- Wire file tree view in panel — filesystem scan overlaid with indexed state
- Implement `on_toggle_files` callback — `deactivate_document` for removes, `index_files` for adds
- Maintain `extra_paths` in marker — persist dot-path selections across updates
- Re-index `extra_paths` after every `update_collection()` in both `run_update` and `execute_init`
- Add `deactivate_document()` — wraps internal store with handlized path translation

**Done when**

- Users can toggle file inclusion via space key in file tree
- Dot-path files persist across `/qmd update`
- `/qmd init` automatically indexes dot-path files
- Toggle state is testable independently from panel UI

## Milestone 8 — Quality + docs parity

- Ensure docs match actual command/runtime behavior
- Add/update README + architecture/onboarding/freshness/panel docs
- Ensure source-of-truth rule is explicit in docs
- Run tests/checks and fix any regressions

**Done when**

- implementation and docs tell the same story
- no global update behavior
- no marker config duplication

## Suggested implementation order in a new repo

1. contracts + store wrapper
2. binding + freshness
3. runtime + status/update commands
4. onboarding + tool lifecycle
5. panel + docs + tests
6. file tree toggle + dot-path support

## Guardrails

- Zod-first (or equivalent runtime validation) at boundaries
- TypeBox only where the host API requires it
- never let marker become mirrored QMD config
- `/qmd update` must stay current-repo scoped
