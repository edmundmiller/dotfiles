# Worklog: openwiki-imessage

Status: active

## Objective

Package a built-in, incrementally cursor-based OpenWiki iMessage connector using the pinned `imsg` runtime. Private connector state and normalized raw records stay under `~/.openwiki/connectors/imessage/`; only synthesized reviewed wiki pages may be written under `/Users/emiller/obsidian-vault/04_Resources`.

Stopping condition: focused upstream tests/typecheck, package harness, Linux evaluation, Darwin package/closure, approved-scope live ingest and repeat-idempotency checks, privacy checks, applicable launchd smoke, `hey check`, Darwin activation, activated-package smoke, landing gates, focused commits, rebase/push, upstream-current verification, and annotated tag all succeed.

## Decisions

- Keep upstream changes in ordered patch `packages/openwiki/patches/0002-imessage-connector.patch`; do not modify patch `0001` or vendor the temporary checkout.
- Reuse pinned `inputs.nix-steipete-tools` `imsg` v0.13.0 only on Darwin; keep Linux evaluation lazy.
- Require explicit chat-ID or participant scope. Both scopes use intersection semantics.
- Raw messages never enter the wiki or Git. Attachments remain metadata-only.
- Existing unrelated working-tree changes are user work and remain outside OpenWiki commits: `.beads/issues.jsonl`, `config/agents/rules/03-version-control.md`, and `overlays/herdr/default.nix`.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64, verified with `hostname` and `uname -a`.
- Upstream RED: nine expected failures (missing connector, command target misclassified, zero-file synthesis invoked, weak `.gitignore`).
- Upstream GREEN: focused Vitest suite passed 65 tests; `pnpm typecheck` passed.
- Fresh `pkg-check openwiki` applied `0001` then `0002`, passed typecheck, and passed 71 tests.
- Linux evaluation printed `openwiki`. Darwin package built; recursive closure contains `/nix/store/4zaazwcscfsl78d9xgihxblnryq9s9fh-imsg-0.13.0`.
- Live onboarding inspection reported zero iMessage instances, no legacy iMessage source, and zero approved chat IDs without printing any source values.
- `hey check`, `hey agent-audit-tests`, and `hey agent-finish` passed. Darwin rebuild activated successfully.
- Activated `openwiki --help` passed; `/run/current-system/sw/bin/openwiki` closure contains `imsg-0.13.0`.
- Existing all-source schedule is loaded at 02:00 under `com.openwiki.ingestion`; kickstart is deferred with live iMessage configuration because no approved chat ID exists.
- Onboarding now preserves saved iMessage instances. An isolated activated-package smoke found `imessage-1`, rejected its empty scope before any `imsg` access, exited nonzero, and left both raw and log directories empty.

## Reviews

- Plan approved by user.
- Plan gate attempted with `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/openwiki-imessage.md`; blocked before review by `RUNTIME: Authentication required`. No findings were produced. User approval remains the operative plan authorization.
- Landing review attempted with `hey agent-review landing --active-model-family openai`; blocked before review by `RUNTIME: Authentication required`. No findings were produced.

## Feedback

None.

## Remaining work

Blocked only on live Messages verification: no user-approved numeric chat ID is available. Per the approved privacy contingency, do not create `imessage-1`, run `imsg`, ingest messages, inspect raw records, verify live first/repeat behavior, or exercise iMessage under launchd until the user supplies approved ID(s).

## Commits

- `feat(openwiki): add private iMessage connector`
- `test(openwiki): capture iMessage onboarding regression`
- `fix(openwiki): preserve iMessage onboarding sources`
