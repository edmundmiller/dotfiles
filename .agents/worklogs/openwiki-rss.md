# Worklog: openwiki-rss

Status: active

## Objective

Package a built-in OpenWiki RSS/Atom connector supporting multiple stable source instances, bounded deterministic incremental capture, registry/onboarding/CLI/schedule integration, and secret-safe connector artifacts. Stop when the fresh-upstream harness, package build/install checks, focused connector smoke, repository package checks, and landing review are exercised; commit only task-shaped files. Do not activate live config, schedules, credentials, or vault writes.

## Decisions

- Extend pinned OpenWiki through reviewable patches; do not add a separate Flue agent.
- Preserve feed and entry provenance in connector-local normalized JSON/manifests; synthesis remains OpenWiki's existing ingestion stage.
- Treat stable source identity, conditional HTTP validators, content identity, bounds, deterministic serialization, and secret exclusion as tested contracts.
- Model each subscribed URL as an existing OpenWiki source instance (`rss-N`), isolating ETag, Last-Modified, and entry hashes by instance ID. This reuses `ingest <source-instance>|rss|all` and the shared schedule instead of adding a parallel scheduler.
- Use a real XML parser dependency in upstream source. Bound bytes before parsing; do not implement an ad-hoc XML subset.
- Reject feed URLs with userinfo or secret-like query parameter names before config/state/raw output.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64 (`hostname`; `uname -a`).
- Package source: `langchain-ai/openwiki` at `d4e94ab513ab13908c6b61346b23dc17bbd59b1f`, version `0.2.0`.
- Existing four-patch stack applies cleanly in `/tmp/openwiki-rss.MJjoLj`.
- `origin/main` at `1f0862e` has no RSS/Atom connector or tests (`git grep` scoped to connector source/tests/docs/package metadata).
- Existing integration surfaces: connector registry/types, deterministic ingestion, persisted source instances, shared `ingest all` schedule, Ink onboarding, README, package harness.
- Pre-rebase RED package state: fresh `pkg-check openwiki` passed typecheck and 74 tests with five strict expected failures from the RSS regression patch, now numbered `0006-rss-connector-regression.patch` after main's evlog patch.
- GREEN upstream workbench: final `pnpm test` passed 366 tests across 36 files; `pnpm typecheck` passed; scoped ESLint passed for changed source/test files.
- GREEN fresh source: final `nix develop -c pkg-check openwiki` cloned the pinned revision, applied the full patch stack, installed the frozen lockfile, passed typecheck, and passed focused tests.
- Package: `nix build .#openwiki` passed, including the `fast-xml-parser` install check. After rebasing over main's evlog dependency, the combined patched dependency hash is `sha256-g2gxm4iBRcnKfXLwZJ326IGbEBRhcXE8iXakh3dU4cY=`.
- Packaged CLI smoke: a temporary HOME plus local HTTP 304 endpoint exercised `./result/bin/openwiki ingest rss --print`; it selected `RSS / Atom`, skipped synthesis with zero raw files, and wrote connector state. No live OpenWiki config, schedules, credentials, or vault files were touched.
- `nix develop -c ast-grep scan packages/` passed.
- `./bin/hey check` passed Darwin evaluation, formatting, hooks, package harness/policy, tmux tests, and ast-grep tests.
- Final manual review disabled feed-defined XML entity expansion and added a passing regression test, preventing bounded XML input from expanding into unbounded parser output.

## Reviews

- Plan gate attempted with `./bin/hey agent-review plan --active-model-family openai --worklog .agents/worklogs/openwiki-rss.md`; blocked at ACP `session/new` by `RUNTIME: Authentication required`. No review findings were produced. The explicit delegated requirements and scoped package plan remain operative; landing review will retry.
- Landing review attempted with `./bin/hey agent-review landing --active-model-family openai --worklog .agents/worklogs/openwiki-rss.md`; blocked at ACP `session/new` by the same `RUNTIME: Authentication required`. No review findings were produced. Manual diff review added XML entity hardening and a regression test; all final gates were rerun.

## Feedback

- `fetchPnpmDeps` must receive `finalAttrs.patches` when a local source patch changes `pnpm-lock.yaml`; otherwise the old dependency hash can appear valid while the patched build lacks the new package.

## Remaining work

- Run agent audit/finish and landing review.
- Commit implementation/worklog, rebase/push, and verify upstream state.

## Commits

- `36659e602 test(openwiki): define RSS ingestion contracts`
