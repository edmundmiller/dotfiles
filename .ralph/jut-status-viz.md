# Implement but-style status visualization for jut

## Goal
Rewrite `jut status` to show stacked and parallel branches using the same tree-drawing visualization as `but status`.

## Design
- Parse jj DAG to identify stacks (chains of mutable revisions from trunk to bookmarks)
- Render with tree-drawing characters: `┊`, `╭`, `├`, `│`, `╯`, `┴`
- Show commits with colored dots, short IDs, descriptions
- Show file changes per revision
- Show bookmarks inline on their revisions
- Show working copy `@` marker
- Support `--json` output with stack structure

## Checklist
- [x] Add `RevisionInfo` struct and `stacks()` method to `Repo`
- [x] Add stack detection logic (walk from bookmarks to trunk)
- [x] Rewrite `status.rs` with tree rendering matching `but status` style
- [x] Handle parallel stacks (multiple bookmarks from same base)
- [x] Handle working copy highlight
- [x] Handle file changes display
- [x] Update JSON output to include stack structure
- [x] Build and test
- [x] Fix any compilation errors
