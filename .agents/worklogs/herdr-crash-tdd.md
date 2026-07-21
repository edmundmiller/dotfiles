# Worklog: herdr-crash-tdd

Status: active

## Objective

Diagnose the fresh Herdr crash, add a deterministic regression test for the observed failure, fix the root cause, and verify the packaged Darwin runtime no longer crashes. Stop only after focused tests, runtime smoke, `hey check`, and upstream publication succeed.

## Decisions

- Source ownership is `overlays/herdr/`; runtime executable is Nix-managed and must not be edited directly.
- Start from captured crash evidence and construct a red-capable test before hypotheses.

## Evidence

- `hostname; uname -a; command -v herdr; herdr --version`: `MacTraitor-Pro.local`, Darwin arm64, `/etc/profiles/per-user/emiller/bin/herdr`, `herdr 0.7.4`.
- `herdr_status`: client/server 0.7.4, protocol 16, compatible, server running.

- Crash report `herdr-2026-07-19-180402.ips` is a SIGABRT in `terminal.PageList.resizeCols`; binary UUID matches the active Nix store executable.
- Symbolication resolves the panic to `Page.setGraphemes`' `@memcpy` length check after `BitmapAllocator(16).alloc`; existing `0010` cursor-scrollback guard is present and not the failing path.
- Isolated PageList probes for multi-codepoint capacity growth, cursor-to-scrollback, and a twice-run `80×24 → 197×52` multi-page replay all pass.
- A full Herdr Rust test using 2,000 styled Unicode lines and 200 alternating `197×52 ↔ 157×42` reflows passes.
- An isolated Herdr server rendered the recorded crash-time OMP session, then replayed the actual `80×24 → 224×53 → 157×42` client transition and focus change to a second workspace and back. It did not crash.
- A second isolated replay rendered the recorded OMP session and exercised `224×53 → 157×42 → 80×24` client reconnects plus the focus transition. It did not crash.
- The full Unicode reflow test also passes in the production-equivalent `ReleaseSafe` libghostty build.
- Static analysis of the resize path identified three SIGABRT candidates in `PageList.resizeCols`/`increaseCapacity`: (1) `@memcpy` length check in `Page.setGraphemes` (page.zig:1527, covered by patch 0011); (2) `unreachable` at `PageList.zig:1601` firing after `setGraphemes failed` log when `setGraphemes` returns an error despite the capacity probe; (3) `@panic("unexpected clone failure")` at `PageList.zig:3358` when `cloneFrom`'s internal `setGraphemes` fails during capacity doubling. The probe at `PageList.zig:1573-1583` only exercises `grapheme_alloc` (byte buffer); `grapheme_map` capacity is checked once at `PageList.zig:1562` and grown indirectly via `grapheme_bytes` derivation in `Page.layout`. Bitmap allocator fragmentation (documented in `bitmap_allocator.zig:8`) is the leading candidate for a probe-success-then-setGraphemes-failure gap.
- Patch `0012-grapheme-crash-diagnostics.patch` adds error-path state dumps at sites (2) and (3): grapheme count/capacity, alloc capacity/used bytes, `cps_len`, cell content tag/codepoint, and old/new `grapheme_bytes`. Built cleanly to `/nix/store/sirw3wpsvbanqw3ms6pawbfmwr73ryms-herdr-0.7.4`. **0012 is now live**: activated via `herdr server live-handoff --import-exe /etc/profiles/per-user/emiller/bin/herdr --expected-protocol 16 --expected-version 0.7.4` (handoff completed, 29 panes preserved, `herdr_status` running/compatible). Old PID 70101 replaced by live PID 18228 running the 0012 binary (`/nix/store/sirw3wpsvbanqw3ms6pawbfmwr73ryms-herdr-0.7.4/bin/herdr`, mtime 1969 Nix epoch, 16,088,792 bytes). No `hey re` / sudo needed unless the Nix profile itself changes.
- A synthetic saturated-capacity harness in a scratch `/tmp/herdr-full-probe` build produced `FAIL (TestUnexpectedResult)` with `EXIT=1` (not SIGABRT/134), but emitted **no `[resize` marker** — meaning it failed at a pre-resize setup assertion (likely `totalPages() >= 2` after `growRows(20)` on an `init(80, 2, 0)` screen, where 22 rows likely fit a single default page) and never reached `resize()`. This run established **nothing** about the production resize crash path; the harness was structurally broken about page capacity. Scratch dir and logs cleaned up. The advisory correctly notes the synthetic path is not a valid reproduction.
- Static analysis refinement: site (1) at `page.zig:1511` (`if (slice.len != cps.len) @panic`) is **dead code** — `BitmapAllocator.alloc` (bitmap_allocator.zig:104) returns `ptr[0..n]` where `n == cps.len`, so `slice.len == cps.len` is tautological and the 0011 check can never fire. The Apple crash report says **SIGABRT**, which is Zig `@panic`/`unreachable` → `abort`, not a memory fault (SIGSEGV/EXC_BAD_ACCESS). Combined, this narrows the real crash to site (2) (`unreachable` at PageList.zig:1615, fired when `setGraphemes` returns `GraphemeAllocOutOfMemory` or `GraphemeMapOutOfMemory` after the capacity probe at 1562/1585) or site (3) (`@panic("unexpected clone failure")` at PageList.zig:3390, fired when `cloneFrom`'s internal `setGraphemes` fails). Both are covered by the live 0012 diagnostic. **Disproven hypotheses:** (a) "src page destroyed/recycled mid-reflow" — `destroyNode(row.node)` at PageList.zig:1146 runs AFTER `reflowRow` returns at 1140, so `cps` is consumed while the src page is alive. (b) "src_page aliases self.page" — src pages are orphaned originals from the pre-surgery list; dst pages are freshly `createPage`'d nodes; each page has its own `memory` buffer, so `@memcpy` at page.zig:1525 has no overlap risk. (c) "probe grows wrong dimension" — `grapheme_map` capacity is derived from `cap.grapheme_bytes` via `ceilPow2(ceilDiv(grapheme_bytes, grapheme_chunk))` (page.zig:1740-1747), so `increaseCapacity(.grapheme_bytes)` grows both the byte buffer AND the map. The remaining question is why `setGraphemes` or `cloneFrom` fails after a capacity increase that should provide sufficient room — bitmap allocator fragmentation during `cloneFrom`'s sequential `setGraphemes` calls is the leading remaining candidate, but cannot be confirmed without the diagnostic log. The existing test at PageList.zig:13744 ("resize reflow grapheme map capacity exceeded") covers the map-capacity path with 1-cp graphemes and passes; a multi-codepoint grapheme test targeting bitmap fragmentation could be written but without the diagnostic log identifying which site fires, a targeted red regression cannot be written. The 0012 diagnostic remains the path to the proven invariant.
- cloneFrom structural analysis: `clonePartialRowFrom` (page.zig:911-918) calls `self.setGraphemes(dst_row, dst_cell, cps)` with **NO capacity probe and NO trial alloc loop**, unlike the writeCell reflow path (which has both at PageList.zig:1562 and 1572-1587). It relies on the assumption at 3373-3376 that "we're only increasing capacity so this should never be possible." However, `increaseCapacity` creates a **fresh page with all-free bitmap** — `cloneFrom`'s sequential `setGraphemes` calls pack from the start with no fragmentation, total bytes needed ≤ original capacity < doubled capacity, and `grapheme_map` capacity also doubles (derived from `grapheme_bytes` via page.zig:1740-1747). So cloneFrom failure (site 3) also seems structurally impossible from static analysis. **Every traced path shows the failure "shouldn't be possible"** — the diagnostic patches exist precisely because the production crash state differs from what static analysis can predict (likely a state corruption or edge case in the bitmap allocator or map that only manifests under real terminal workloads with specific grapheme patterns). The 0012 diagnostic is the only remaining path to the proven failing invariant. No further static analysis is productive.
## Reviews

- Plan gate blocked before review by `RUNTIME: Authentication required`; no findings were produced.

## Feedback

None.

## Remaining work

The crash remains non-reproducible across all probes, replays, and the synthetic saturated-capacity harness (the last failed at a pre-resize setup assertion and proved nothing about resize). No root-cause patch is justified yet. **0012 is now live** via `herdr server live-handoff --import-exe /etc/profiles/per-user/emiller/bin/herdr` (handoff completed; 29 panes preserved; `herdr_status` reports running/compatible). Both diagnostic patches (0011 covering the `@memcpy` site, 0012 covering the two error-path `unreachable`/`@panic` sites) are now armed in the running PID. Next step: capture the next failure from `~/.config/herdr/herdr-server.log` — the diagnostic block will identify which of the three candidate sites fires. Once identified, write a red regression against that specific invariant and replace 0011/0012 with the root fix. No `hey re` / sudo is needed unless the Nix profile itself changes.

## Commits

None.
