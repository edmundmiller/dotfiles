---
purpose: Choose and stage a self-hosted Amp orb provider without disrupting home services.
applies_to: NUC and UNAS rootless providers, storage safety, and Meshify execution choices.
entrypoint: Submit the authorized exact-revision NUC deployment with --orb-pilot.
verification: Exercise spawn, pause, resume, snapshots, and delete in the approved account.
update_when: Amp's dispatch contract or the selected host and isolation policy changes.
---

# Self-hosted Amp orbs

## Recommendation

Keep Amp-hosted orbs as the default and the Mac desktop app unchanged. Allow up
to two bounded small orbs on the NUC after live capacity checks. Keep the existing runners.
UNAS allows one active small orb after its separate activation and registration
gates below. Do not change Meshify's sleep policy to make it an
always-on provider. A provider adds separate thread checkouts;
it does not give those threads the host's working tree or service credentials.

`hosts/_amp-orbs.nix` declares the dedicated account, CLI installer, dispatcher,
and user unit for both hosts. It enables `programs.nix-ld` so Amp's downloaded
Linux CLI can run without patching its mutable executable after each update.
`hosts/nuc/amp-orbs.nix` owns its ZFS storage;
`hosts/unas/amp-orbs.nix` owns its bounded NVMe storage. The controller waits for
registration before it starts. Repository
wiring is not proof that the host adopted it. See the task checkpoint for current
authorization and delivery evidence.

## UNAS storage and activation gates

UNAS restoration was accepted on November 8. A read-only November 10 inventory
confirmed the accepted migration closure, 12 online logical CPUs, 31.15 GiB
OS-visible RAM, 29.16 GiB available RAM, and 389.09 GiB free on the NVMe Btrfs
filesystem. These are point samples, not reserved resources or activation authority.
No failed units or active backup/restore processes were observed; backup timers
remain armed. Recheck them before an approved deployment.

The NVMe filesystem has no qgroups enabled. Do not enable quotas across the
restored NAS to bound this one workload. The UNAS module creates only a sibling
`@amp-orbs` subvolume on the verified NVMe filesystem. It preallocates a 64-GiB
NOCOW file, formats that new file as ext4 without discarding its allocation,
and mounts it at `/var/lib/amp-orbs`. It never formats a block device. The
initializer requires at least 100 GiB free before allocation and refuses an
unexpected filesystem identity, unrelated contents, or an existing account home
that the mount would hide. Existing images must have the expected size, type
and label; they are never reformatted automatically.

The image bounds CLI state, images, snapshots and checkouts together. The NAS
controller sets `AMP_ORB_MAX_ACTIVE=1`, limiting starts and resumes to one active
orb with two CPUs and 2 GiB RAM. The NUC retains its two-orb default. Both retain
the 2-GiB host reserve and 20-GiB storage floor. Neither bulk nor preservation storage is
used. Hourly Btrbk snapshots select `@root`, `@home` and `@var`; they do not
recurse into the separate `@amp-orbs` subvolume. Existing Restic include paths
also exclude it. Do not add orb images to NAS replication or change existing
backup policies. Retained orb disks are not independently backed up: commit and
publish valuable work, and never prune unfinished or retained work automatically.

The Nix configuration does not register a provider or create its readiness marker.
After exact-candidate validation and separately approved `hey unas` activation,
verify the bounded mount, actual rootless limits, backup/share continuity and
disk-preserving lifecycle. Then register `unas-orbs` with its own token in the
dedicated account through private interactive input. Never copy the NUC provider
token: independent controllers cannot share local disks or snapshots. Provider
registration and workspace settings changes need explicit approval. Keep public
portals disabled and do not change the default provider during installation.

## Evidence and limits

