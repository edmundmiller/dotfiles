# nf-test Checklist

Use this when an nf-test task needs more than the core loop in `SKILL.md`.

## Target

- Read the process/workflow `main.nf`, existing `.nf.test`, local `nextflow.config`, and root `nf-test.config`.
- Preserve existing tags, profiles, plugin choices, and snapshot style.
- Add one behavior at a time: mode, optional output, config branch, error case, or workflow wiring.

## Inputs

- Use tiny real test data and `file(..., checkIfExists: true)`.
- Build channels with representative meta maps.
- Use per-test `config './nextflow.mode.config'` for mode-specific settings.

## Assertions

- Assert `process.success` first.
- Assert meaningful report/log/file content before snapshots.
- Snapshot deterministic channel outputs, files, and `versions` only.
- Review snapshot diffs before updating.

## Command

- Prefer the repo command when documented.
- Otherwise run `nf-test test path/to/main.nf.test`.
- Use `NFT_WORKDIR=$(mktemp -d)` when isolation matters.
