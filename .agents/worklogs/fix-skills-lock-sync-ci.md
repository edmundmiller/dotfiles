# Worklog: fix-skills-lock-sync-ci

Status: active

## Objective

Make the deterministic skills-lock synchronization hook run in native Linux CI
without relying on ambient Nix experimental-feature settings.

## Decisions

- Keep this Linux compatibility repair separate from the agent-quality, Pi
  Hunk, and package-publication commits.
- Enable `nix-command` and `flakes` on the nested command itself. Do not change
  global Nix policy or weaken the lock check.
- Preserve the independent Python comparison after Nix validates the child
  lockfile.

## Evidence

- Final-tip CI run `33296912916` passed Pi package QA, Herdr VM, and Darwin
  pre-commit, but Linux pre-commit failed only in `skills-lock-sync` with
  `experimental Nix feature 'nix-command' is disabled`.
- The focused hook-wiring regression failed before the command change and
  passes afterward.
- All nine `tests.test_skills_lock_sync` cases pass.
- With ambient experimental features explicitly cleared, the updated command
  completes and `skills/scripts/check-lock-sync.py` reports
  `PASS skills-lock-sync`.
- `nix fmt flake.nix tests/test_skills_lock_sync.py` and `git diff --check`
  pass.
- `hey check --worktree` passes Darwin evaluation, formatting, direct hooks,
  tmux, package harness/policy, DJI Mic Mini, and ast-grep checks.

## Reviews

- Independent diagnosis confirmed the per-command feature flags are sufficient
  for the Linux CI failure and do not address or conceal the separate local
  Darwin build-user daemon policy limitation.
- A second independent review reproduced that both features are required,
  confirmed the nine-test suite, and found the current change to be the smallest
  repair that preserves full child-flake validation.
- Final diff review found no P1/P2 issues, confirmed the Nix CLI argument order,
  and verified that the regression test covers both feature flags without
  modifying the nested lockfile.

## Feedback

- Hooks that invoke experimental Nix subcommands must declare their own feature
  requirements; the parent Nix process's settings do not automatically become
  the nested client's settings inside a derivation.

## Remaining work

- Run the repository gates, commit and publish the isolated repair, then verify
  native GitHub Linux and Darwin CI at the landed revision.

## Commits

The isolated compatibility commit and annotated tag will be recorded after
landing.
