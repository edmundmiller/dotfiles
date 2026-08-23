# Worklog: retire-openclaw-trim-skills

Status: active

## Objective

Reduce shared skill-routing conflicts and retire OpenClaw-owned configuration. Stop when the cleanup is committed before skill-source updates, update-only changes are committed separately, focused checks pass, live runtime state matches the source, and unrelated dirty files remain unchanged.

## Decisions

- Prefer Codex and OMP native capabilities over overlapping shared skills.
- Preserve deterministic validators and genuinely distinct workflows.
- Treat OpenClaw runtime configuration as retired; do not remove unrelated upstream projects merely because their GitHub organization is named `openclaw`.
- Authority is local-only: commit, but do not push.

## Evidence

- Baseline: detached Git worktree at `d78d1c8dc6be26c4d02524aea315a9ec2f2b3b63`.
- Unrelated dirt to preserve: `modules/services/hass/default.nix` and `packages/herdr-plugins/default.nix`.
- Host: `MacTraitor-Pro.local`, Darwin arm64.

## Reviews

Plan gate not required; no external reviewer requested.

## Feedback

The prior audit was read-only; cleanup recommendations must not be described as already applied.

## Remaining work

- Classify exact skill and OpenClaw cuts.
- Apply and validate cleanup.
- Commit cleanup, update skill inputs, activate, verify, and commit update-only changes.

## Commits

None yet.
