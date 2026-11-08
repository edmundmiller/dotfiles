# NUC orb provider pilot

Status: authorized candidate preparation; not deployed. Current publication and
deployment evidence stays in the existing agent-run receipt.

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
active 2-CPU/4-GiB orb. Leave public portals disabled. Keep existing runners,
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
