# NUC orb provider pilot

Status: initial host wiring deployed; provider not registered or ready. A smaller
pilot is being prepared after the second run failed its capacity gate. Current
publication and deployment evidence stays in the existing agent-run receipt.

Request and approval:
https://ampcode.com/threads/T-01a1bb8c-9138-71d1-9002-41a01abffe05

## Authority and decisions

On 2026-11-08, Edmund first approved the pilot after HA recovery and capacity
checks. His later direct instruction was: "I approve everything, nothing is
mission critical, just do your best and get it running". Proceed with scoped
publication and deployment without waiting for HA recovery. Keep a live capacity
gate and hosted orbs as default. Do not ask for the same approval again.

The pilot is a workspace provider named
`nuc-orbs`, a dedicated rootless Podman account, bounded local storage, and one
active 2-CPU/3-GiB orb. Leave public portals disabled. Keep existing runners,
the Mac app, NAS duties, and Meshify sleep unchanged. Do not create another thread
or silently switch this orb to a runner. The approval does not authorize changes
to HA/Matter, tailnet policy, unrelated services, or destructive cleanup.

## Revision and preparation

Checkout: `/home/user/workspace/repo`, local `main`, base revision
`b0d9cea6` after reconciling the HA read-only diagnostics workflow. The pilot
checks run only for explicit deployments, never diagnostic-only requests.

Candidate files:

- `config/amp-orbs/dispatch.sh`
- `config/amp-orbs/provider.service`
- `hosts/nuc/amp-orbs.nix` and its import in `hosts/nuc/default.nix`
- `scripts/amp-orb-pilot.sh`
- Optional pilot input in `.github/workflows/deploy-nuc.yml`
- `scripts/nuc_shipping.py` and its existing tests
- `docs/runbooks/amp-self-hosted-orbs.md`
- This checkpoint.

The module installs a dedicated account, a new 64-GiB-quota local dataset, Amp's
CLI, and a registration-gated user unit. No provider was registered and this task
has not deployed anything at this checkpoint. The runbook owns setup, acceptance
checks, and non-destructive rollback. Existing exact-SHA deployment
uses GitHub's approved OIDC tailnet route, not direct SSH from this orb.

## Evidence and blockers

Initial preparation passed task-scoped `hey check`, Bash syntax, ShellCheck,
and `systemd-analyze verify`. A temporary stateful simulator
passed lifecycle and snapshot preservation, repeated operations, admission,
storage boundaries, ownership protection, and storage/listing error rejection.
These are local preparation checks, not live Podman or NUC verification. The new
wiring passed shipping unit tests, Bash syntax, ShellCheck, unit validation,
full NUC toplevel evaluation, and task-scoped `hey check` before reconciliation.
Reconciliation checks must pass again before candidate submission.

The Space supplied successful deployment of HA packaging fixes at
`432c255c3bd28e5e765ee2a064d65e673faa8513`:
https://github.com/edmundmiller/dotfiles/actions/runs/42495236743
It verified SSH/Tailscale and no failed systemd units, not integration health.
Do not claim HA, Bluetooth, or HomeKit recovered. Repair owner:
https://ampcode.com/threads/T-01a1bb8a-93a8-7608-912b-5d4a1b9cb9d5

This execution remains in an Amp-hosted orb. It has no NUC SSH configuration or
tailnet client. No runner execution has been selected. Live RAM, disk, load,
rootless cgroup delegation, and storage quota suitability remain unmeasured.

## Next action

Finish local validation, submit candidate CI, and resume on its completion event.
Land only the exact passing candidate, then request the exact-main deployment
through `scripts/nuc_shipping.py request --orb-pilot` and the existing receipt.
Subscribe to exact-SHA CI and deployment outcomes. Do not poll or create threads.

After deployment, inspect live capacity and backend smoke results. Registration
and provider credentials belong on the NUC in the dedicated account. If its Amp
sign-in needs a human, finish backend checks before asking for it. Never move a
provider token or personal runner credentials through this orb or the Space.

Report actual live test results or readiness to
`T-01a1b71a-94c9-7672-8791-b33976352643`, with the same findings in this thread's
final response. Distinguish local preparation, actual container smoke results,
and full Amp provider/thread tests. Name remaining gates and do not claim the
pilot operational without the runbook's live acceptance evidence.

## First live deployment and repair

The exact tested pilot landed and activated on NUC:
https://github.com/edmundmiller/dotfiles/commit/335d47369e65b9674d1abf7d4fb6d10c90d291f0
https://github.com/edmundmiller/dotfiles/actions/runs/42526100798

Live preflight reported eight CPUs, 6,320,824 KiB available RAM, 203,865,728 KiB
free local storage, and load averages 1.79, 1.94, 1.67. The new dataset was active
with quota 68,719,476,736 bytes and used 95,469,568 bytes. The host reported the
expected configuration revision after activation.

The backend smoke then failed before creating a container. Its dedicated account
inherited the SSH account's `/home/emiller` working directory, which rootless
Podman could not enter. The repair changes to the dedicated account's own home
before Podman starts. It does not weaken home permissions or reuse runner state.
Reconcile this repair onto the latest main, validate, submit candidate CI, and
request a new authorized exact-SHA pilot run after landing. Preserve the first
run's outcome in this receipt before recording the new request.

This is installed host wiring and successful live capacity evidence, not a
working provider. Container lifecycle/resource tests, NUC Amp authentication,
provider registration, and end-to-end thread tests remain unverified.

## Second live attempt and smaller pilot

The working-directory repair passed candidate CI and landed on main:
https://github.com/edmundmiller/dotfiles/commit/78da1c8b2bd235321eb3a532df99b567fc96e1dc
https://github.com/edmundmiller/dotfiles/actions/runs/42527893784

The next live attempt stopped before activation at the retained capacity gate:
https://github.com/edmundmiller/dotfiles/actions/runs/42528091834
It reported eight CPUs, 6,243,256 KiB available RAM and 204,487,808 KiB local
free storage. Available RAM was below the original 6-GiB requirement. No smoke
container ran, and the working-directory repair has not been verified live.

Reduce the pilot allocation from 4 GiB to 3 GiB for lighter workloads. Require
5 GiB available before activation to retain the same 2-GiB host headroom. Do not
stop unrelated services, loosen the storage gate, or alter the hosted default.
Publish through candidate CI, then submit a new exact-main deployment under the
existing scoped approval. Preserve both earlier run outcomes in the receipt.
