---
purpose: Preserve UNAS storage measurements and a proposed Btrfs migration plan.
applies_to: Review of the November 2, 2026 observations and future data-pool planning.
entrypoint: Read the dated evidence and constraints before the proposed migration.
verification: Original threads record completed checks and unverified claims.
update_when: New reviewed evidence changes storage, backup, or migration assumptions.
---

# UNAS storage benchmark and Btrfs migration plan

This is a planning document, not authorization to format disks, migrate data, or
deploy a new configuration. It preserves the November 2, 2026 observations from
the frozen reconciliation snapshot retained in the November 3, 2026 handoff.
The later Meshify recovery17 source was published separately in
[recovery preservation commit](https://github.com/edmundmiller/dotfiles/commit/395b08f57f101bffbcb54cb49d2d1809b08c83b2)
`395b08f57f101bffbcb54cb49d2d1809b08c83b2`. Publication does not establish that
this later source was deployed or matched the observed live generation.
Verify the live configuration and source before applying further host changes.

## Benchmark baseline

On November 2, 2026, after the backup and scrub stopped, Meshify tested the
active `datatank` mirror. The scrub repaired 0 bytes and reported no errors;
both mirror members were online. Before testing, four consecutive pool I/O
samples were zero. Load snapshots during the test do not prove that the system
was idle throughout.

| Test                                  |       Median |                Range | Runs |
| ------------------------------------- | -----------: | -------------------: | ---: |
| 512 MiB random write with final fsync |  137.72 MB/s |   130.13-144.28 MB/s |    5 |
| Buffered read and SHA-256             |  243.90 MB/s |   225.15-267.42 MB/s |    5 |
| Direct-request read and SHA-256       |  130.39 MB/s |   128.82-141.34 MB/s |    5 |
| Meshify to UNAS over SSH              | 532.243 Mb/s | 415.402-666.795 Mb/s |    5 |
| UNAS to Meshify over SSH              | 713.518 Mb/s | 703.052-768.881 Mb/s |    5 |

Storage tests wrote fresh incompressible data in a temporary directory on
`datatank/docs`. Each write included random data generation and a final fsync.
Each read included SHA-256 computation. The buffered read followed another
read and was likely cached. Direct I/O was requested, but cache bypass was not
independently established. The 512 MiB test is not a sustained larger-than-cache
disk benchmark.

The network test transferred 128 MiB per run over SSH through a direct
Tailscale peer connection. Timings included random generation, hashing,
connection setup, SSH and Tailscale. They are not raw link speeds or NFS/SMB
performance. Byte counts and transfer hashes matched, and the storage reads
matched a hash of each written file. This checks read consistency, not an
independent comparison against the random source. All commands succeeded, and
the test directory was removed. No limiting component was profiled.

An earlier single run overlapped backup I/O and reported 16.3 MB/s for writes
and 37.6 MB/s for direct-request reads. Those are contention-affected
observations, not idle-pool limits. See the [benchmark thread](https://ampcode.com/threads/T-01a19f90-b79e-73c6-8241-0dd8657e8b83)
for commands and the full results.

## Starting point and constraints

The [recovery thread](https://ampcode.com/threads/T-01a19e99-f55d-74cb-b24d-029e35c0a0bd)
last observed a 1 TB NVMe running `zroot`, an active `datatank` mirror on two
16 TB HDDs, and separate 18 TB and 6 TB HDDs carrying old pool metadata.
The 18 TB disk belonged to a degraded old pool; the 6 TB disk belonged to an
unavailable old pool. These observations are not a current inventory or
permission to erase either disk. Multiple pools share the name `datatank`;
identify any pool by GUID and disks by stable IDs, not discovery order or name.

The proposed scope is the data pool only. Keep NVMe `zroot` and its boot setup
on ZFS. Btrfs RAID1 stores two copies of data and metadata on different devices.
Across 18 + 16 + 16 + 6 TB, the theoretical upper bound is about 28 TB before
metadata, allocation constraints and operational free space. It protects
against any one drive failure, not every pair of failures. Btrfs RAID5/6 is
[marked unstable](https://btrfs.readthedocs.io/en/latest/Status.html) and is
not part of this plan.

The November 2 investigation recorded a failed scheduled Restic job with missing
decrypted password material and a DNS failure in its preceding hook. A later,
separate authenticated read-only rclone listing returned HTTP 401. Its
relationship to the Restic listing timeouts was unproven. A complete independent
restore was not verified. The recovery thread also reported a local Znapzend
backup from `zroot/user/home` to `datatank/backup/unas`. That local copy and
snapshots on `datatank` do not survive destruction of that pool.
The published recovery source cited above does not establish deployment or exact
correspondence to the live system. Neither source publication nor the historical
observations prove current backup coverage.

## Read-only inventory, November 2, 2026

At 22:37-22:38 Central, Meshify confirmed the UNAS identity over pinned SSH.
Both active pools were online and had completed scrubs without errors. The
active `datatank` mirror (GUID `5553631198264591155`) had 160.5 GB allocated.
Its `backup/unas/emiller` dataset accounted for about 232.9 GB of logical data;
most other data datasets were effectively empty. The separate NVMe `zroot`
(GUID `17576335980796613953`) held the OS and home datasets.

The old 18 TB pool (GUID `3888245209138560581`) was degraded with one of three
mirror members present. The old 6 TB pool (GUID `10347620144501571126`) was
unavailable with insufficient replicas. At 22:40-22:41 Central, the 18 TB pool
was imported read-only by GUID under a temporary name without mounting datasets,
forcing or rewinding. Its 12 filesystem datasets reported 2,506,752 bytes used
in total, with one `@blank` snapshot. No file contents were inspected; the
accounting suggests a nearly empty pool but does not prove recovery or rule out
historical data. The temporary pool was exported, and active pools stayed
healthy. The 6 TB pool could not be imported; both members of two mirror groups
were missing, so its contents and recoverability remain unknown. Neither
assessment authorizes erasing a disk.

The observed active-pool data fits within the roughly 6 TB upper bound of a
two-disk Btrfs RAID1 on the 18 TB and 6 TB disks, even without counting on ZFS
compression. This is a capacity estimate, not permission to erase them. Allow
space for metadata, growth, verification and retained history.

The 22:00 local home-replication snapshots had matching source and destination
GUIDs, but no restore was tested. Restic's timer was active; its most recent
successful backup and restore remained unverified, and the previous boot logged
failures. NFS and Time Machine were configured, but client access and restores
were not verified. Meshify's UNAS configuration contained uncommitted recovery
changes; exact correspondence to the deployed generation was not established.
See the [inventory thread](https://ampcode.com/threads/T-01a19f90-b79e-73c6-8241-0dd8657e8b83)
for details. Repeat the inventory before migration because usage and health change.

## Restic investigation, November 2, 2026

The 21:30 scheduled backup failed on the previous boot. Agenix logged that no
identity matched for three secret decryptions; Restic then reported that its
password file did not exist. DNS resolution also failed in the preceding hook.
On that boot, generation 18 mounted the home filesystem containing the identity
three seconds after the failed activation. Recovery subsequently deployed
generation 20 with `/home/emiller` needed for boot. On its observed reboot,
home mounted in the initrd before agenix decrypted the secrets. The then-current
identity fingerprint matched the configured recipients and all three secrets
were readable by the service user. This verifies one boot, not future boots or
a successful cloud backup. The later published recovery preservation commit
cited above includes that boot-order fix in `hosts/unas/backups.nix`; this
November 2 observation does not verify deployment of the later source.

The deployed backup command observed on November 2 listed `/home/emiller/sync`,
`/home/emiller/archive` and `/data/docs`. A read-only snapshot listing using the
then-current credentials timed out after 90 seconds, so neither the latest cloud
snapshot nor repository access was verified. A later endpoint check resolved DNS
and verified TLS, but
an authenticated read-only rclone listing returned HTTP 401. The rejected request
does not identify which credential or setting is wrong, and its relationship to
the Restic timeouts is unproven. Preserve the deployed identity ordering, verify
R2 credentials, and test a backup and an independent restore before migration.

## Proposed migration

1. Inventory the live machine read-only. Record pool GUIDs and health, device
   IDs and sizes, pool usage, datasets and snapshots, mountpoints, active
   services, NFS exports, Time Machine, and the actual backup configuration.
   Confirm the status and recovery value of both old pools before touching
   their disks. Decide whether historical ZFS snapshots must be preserved on
   independent ZFS storage; copying files to Btrfs does not translate them.
2. Establish independent backup capacity for all data that must survive,
   including the local home backup and boot recovery material. Repair and
   verify cloud backup separately if it is needed. Restore representative
   files and metadata from the independent copy and document the result. Do not
   count snapshots or the other side of a mirror as independent backups.
3. Choose a staging destination and layout. Prefer a separate set of disks with
   enough capacity to build and test a Btrfs RAID1 filesystem while retaining
   the entire ZFS mirror unchanged. The 18 TB and 6 TB drives are candidates
   only after their old pools have been dispositioned and their data protected;
   as a two-device RAID1 they offer at most about 6 TB before overhead. Check
   actual used data and free space before deciding if they suffice. If they do
   not, obtain additional staging or backup capacity. Do not break the active
   mirror or rely on an unverified single remaining copy as a shortcut.
4. Design Btrfs subvolumes, mountpoints, permissions, compression, scrub and
   snapshot retention against the actual dataset and service inventory. Plan
   replacements for ZFS send/receive and Znapzend where needed; `zroot` home
   snapshots cannot be received directly as Btrfs snapshots. Preserve and test
   NFS exports, Time Machine, ACLs, extended attributes, ownership, hard links
   and application-specific backup requirements. Avoid disabling data
   checksums through NOCOW without an explicit workload-specific decision.
5. Prepare NixOS and Disko changes in a separate reviewable task, based on the
   recovered live configuration. Test evaluation and a disposable VM or spare
   disks first. A Disko configuration can format devices; do not run it against
   existing disks as a verification step. Define a maintenance window and
   obtain explicit authorization before any host activation or destructive
   disk operation.
6. Copy data to the staged Btrfs filesystem while services remain available,
   then stop writers for a final synchronization. Verify file contents and
   metadata, mountpoints, exports, Time Machine access, snapshots, monitoring,
   scrub and a backup restore. Record checks and discrepancies before cutover.
7. Cut over only after verification and authorization. Retain the intact ZFS
   mirror as rollback until the user accepts the new system and an independent
   Btrfs backup has been restored successfully. Rollback requires stopping
   writers, restoring the old mounts and service configuration, and accounting
   for any writes made after cutover. Adding the original mirror disks to Btrfs
   destroys that rollback path; make that a separate authorized decision after
   the retention period and backup verification.

Open decisions: whether to retain old-pool data and historical snapshots,
where the independent backup and staging space will live, and the acceptable
cutover window and rollback retention period. No migration has been performed.
