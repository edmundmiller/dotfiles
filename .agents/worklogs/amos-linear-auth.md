---
purpose: Track the Amos Linear credential repair through NUC deployment proof.
applies_to: Amos Hermes cron authentication on the NUC.
entrypoint: hosts/nuc/default.nix and tests/test_hermes_cron_executors.py.
verification: Focused test, NUC deploy, exact-environment read-only Linear query.
update_when: Evidence, review findings, commits, or landing status changes.
---

# Worklog: amos-linear-auth

Status: active

## Objective

Materialize Amos's valid 1Password Linear credential into its isolated cron executor environment. Stop after regression coverage, local checks, `hey nuc`, read-only Linear identity/query proof, commit, rebase, push, and upstream-current verification. Never run a cron job manually or mutate Linear.

## Decisions

- Replace the stale shared OAuth token source only for Amos.
- Use `op://Agents/Amos Linear Bot Team/credential`, already proven by a read-only GraphQL viewer query.
- Keep job `8910f5c8ba39` and its schedule unchanged.

## Evidence

- NUC SSH and passwordless sudo succeeded.
- Amos timer is enabled and active.
- Existing exact executor environment returned Linear HTTP 401.
- Persisted OAuth token was last written 2026-04-04; its refresh service and timer are absent/inactive.
- Candidate 1Password credential returned Linear HTTP 200 for `viewer`.

## Reviews

- Plan: blocked. `hey agent-review plan --active-model-family gpt-5 --worklog .agents/worklogs/amos-linear-auth.md` returned `RUNTIME: Authentication required` on 2026-07-17. No retry per provider-auth guard.
- Landing: pending.

## Feedback

None.

## Remaining work

- Regression test and implementation commits.
- Local checks and NUC deploy/read-only runtime proof.
- Landing review, rebase, push, tag, upstream verification.

## Commits

None.
