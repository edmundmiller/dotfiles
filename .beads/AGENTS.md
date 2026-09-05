# Beads

Use `br` from the repository root; `bd` is retired (the shim exits 127).
`br ready`, `br show <id>`, and [README.md](README.md) cover tracker discovery.

Shared issue state is `issues.jsonl`. SQLite databases, locks, recovery files,
and backups are ignored runtime artifacts. `br sync --import-only` imports;
`br sync --flush-only` exports.

Close with `br close <id> --reason <reason>` after acceptance criteria are met
and the work is landed. Each Herdr downstream patch references an open bead;
close it after removing the patch and verifying the affected package.
