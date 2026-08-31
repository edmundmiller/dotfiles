---
purpose: Explain MacTraitor-Pro disk accounting and safe storage-pressure recovery.
applies_to: Unexpected disk growth or low free space on the personal Mac.
entrypoint: Run df and diskutil, then compare the top-level APFS ledger below.
verification: Re-run both commands after approved cleanup and verify retained data.
update_when: Storage layout, cleanup ownership, or the measured baseline changes.
---

# MacTraitor-Pro storage ledger

This is the durable record of the August 29–30, 2026 disk investigation. The
audit was read-only: it did not delete files, evict iCloud downloads, run Nix
garbage collection, remove worktrees, or remove simulator runtimes.

All values below are GiB (`2^30` bytes). macOS and `diskutil` also display
decimal GB, which is why the same disk can appear to be 1 TB, 994.7 GB, or
926.352 GiB.

## The rule that makes the numbers add up

Treat the SSD like one jar with smaller jars inside it. Add siblings only.
Never add a child to its parent:

- `~/Library` is already inside Home.
- iCloud's `Mobile Documents` is already inside `~/Library`.
- Codex worktrees are already inside `~/.codex`.
- Simulator runtime assets are already inside Data; mounted simulator disk
  images are views of those backing assets, not extra host capacity.

## Exact APFS snapshot

At 2026-08-30 20:11 CDT, the main APFS container was 926.352 GiB total and
908.333 GiB used. Only 18.019 GiB was free.

```text
50 columns = the whole 926.352 GiB container
[DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDNNNVVMMF]
 D = Data 774.097   N = Nix 58.214   V = VM 40.009
 M = macOS core 36.013              F = free 18.019
```

| Top-level sibling |         GiB | What it means                                                                |
| ----------------- | ----------: | ---------------------------------------------------------------------------- |
| Data              |     774.097 | Home directories, apps, global Library, caches, logs, and other mutable data |
| Nix Store         |      58.214 | Separate APFS volume; managed by Nix                                         |
| VM                |      40.009 | Live swap and VM files; workload-dependent                                   |
| macOS core        |      36.013 | System, Preboot, Recovery, Update, and APFS/unlisted overhead                |
| Free              |      18.019 | Unallocated container space                                                  |
| **Total**         | **926.352** | Rounded rows reconcile to the container ceiling                              |

Live source of truth:

```bash
df -h / /System/Volumes/Data
diskutil apfs list
```

`df -h` rounded this snapshot to 909G used and 19G available. `diskutil`
reported 975.3 decimal GB in use and 19.3 decimal GB unallocated. Those are the
same state in different units.

## The earlier detailed Data scan

The detailed scan completed earlier in the same investigation, while Data was
777.175 GiB. The machine continued changing during the audit, so this section
must not be added to the later 774.097 GiB Data value above.

| Data child                   |         GiB |
| ---------------------------- | ----------: |
| Home (`/Users/emiller`)      |     590.544 |
| System assets                |      43.579 |
| Other system and app data    |      94.740 |
| Protected or unclassified    |      48.312 |
| **Data at that measurement** | **777.175** |

The protected/unclassified row is an accounting remainder, not a cleanup
recommendation. macOS privacy protections prevented a complete traversal of
some system-owned directories.

### Home, without double counting

| Home child                   |         GiB |
| ---------------------------- | ----------: |
| `~/Library`                  |     205.713 |
| `~/.codex`                   |     137.164 |
| `~/src`                      |      60.764 |
| Other top-level home entries |      75.374 |
| `~/.local`                   |      35.467 |
| `~/.cache`                   |      20.657 |
| `~/.config`                  |      20.482 |
| `~/Pictures`                 |      21.149 |
| `~/obsidian-vault`           |      13.774 |
| **Home**                     | **590.544** |

### Library, nested inside Home

| `~/Library` child           |         GiB |
| --------------------------- | ----------: |
| `Mobile Documents` (iCloud) |      88.756 |
| `Containers`                |      35.368 |
| `Application Support`       |      25.415 |
| `Developer`                 |      20.113 |
| `Group Containers`          |       7.453 |
| Mail                        |       4.640 |
| Metadata                    |       4.621 |
| Messages                    |       4.096 |
| Photos                      |       4.064 |
| Caches                      |       3.738 |
| Other Library entries       |       7.449 |
| **Library**                 | **205.713** |

### iCloud, nested inside Library

| Local iCloud child    |        GiB |
| --------------------- | ---------: |
| Audiobooks            |     26.961 |
| Photos DTP            |     19.117 |
| Downloads             |     13.668 |
| Media                 |     11.604 |
| Google Drive material |      5.591 |
| Backups               |      3.354 |
| Castro                |      2.961 |
| Other audiobooks      |      2.113 |
| Framework data        |      1.277 |
| Other                 |      2.110 |
| **Mobile Documents**  | **88.756** |

These are local allocated blocks, not the total size of the cloud account.
Deleting an iCloud file in Finder deletes the cloud item too. **Remove
Download** is the supported way to keep the cloud copy while evicting the
local copy.

### Codex, nested inside Home

| `~/.codex` child                    |         GiB |
| ----------------------------------- | ----------: |
| Worktrees (183 at measurement time) |     116.528 |
| Archived sessions                   |       5.121 |
| Active session history              |       4.263 |
| Visualizations                      |       1.022 |
| Plugins                             |       0.398 |
| Other Codex state                   |       9.832 |
| **Codex**                           | **137.164** |

