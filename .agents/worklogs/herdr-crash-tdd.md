---
purpose: Track Herdr PageList resize crash diagnosis and fix.
applies_to: overlays/herdr hyperlink reflow crash work.
entrypoint: overlays/herdr/patches/0013-hyperlink-string-chunk-ceiling.patch
verification: zig test-lib-vt -Dtest-filter=chunk_ceiling_repro ReleaseSafe; herdr smoke.
update_when: Fix, patch stack, or crash evidence changes.
---

# Herdr crash TDD

## Outcome

Stop Herdr SIGABRT on pane resize during hyperlink reflow.

## Stopping condition

ReleaseSafe no longer unreachable on `link dupe failed with capacity check`, with a locked regression.

## Evidence

- Crashes: `herdr-2026-07-18-200336.ips`, `herdr-2026-07-19-180402.ips`, `herdr-2026-07-19-182341.ips`
- Binary UUID match: `/nix/store/64d12g4d8fzgqn4nfz0ynzg7psgvv52i-herdr-0.7.4`
- PC `resizeCols+12544` is return-after-`reachedUnreachable` from cold path logging **`link dupe failed with capacity check`**
- Not grapheme `@memcpy`; hyperlink `PageEntry.dupe` after under-probe

## Root cause

`ReflowCursor.writeCell` probed string capacity with one allocation of `uri.len + id.len`.
`PageEntry.dupe` allocates URI and explicit ID separately; each is chunk-rounded (32 bytes).
For lengths like 33+33: probe needs 96 bytes, dupe needs 128 → OOM → ReleaseSafe `unreachable`.

## Fix

`0013-hyperlink-string-chunk-ceiling.patch`: require
`bytesRequired(uri) + bytesRequired(id)` before dupe.

## Verification

- `chunk_ceiling_repro` drives `PageList.resize(...reflow=true)` ReleaseSafe:
  - buggy probe: SIGABRT `link dupe failed with capacity check` (matches ips)
  - fixed probe: PASS (EXIT:0)
- Diagnostic patches 0011/0012 removed
- `nix build .#herdr` succeeds with 0013

## Remaining

- none (activated `/nix/store/l90w0m8vxz0jhm4g47jfv0wjhhw86h8s-herdr-0.7.4`, OSC-8 resize smoke OK)

## Activation

- `hey re` → active `herdr` = fixed store path
- isolated session OSC-8 + resize thrash: no panic / no ips
