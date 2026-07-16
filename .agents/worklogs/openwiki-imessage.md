# Worklog: openwiki-imessage

Status: complete

## Objective

Package a built-in, incrementally cursor-based OpenWiki iMessage connector using the pinned `imsg` runtime. Private connector state and normalized raw records stay under `~/.openwiki/connectors/imessage/`; only synthesized reviewed wiki pages may be written under `/Users/emiller/obsidian-vault/04_Resources`.

Stopping condition: focused upstream tests/typecheck, package harness, Linux evaluation, Darwin package/closure, approved-scope live ingest and repeat-idempotency checks, privacy checks, applicable launchd smoke, `hey check`, Darwin activation, activated-package smoke, landing gates, focused commits, rebase/push, upstream-current verification, and annotated tag all succeed.

## Decisions

- Keep upstream changes in ordered patch `packages/openwiki/patches/0002-imessage-connector.patch`; do not modify patch `0001` or vendor the temporary checkout.
- Reuse pinned `inputs.nix-steipete-tools` `imsg` v0.13.0 only on Darwin; keep Linux evaluation lazy.
- Require explicit chat-ID or participant scope. Both scopes use intersection semantics.
- Raw messages never enter the wiki or Git. Attachments remain metadata-only.
- Keep `windowHours` as a strict privacy/data-volume bound. If the previous successful run predates it, fail closed with the minimum explicit window needed to catch up.
- Scheduled ingestion uses a dedicated native launcher with fixed arguments, a cleared/reconstructed environment, a fixed approved vault, and Hardened Runtime signing; never grant FDA to the shared Bash wrapper.
- Existing unrelated working-tree changes are user work and remain outside OpenWiki commits.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64, verified with `hostname` and `uname -a`.
- Upstream RED: strict expected failures verified for connector presence, command classification, empty synthesis, private ignore rules, attachment paths, schedule privacy, bounded downtime, capped recovery, silent launchd denial, and shared launch identity.
- Upstream GREEN: focused Vitest passed 12 connector tests and typecheck passed. Fresh-source `pkg-check openwiki` applied both patches and passed typecheck plus 75 tests across eight files; `nix build .#openwiki` passed.
- Linux evaluation printed `openwiki`. Darwin package built with `imsg` plus its helper and both resource bundles adjacent to the executable.
- The approved scope contains 171 chats whose participant handles all match macOS Contacts: 90 direct and 81 group chats. No names or handles were printed.
- Live ingestion succeeded and synthesized only into the vault. Two immediate direct connector reruns both skipped with zero raw files.
- Raw run directories are `0700`; JSON/state files and the schedule log are `0600`; `.gitignore` is `*\n!.gitignore\n`. Existing attachment filenames were reduced to basenames and all raw runs now contain zero path-valued filenames.
- `hey check`, `hey agent-audit-tests`, and `hey agent-finish` passed. Darwin activation succeeded.
- Onboarding preserves saved iMessage instances. An isolated activated-package smoke found `imessage-1`, rejected its empty scope before `imsg`, exited nonzero, and left raw/log directories empty.
- An isolated activated-package smoke reproduced a 193-hour outage, exited nonzero before `imsg`, and printed the explicit 168-hour gap-reset recovery path.
- The launch agent now uses stable `/run/current-system/sw/bin/openwiki-launchd-launcher` and preserves log mode `0600`. Strict signature verification passed with Hardened Runtime flags; hostile `NODE_OPTIONS` and `DYLD_INSERT_LIBRARIES` self-tests passed. Unified TCC logs attribute the live denial to its resolved native binary, `/nix/store/7fgrx02y3sws3mvh18a5ynlznfyjwqcl-openwiki-launchd-launcher-1/bin/openwiki-launchd-launcher`, proving isolation from Bash.
- The system TCC database records the old Nix Bash identity disabled and the resolved launcher granted. The real loaded launchd job then ingested 36 scoped messages, synthesized `sources/imessage`, exited `0`, and preserved `0700` raw-directory plus `0600` raw-file/log modes.

## Reviews

- Plan approved by user.
- Plan gate attempted with `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/openwiki-imessage.md`; blocked before review by `RUNTIME: Authentication required`. No findings were produced. User approval remains the operative plan authorization.
- Landing review attempted with `hey agent-review landing --active-model-family openai`; blocked before review by `RUNTIME: Authentication required`. No findings were produced.

## Feedback

None.

## Remaining work

None.

## Commits

- `feat(openwiki): add private iMessage connector`
- `test(openwiki): capture iMessage onboarding regression`
- `fix(openwiki): preserve iMessage onboarding sources`
- `test(openwiki): capture attachment path leak`
- `fix(openwiki): redact attachment paths`
- `test(openwiki): capture wrapper bypass in launchd`
- `fix(openwiki): run schedules through Nix wrapper`
- `test(openwiki): capture public schedule logs`
- `fix(openwiki): protect scheduled ingestion logs`
- `test(openwiki): capture bounded downtime gap`
- `fix(openwiki): fail closed across ingestion gaps`
- `test(openwiki): capture silent launchd denial`
- `fix(openwiki): explain silent launchd denial`
- `fix(openwiki): package imsg runtime sidecars`
- `test(openwiki): capture capped outage recovery`
- `fix(openwiki): document capped outage recovery`
- `test(openwiki): capture launchd interpreter denial`
- `fix(openwiki): identify launchd interpreter for FDA`
- `test(openwiki): capture shared launchd identity`
- `fix(openwiki): isolate scheduled FDA identity`
- `test(openwiki): capture resolved launcher denial`
- `fix(openwiki): resolve launcher path for FDA`
