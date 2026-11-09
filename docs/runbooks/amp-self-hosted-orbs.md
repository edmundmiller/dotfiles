---
purpose: Choose and stage a self-hosted Amp orb provider without disrupting home services.
applies_to: NUC provider pilot, NAS recovery, and Meshify execution choices.
entrypoint: Submit the authorized exact-revision NUC deployment with --orb-pilot.
verification: Exercise spawn, pause, resume, snapshots, and delete in the approved account.
update_when: Amp's dispatch contract or the selected host and isolation policy changes.
---

# Self-hosted Amp orbs

## Recommendation

Keep Amp-hosted orbs as the default and the Mac desktop app unchanged. Pilot a
single small orb on the NUC after a live capacity check. Keep the existing runners.
Do not put a provider on the NAS during storage recovery or change Meshify's sleep
policy to make it an always-on provider. A provider adds separate thread checkouts;
it does not give those threads the host's working tree or service credentials.

`hosts/nuc/amp-orbs.nix` installs the candidate account, storage, CLI, dispatcher,
and user unit. The controller waits for registration before it starts. Repository
wiring is not proof that the host adopted it. See the task checkpoint for current
authorization and delivery evidence.

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
It admits one running managed container, caps it at two CPUs and 3 GiB with no
extra swap allowance, sets 1 GiB shared memory and a PID limit, and requires
20 GiB free before spawn or snapshot. Its lock serializes lifecycle jobs.
It implements disk snapshots and repeatable lifecycle jobs, refuses containers
without its ownership label, and passes bootstrap tokens only through exec.
Podman commands close the lock descriptor before execution so detached conmon
and fuse-overlayfs processes cannot keep the lifecycle lock after dispatch exits.

The live NUC reported about 6 GiB available RAM across two preflights. The pilot
uses 3 GiB for lighter workloads so it can retain 2 GiB of host headroom without
stopping existing services. Large builds should continue using hosted orbs.

The dispatcher grants no host mounts, container socket, host networking, devices,
or privileged mode. These limits do not isolate the LAN or prevent kernel
exploits. Rootless Podman resource enforcement requires working cgroup v2
delegation. Validate actual limits before trusting them. Use a dedicated VM if
untrusted repositories or stronger protection of home services are required.

The NUC module creates only `zroot/system/amp-orbs`, mounted at `/var/lib/amp-orbs`
with a 64-GiB quota. CLI state, images, snapshots, and checkouts share this limit.
It refuses to mount over a non-empty existing home or adopt a dataset with a
different mountpoint or quota. The dispatcher's free-space check is an additional
admission guard. Do not use the recovering NAS or add GPU/USB passthrough.

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
