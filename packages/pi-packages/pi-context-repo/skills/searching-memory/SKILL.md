---
name: searching-memory
description: Retrieves pi-context-repo notes and checks memory sync state. Use to find prior preferences, read memory files, or synchronize requested updates.
---

# Searching memory

Use `memory_read` for a known path, `memory_search` for a keyword,
`memory_list` for directory discovery, and `memory_recall` for old conversation
context. Paths are relative to the memory repository (e.g. `system/style.md`).

For requested maintenance, merge stale notes with `memory_write` and
`memory_commit`; preserve frontmatter `description`, `limit`, and protected
`read_only`. Stay within file limits and leave read-only files unchanged.

`/memory` shows status/history. When remote synchronization is authorized,
`git -C "$MEMORY_DIR" push` publishes local memory commits; an ahead status
alone does not authorize publication.