Assessment on 2026-11-08 used the official
[self-hosted orb documentation](https://ampcode.com/docs/orbs/self-hosted),
[sizes and costs](https://ampcode.com/docs/orbs/sizes-and-costs), and these sources:

- `hosts/nuc/default.nix` declares the personal `nuc` runner as `emiller` and
  a separate, restricted `nuc-shared` account and runner. The runner inventory
  confirmed `nuc` online, plus a vault runner on NUC and two Mac app runners.
  It did not show `nuc-shared` or Meshify. Absence is not proof of removal.
- `hosts/nuc/hardware-configuration.nix` records six CPU cores. The NUC also
  hosts Home Assistant, Hermes, and other services. RAM, free disk, and current
  load have not been measured on the host.
- `hosts/unas/default.nix` and `nas.nix` own ZFS recovery, backups, and NFS.
  They declare Rex and Podman, not an Amp runner or provider. Protect storage
  availability instead of adding build and image churn.
- `hosts/meshify/omarchy/README.md` and its user runner unit describe the
  current Omarchy workflow and suspend after 15 minutes without user input.
  The NixOS configuration records AMD hardware, but is not evidence of the
  currently booted OS. More compute does not make a sleeping provider reliable.
- Personal and `the-millers` workspace provider inventories were both empty.

The initial assessment ran in an Amp-hosted orb without direct NUC access. Live
capacity and backend checks now use the existing privileged deployment workflow,
not a new runner or new tailnet credentials.

## Tradeoffs

| Execution choice               | What it buys                                                                                                                    | What it costs or cannot do                                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Existing NUC or Meshify runner | Host tools, existing checkouts, local network and hardware access under its account                                             | Shared host state and account permissions; not an isolated per-thread machine; host must remain online                  |
| Mac desktop app                | Existing Mac environment and desktop access                                                                                     | Keep this approach; Linux containers do not replace native macOS tools                                                  |
| Amp-hosted orb                 | Separate checkout per thread, disk and memory resume, prepared project snapshots, no home-server capacity or maintenance burden | Compute charges; no implicit home LAN, SSH config, tailnet identity, or HA token                                        |
| Self-hosted Podman orb         | Separate container and checkout per thread on home compute; permitted LAN routes without a tailnet client inside each orb       | Shares the host kernel; CPU, RAM, disk, network access, updates, image retention, and outages become our responsibility |

Podman stop/start preserves disk, not memory. Shell sessions and desktop apps
disappear; portal services need restart on wake. Use Amp-managed services and
`.agents/resume`, not background shell processes. Local image snapshots can skip
project setup on the same host, but do not make multiple independent hosts a
single provider. Run one controller per token, with separate tokens for any
future hosts.

Self-hosting moves tool execution and stored disks home. Amp still runs the agent
and model inference remotely and receives tool output, read file contents, diffs,
and attachments. It is not offline or entirely private AI. Only outbound HTTPS
and WSS are needed; do not open inbound ports. Keep public portals off. A portal
can otherwise expose a service whose container can reach the home network.

As of the assessment, Amp lists a hosted small orb at $0.17/hour and medium at
$0.33/hour. Paused hosted orbs cost nothing. The docs say self-hosted compute is
free on Hobby, Individual, and Teams after November 13; Enterprise pays the
standard compute rate after that date. Model usage, electricity, storage, and
administration are separate. Confirm the workspace plan before assuming savings.

## Prepared pilot

`config/amp-orbs/dispatch.sh` uses rootless Podman under a dedicated account.
It admits at most two running managed containers on the NUC and one on UNAS.
New containers have two CPUs
and 2 GiB RAM with no extra swap allowance. Running 3-GiB containers keep their
limits until they stop. After admission succeeds, stopped containers adopt the
current 2-GiB/two-CPU limits before restarting, without replacing their disks.
Admission caps assigned memory at 5 GiB and CPU at four cores. It reserves four
host CPUs and checks that available host RAM covers every running container's unused allowance,
the incoming container's full limit, and another 2 GiB for host services. Missing
resource readings fail closed. An already-running orb can reconnect without
another capacity reservation. These are admission checks, not a promise that
unrelated host workloads cannot later consume the remaining RAM.

Containers retain 1 GiB shared memory and a PID limit. Spawn and snapshot require
20 GiB free in container storage. The lifecycle lock also serializes admission.
It implements disk snapshots and repeatable lifecycle jobs, refuses containers
without its ownership label, and passes bootstrap tokens only through exec.
Podman commands close the lock descriptor before execution so detached conmon
and fuse-overlayfs processes cannot keep the lifecycle lock after dispatch exits.

At 2026-11-09 20:55:55 UTC, the live NUC reported eight CPUs, 7,279,944 KiB
available RAM, no swap, and a 1.23 one-minute load average. The existing 3-GiB orb
used 486,002,688 bytes, and orb storage had 51,724,672 KiB free. A second 2-GiB orb
fits that sample while a pair of 3-GiB allocations would not retain 2 GiB of host
headroom at their full limits. Each spawn rechecks current capacity. Large builds
should continue using hosted orbs. Do not archive unfinished review work merely
to free a slot or automatically prune retained disks.

The dispatcher grants no host mounts, container socket, host networking, devices,
or privileged mode. These limits do not isolate the LAN or prevent kernel
exploits. Rootless Podman resource enforcement requires working cgroup v2
delegation. Validate actual limits before trusting them. Use a dedicated VM if
untrusted repositories or stronger protection of home services are required.

The NUC module creates only `zroot/system/amp-orbs`, mounted at `/var/lib/amp-orbs`
with a 175-GiB quota. CLI state, images, snapshots, and checkouts share this limit.
It refuses to mount over a non-empty existing home or adopt a dataset with a
different mountpoint or quota. The dispatcher's free-space check is an additional
admission guard. UNAS uses its separate bounded local image described above;
do not use bulk/preservation storage or add GPU/USB passthrough.

For an existing NUC dataset at a former 64-GiB or 96-GiB quota, run `hey nuc:orb-quota`
with approval before deploying the 175-GiB configuration. This changes the persistent
ZFS property without restarting containers or deleting disks. It refuses other
hosts, mountpoints, and quotas. The 20-GiB admission threshold stays unchanged.
The quota does not reserve pool space; other datasets can limit available storage
before the orbs reach 175 GiB.

The candidate user unit is `config/amp-orbs/provider.service`. It runs only the
provider controller. Rootless containers and images persist in the dedicated
account's Podman storage, separate from existing rootful home-service containers.
Do not enable prune jobs in that account. Archive pauses a thread but does not
delete its container. Project snapshot images also require deliberate retention
management; never run a blanket container/image prune to recover space.

## Approval and installation boundary

Obtain approval before publication, activation, or provider registration. Keep
hosted orbs as the default and public portals disabled. Do not reuse `emiller`,
`amp`, their credentials, their home directories, or the rootful Podman socket.

The existing `Deploy NUC` workflow has an opt-in `orb_pilot` input. Request it
through `scripts/nuc_shipping.py request --orb-pilot` with the exact published
SHA, existing receipt, owner thread, and explicit deployment authority. Its
usual exact-main CI, identity, and deployment-lock guards still apply. Other
NUC deployments do not run the pilot's capacity or smoke tests by default.

`scripts/amp-orb-pilot.sh preflight` checks host identity, cgroup v2, at least four
online CPUs, 5 GiB available RAM, and 100 GiB free on local `/var/lib` storage before
activation. The post-deploy `verify` mode checks actual rootless resource limits,
disk resume, and snapshot cloning with Amp's image. It deletes only its disposable
smoke containers and snapshot. This is backend evidence, not an Amp thread test.

For an explicitly approved inherited-lock repair, add `--recover-orb-pilot` to
the shipping request alongside `--orb-pilot`. After live capacity passes, the
workflow stops the dedicated provider and only its labeled containers, preserving
all disks and images. It verifies the existing lock is released without unlinking
it, then activates the tested dispatcher and runs backend verification before
starting the provider again. This interrupts pilot shell processes, not home
services. A failure leaves the controller stopped for investigation. It is not
enabled by default or by diagnostic-only requests.

To investigate lifecycle failures without rebuilding or restarting anything,
dispatch the same workflow with `operation=orb-diagnostics` and its exact
published main SHA. It streams `scripts/amp-orb-pilot.sh diagnostics` through
the existing OIDC route. It reads controller state, only labeled containers'
running/start/finish fields, and recent controller journal entries. Amp's
redactor runs in the dedicated account before journal text leaves the NUC.
It does not print container environments, stop containers, or touch HA.

The module enables account lingering, installs Amp's mutable CLI independently,
and places the dispatcher at `/etc/amp-orbs/dispatch`. Provider registration must
run on the NUC in this account so the CLI stores its token there. Never paste the
token into a Space or thread, commit it, or pass it as a command argument.

After deployment, an operator with existing NUC access completes authentication
and registration interactively:

```bash
sudo -u amp-orbs -H bash -lc '~/.amp/bin/amp login && ~/.amp/bin/amp orb provider create --workspace the-millers nuc-orbs'
sudo -u amp-orbs -H mkdir -p /var/lib/amp-orbs/.config/amp
sudo -u amp-orbs -H touch /var/lib/amp-orbs/.config/amp/orb-provider-ready
uid=$(id -u amp-orbs)
sudo -u amp-orbs env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user start amp-orb-provider.service
```

Leave normal repository setup enabled. No orb types are required; if a type is
added, the dispatcher accepts only `small`. Select `nuc-orbs` explicitly for the
test thread, not as the workspace default.

## Acceptance and rollback

The local preparation can validate shell syntax, unit syntax, and simulated
dispatch lifecycle behavior. Those checks do not prove Podman compatibility or
live host safety. A pilot is not ready until the approved host passes all of:

1. A test thread starts on the provider and reports Linux, a separate repository
   checkout, the expected CPU/memory limits, and no host filesystem mounts.
2. A second simultaneous thread fails admission without affecting the first.
3. Pause and resume preserve an uncommitted sentinel file. A repeated pause and
   resume work. A snapshot produces a new thread without rerunning project setup.
4. A portal service returns after wake through the managed-service mechanism.
   Host loopback is not container loopback. LAN access does not confer HA API
   authorization, USB/Bluetooth access, or Matter discovery across container NAT.
5. Deleting only a disposable test thread removes its container; archiving it
   does not. Repeated delete is harmless. Inspect retained snapshot images.
6. Observe HA/Matter health, host load, and disk before and during the pilot.
   Do not run stress tests that jeopardize home automation.

To stop the pilot, stop and disable only `amp-orb-provider.service` in its
dedicated account. This stops future lifecycle handling, not running containers.
Inspect and stop only its labeled containers to release compute; preserve all
disks. Restore the provider before expecting paused threads to resume. Revoke
provider access in Amp only with separate approval. Keep existing runners and
the hosted default throughout so repair access does not depend on the pilot.