Archiving a Codex task does not by itself prove that its worktree was removed.
Never manually delete an active or dirty Codex worktree. Close it through the
owning task only after landing and ownership checks.

### Codex retirement outcome

On 2026-08-31, a second bounded inventory found 162 remaining Codex paths:
95 clean and 67 dirty. All unpublished and dirty work was published to verified
`archive/codex/*` refs before cleanup; the final disposition manifest is
`~/.local/state/codex-worktree-final-disposition-20260831T054149Z.json`.

The trace/runtime state was then transactionally backed up, encrypted, uploaded
to the NUC, read back, decrypted, decompressed, and fully listed before local
removal. The final archives are:

- `codex-final-state-20260831T121524Z.tar.zst.age`, SHA-256
  `858294097982b486ace98a8c3c6f1c5935a6346a8a53efbf4a94c58651a336ee`
- `codex-final-tail-20260831T122811Z.tar.zst.age`, SHA-256
  `ff4f2ff41425782c157bc967c4c09c284541f6b21e000a13b38905a0972b2fc4`

MacTraitor-Pro no longer enables the direct Codex module or Codex-backed
LaunchAgents. The applied configuration has no `codex` executable in `PATH`,
no `~/.codex`, and no Buzz Codex ACP tools. Free space reached 114 GiB before
the final verification builds, versus 25 GiB at cleanup start.

The concurrently started `hey gc` did not contribute to that recovery. It
remained blocked for more than eight hours in an uninterruptible root
`lsof -n -w -F n` child. A long-running GC with that process shape is stalled,
not evidence that Nix collection is progressing.

## What grew after the low point

The confirmed low at 2026-08-29 08:52 CDT was 737.132 GiB used and
189.219 GiB free. By the exact snapshot above, use had increased by
171.200 GiB.

The best reconciliation is approximate because macOS was live and the scans
completed at different times:

- About 88 GiB of iCloud files were locally materialized. File Provider
  metadata showed downloaded but not keep-downloaded files, and iCloud
  Optimize Storage was enabled.
- New swap accounted for roughly 33 GiB; VM later reached 40.009 GiB while
  concurrent work continued.
- Fourteen new Codex worktrees accounted for roughly 15.3 GiB.
- Recent `~/Library/Developer` growth accounted for roughly 10.8 GiB.
- Accessible recent `/private` files accounted for at least 7.1 GiB.
- Other recent source and cache growth accounted for roughly 8 GiB.
- The Nix volume later grew from about 51.9 GiB to 58.2 GiB while work
  continued.

The iCloud timing is strong evidence of background materialization, but the
retained logs did not identify the initiating process. The likely explanation
is that macOS used newly available free space to hydrate unpinned iCloud files;
a background reader remains possible. Do not present that inference as a
proven Apple policy decision.

There were no Data-volume snapshots hiding the missing space. The three
observed OS update snapshots were non-purgeable. Open-but-deleted files were
only about 2.4 GiB and were not the cause.

## What is hands-off versus reclaimable

| Category                  | Treatment                                                                                                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS core                | Hands off. Do not remove System, Preboot, Recovery, or APFS metadata.                                                                                                             |
| VM and swap               | Never delete swap files manually. Save work and reboot to let macOS recreate a smaller VM state; the result depends on workload.                                                  |
| Nix Store                 | Managed, not immutable. `hey gc` deletes old user/system generations and unreachable store paths, so use it only with explicit cleanup intent. Never delete `/nix/store` by hand. |
| iCloud local copies       | Use Finder **Remove Download** for verified cloud-backed files. Do not use `rm` unless cloud deletion is intended.                                                                |
| Codex worktrees           | Potentially reclaimable, but only after task ownership, dirty-state, and landing checks.                                                                                          |
| Xcode simulator runtimes  | Remove unused runtimes through Xcode Settings, not by deleting runtime files.                                                                                                     |
| Project/build caches      | Rebuildable in principle. Inspect a `mo purge --dry-run` first and verify `~/.config/mole/purge_paths` excludes cloud data.                                                       |
| Trace stores and DVC data | Treat as protected by default. Reclaim only after the backing remote and rebuild path are freshly verified.                                                                       |

## Recovery order

When free space is critically low, use one bounded action at a time:

1. Save work and reboot to reduce transient VM/swap pressure.
2. Re-run `df` and `diskutil`; record the new baseline.
3. Use Finder **Remove Download** on known large iCloud folders.
4. Close verified, landed Codex tasks so their owned worktrees can be retired.
5. Remove unused simulator runtimes through Xcode.
6. Preview rebuildable project artifacts with `mo purge --dry-run`.
7. Run `hey gc` only after deciding old Nix generations may be removed.

Aim for at least 150 GiB free before starting another broad audit. Near 99%
usage, run targeted scans serially. Concurrent full-tree scans and builds add
memory pressure, can grow swap, and make the ledger change while it is being
measured.

## Refreshing the ledger safely

Start with the cheap top-level checks:

```bash
df -h / /System/Volumes/Data
diskutil apfs list
diskutil apfs listSnapshots /System/Volumes/Data
```

Only if there is enough free space, inspect one bounded subtree at a time:

```bash
gdu -x -h --max-depth=1 /Users/emiller
gdu -x -h --max-depth=1 /Users/emiller/Library
gdu -x -h --max-depth=1 /Users/emiller/.codex
```

`gdu` reports allocated blocks, not necessarily unique physical bytes. APFS
clones, compression, sparse files, protected descendants, and live writes can
all create small differences. The APFS container ledger from `diskutil` is the
authority for total used and free space.
