# Worklog: fix-pi-publish-bun-ci

Status: complete

## Objective

Repair the Pi package publication workflow exposed by the Pi Hunk CI repair.
Stop when package QA has its declared Bun runtime, non-version manifest edits do
not falsely schedule a publish, the workflow is valid, and a remote dry run at
the landed revision passes without publishing a package.

## Decisions

- Keep this workflow repair separate from the Pi Hunk source fix.
- Reuse the same pinned Bun setup action as the main Linux CI workflow.
- Normalize the package directory before constructing the Git object path;
  preserve version changes as the sole automatic publication trigger.
- Use `workflow_dispatch` with `dry-run: true` for remote proof; never publish a
  package as part of this repair.

## Evidence

- GitHub run `33296009768` failed in `QA pi-hunk` with
  `error: bun is required for qa-changed`.
- The same run incorrectly detected `pi-hunk` even though its version remained
  `0.1.0`; the workflow constructed `pi-hunk//package.json`, so `git show`
  fell back to version `0.0.0`.
- Main CI already uses `oven-sh/setup-bun@v2` immediately before
  `qa-changed`; the publication quality gate now matches that runtime contract.
- `actionlint .github/workflows/publish-packages.yml` passes.
- The normalized Git object path reads the prior and current `pi-hunk`
  manifests as `0.1.0`, so this non-version change no longer schedules publish.
- Scoped `hey check --worktree` passes Darwin evaluation, formatting, hooks,
  tmux, package harness/policy, DJI Mic Mini, and ast-grep checks.

## Reviews

- The failure log and current workflow were read independently before editing.
- Fresh final review found no P1/P2 issues and confirmed both Bun step ordering
  and the normalized previous-manifest path; `actionlint` independently passes.

## Feedback

- A successful package QA script locally is not proof that every workflow
  installs its declared runtime.

## Remaining work

- No implementation work remains. Closeout must commit and publish this
  isolated repair, then run and inspect the remote dry-run workflow at the
  landed revision.

## Commits

The isolated workflow repair commit hash will be reported in the final handoff.
