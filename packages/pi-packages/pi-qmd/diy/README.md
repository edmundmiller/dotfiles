# QMD DIY Blueprint

This directory is a **copy/paste blueprint** for rebuilding the QMD extension in another repo without installing this package.

## Goal

Give another agent enough implementation detail to recreate the same behavior snapshot:

- `/qmd`, `/qp`, `Ctrl+Alt+Q` panel
- `/qmd status`, `/qmd update`, `/qmd init`
- repo binding + freshness marker (`.pi/qmd.json`)
- deterministic onboarding flow
- workflow-scoped `qmd_init` tool activation
- indexed-only footer + prompt guidance

## How to use this in another repo

1. Copy this entire `diy/` folder into that repo.
2. Tell your agent to implement `qmd-extension-snapshot-spec.md` using `qmd-extension-diy-execution-plan.md`.
3. Provide `references.md` so it can pull deeper context from raw source files.

Suggested prompt:

```text
Implement the QMD extension described in ./diy/qmd-extension-snapshot-spec.md.
Follow ./diy/qmd-extension-diy-execution-plan.md milestone-by-milestone.
Use ./diy/references.md for source-of-truth links.
Match behavior exactly before proposing any v2 improvements.
```

## Files in this folder

- `qmd-extension-snapshot-spec.md` — implementation blueprint for the current behavior snapshot
- `qmd-extension-diy-execution-plan.md` — step-by-step build plan
- `agent-prompt-template.md` — ready-to-paste prompt for another agent
- `references.md` — internal docs + track artifacts + raw links
