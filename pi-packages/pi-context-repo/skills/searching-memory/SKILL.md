## <!-- Purpose: Teach agents fast day-to-day memory browse/search/read/sync workflows in pi-context-repo. -->

name: searching-memory
description: >
Search, browse, and inspect memory quickly in pi-context-repo. Use when asked
to find prior notes, inspect memory files, locate preferences, or sync recent
memory updates. Trigger phrases: "search memory", "list memory files",
"find in memory", "read memory file", "memory status", "sync memory".

---

# Searching Memory

Use this workflow for fast retrieval and lightweight maintenance.

## 1) Find candidate files

- `memory_search` when you have a keyword.
- `memory_list` when you need directory-oriented discovery.

Start broad, then narrow:

- `memory_list` (root overview)
- `memory_list { directory: "system" }`
- `memory_list { directory: "reference" }`

## 2) Read exact file

Use `memory_read` with a single relative path (e.g. `system/style.md`).

- Prefer reading one file at a time.
- If result is close but not exact, branch back to `memory_search`.

## 3) Update only if needed

If memory is stale:

1. `memory_write` with concise, merged content
2. `memory_commit` with clear message

Avoid duplicate files or repetitive notes.

## 4) Verify sync state

- Run `/memory` for status + recent history.
- If ahead of remote, push from shell:

```bash
git -C "$MEMORY_DIR" push
```

## Heuristics

- **Known file path?** → `memory_read`
- **Known keyword, unknown file?** → `memory_search`
- **Unknown shape entirely?** → `memory_list`
- **Need old conversation context?** → `memory_recall`

## Constraints

- Keep writes under file `limit`.
- Never modify `read_only` files.
- Preserve frontmatter schema (`description`, `limit`, optional protected `read_only`).
