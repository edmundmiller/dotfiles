# Worklog: openwiki-links-input

Status: complete

## Objective

Add a packaged OpenWiki links source that persists a deterministic URL queue, ingests new or changed entries through `ingest links` and `ingest all`, and feeds the existing personal synthesis. Stop when fresh-source tests, package build, built CLI smoke checks, and repository gates pass and task-shaped commits are pushed.

## Decisions

- OpenWiki owns link ingestion; no Flue or live vault/config/schedule changes.
- Preserve original and canonical URL, capture timestamp, optional metadata/provenance, and a stable source ID without storing credentials.
- Prefer one upstream-shaped patch after the existing package patch stack.
- Persist the queue at `~/.openwiki/connectors/links/config.json`; onboarding creates it and later additions can use the documented schema.
- Canonicalize HTTP(S) URLs locally, remove fragments/tracking parameters, sort query parameters, and derive the stable source ID from SHA-256 of the canonical URL.
- Store a content fingerprint in connector state. Emit a raw manifest only for new or changed records; a repeat run is a no-op.
- Do not fetch target URLs. The connector captures link records only, avoiding SSRF and accidental credential/cookie persistence.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Initial worktree: detached HEAD, clean.
- Package pin: OpenWiki `d4e94ab513ab13908c6b61346b23dc17bbd59b1f`, version `0.2.0`.
- Fully patched upstream workbench: `/tmp/openwiki-links.J7M9qU`.
- Red: focused Vitest run failed for missing `links.ts`, unrecognized `links` CLI target, and dropped onboarding source.
- Green: upstream full suite passed, 36 test files / 363 tests; focused changed suite passed, 6 files / 63 tests; typecheck and changed-file ESLint passed.
- Fresh source: `nix develop -c pkg-check openwiki` applied the full patch stack, passed typecheck, and passed 82 declared tests.
- Package: `nix build .#openwiki` passed for Darwin arm64.
- Built CLI: isolated HOME showed `openwiki ingest links`, skipped an empty queue without credentials, and wrote connector directory/state/gitignore at `0700`/`0600`.
- Structural/policy: `nix develop -c ast-grep scan packages/` and `hey check` passed. `hey check` also passed Darwin evaluation, package harness/policy, and ast-grep tests.
- Agent gates: `hey agent-audit-tests` and `hey agent-finish --worklog .agents/worklogs/openwiki-links-input.md` passed all applicable checks.
- Landing: rebased onto `origin/main`, `br sync --flush-only` had no issue changes, and branch push hooks passed.
- Full upstream `pnpm lint:check` remains non-green because existing iMessage/ingestion patch tests have 11 lint errors; changed production/test files passed focused ESLint, and the new ingestion assertion adds no lint error.

## Reviews

- Plan review blocked: `hey agent-review plan --active-model-family gpt --worklog .agents/worklogs/openwiki-links-input.md` returned `RUNTIME: Authentication required` on 2026-07-18. No credentials were modified.
- Landing review blocked by the same access boundary: `hey agent-review landing --active-model-family gpt --worklog .agents/worklogs/openwiki-links-input.md` returned `RUNTIME: Authentication required` on 2026-07-18. No credentials were modified.

## Feedback

None.

## Remaining work

None.

## Commits

- `9caa48c0a4` — `feat(openwiki): add links input connector`
- `5166c7dda8` — `docs(agent): record OpenWiki links verification`
