---
purpose: Track the Amos Linear credential repair through NUC deployment proof.
applies_to: Amos Hermes cron authentication on the NUC.
entrypoint: hosts/nuc/default.nix and tests/test_hermes_cron_executors.py.
verification: Focused test, NUC deploy, exact-environment read-only Linear query.
update_when: Evidence, review findings, commits, or landing status changes.
---

# Worklog: amos-linear-auth

Status: complete

## Objective

Materialize Amos's valid 1Password Linear credential into its isolated cron executor environment. Stop after regression coverage, local checks, `hey nuc`, read-only Linear identity/query proof, commit, rebase, push, and upstream-current verification. Never run a cron job manually or mutate Linear.

## Decisions

- Replace the stale shared OAuth token source only for Amos.
- Use `op://Agents/Amos Linear Bot Team/credential`, already proven by a read-only GraphQL viewer query.
- Do not mutate cron state. Preserve the Linear bug queue sweep's hourly schedule.

## Evidence

- NUC SSH and passwordless sudo succeeded.
- Amos timer is enabled and active.
- Existing exact executor environment returned Linear HTTP 401.
- Persisted OAuth token was last written 2026-04-04; its refresh service and timer are absent/inactive.
- Candidate 1Password credential returned Linear HTTP 200 for `viewer`.
- `python3 -m unittest tests.test_hermes_cron_executors -v`: 2 passed.
- `nixfmt --check hosts/nuc/default.nix` and `git diff --check`: passed.
- `hey nuc dry-activate`: built successfully; only Home Manager restart predicted.
- `hey nuc`: switched to `/nix/store/hy3vw37bbz1pdhf0b2pkp9z5pfgfm7an-nixos-system-nuc-26.11.20260714.18b9261`.
- Live timer remained enabled/active. Job `8910f5c8ba39` remained enabled on its 60-minute interval.
- Exact Amos systemd environment: read-only Linear `viewer` plus `issues(first: 1)` returned HTTP 200; API and MCP token bindings matched.
- Generic post-deploy `hermes-runtime-smoke.service` was masked and is not counted as proof.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey agent-finish`: focused inventory/tests passed, but repo-quality failed because the checkout has neither `prek.toml` nor `.pre-commit-config.yaml`; no no-op check is counted as passed.
- Rebased onto `origin/main` at `13db3c63fa`; focused tests and Nix formatting still passed.
- Concurrent canonical cron updates changed the Linear bug queue sweep ID to `42b0137c1f43` without changing its enabled hourly schedule.
- Post-rebase drift check found the Amos environment no longer matched the still-valid 1Password credential, so the allowed conditional redeploy was required.
- Final `hey nuc` switched to `/nix/store/10x44d51xb7hnlmc436ism7xajl6sq1v-nixos-system-nuc-26.11.20260714.18b9261`.
- Final live proof: environment matches 1Password, timer enabled/active, read-only `viewer` plus `issues(first: 1)` HTTP 200, API/MCP bindings equal.

## Reviews

- Plan: blocked. `hey agent-review plan --active-model-family gpt-5 --worklog .agents/worklogs/amos-linear-auth.md` returned `RUNTIME: Authentication required` on 2026-07-17. No retry per provider-auth guard.
- Landing: blocked. `hey agent-review landing --active-model-family gpt-5 --worklog .agents/worklogs/amos-linear-auth.md` returned `RUNTIME: Authentication required` on 2026-07-17. No retry per provider-auth guard.

## Feedback

None.

## Remaining work

None.

## Commits

- `f0d2b43995` test(hermes): cover Amos Linear credential source
- `2aa9e94a7b` fix(hermes): repair Amos Linear authentication
