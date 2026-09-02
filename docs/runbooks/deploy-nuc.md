---
purpose: Deploy and verify the NUC from the dotfiles worktree.
applies_to: NUC builds, switches, rollbacks, and deployment recovery.
entrypoint: Run `hey nuc dry-activate`, then `hey nuc`.
verification: Confirm the generation and relevant systemd services on the NUC.
update_when: NUC authentication, build location, commands, or verification changes.
---

# Runbook: Deploy to NUC

## Overview

The NUC is a NixOS server managed from this dotfiles repo — there is no CI-driven deployment. `hey nuc` evaluates and builds on the NUC for consistent cross-platform behavior: when run off-NUC it syncs the current worktree to a task-isolated `nuc:/tmp/dotfiles-worktree-$USER-$HEAD-{clean|dirty}-$UUID` snapshot and runs `nixos-rebuild` there; when run on the NUC it runs a local `nixos-rebuild`. NUC rebuilds pass `--max-jobs 1` to keep builds stable on the small host.

The canonical host source of truth is
`/Users/emiller/.config/dotfiles/hosts/nuc/default.nix` (tracked as
`hosts/nuc/default.nix`). Reusable Hermes runtime behavior is sourced from
`/Users/emiller/src/personal/agents-workspace`; generated profiles, systemd
units, and live Hermes homes are deployment artifacts, not configuration
sources. The gateway ownership patch is maintained at
`/Users/emiller/src/personal/agents-workspace/patches/hermes-agent/0006-gateway-cron-executor-ownership.patch`
and is consumed by the dotfiles overlay after the matching flake input is
landed.

## Prerequisites

- SSH access to `nuc` (configured in `~/.ssh/config` via home-manager)
- Tailscale connected (the NUC is on the tailnet)
- `/var/lib/opnix/secrets/githubNixToken` materialized by `opnix-secrets.service`
- A clean, committed working tree for `dry-activate`, `test`, or `switch`

Private `github:` flake inputs use `nix-private-github`. It reads the root-only
opnix credential and supplies Nix `access-tokens` without logging the token.
`hey nuc`, local NUC `hey re`, and `nixos-upgrade.service` use this wrapper.
Darwin `hey re` obtains the same narrow credential from the local `gh` keyring.
For a mutating remote dotfiles rebuild, the wrapper resolves `origin/main` over
Git transport and replaces the mutable `github:edmundmiller/dotfiles#...`
reference with that exact commit before Nix runs. A failed lookup or malformed
revision aborts before activation, so an API-rate-limit failure cannot select a
different cached dotfiles revision.

Before any remote check or mutating command, verify the target identity and
abort unless the remote hostname is exactly `nuc`:

```bash
set -euo pipefail
ssh nuc '
  set -eu
  hostname="$(hostname)"
  uname="$(uname -a)"
  printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"
  test "$hostname" = "nuc"
'
```

Mutating NUC rebuilds (`dry-activate`, `test`, `switch`, and `boot`) share the
NUC-side lock `/run/lock/nixos-deploy.lock`. Worktree deploys also send their
HEAD and merge-base; the wrapper compares them with live GitHub `origin/main`
before activation. Old synced snapshots without metadata and stale worktrees
are rejected. Every synced snapshot carries a fail-closed
`system.configurationRevision` with the exact dotfiles and agents-workspace
revisions. Dirty worktrees are refused for activation; `build` and `vm` remain
available for testing, carry a `-dirty` provenance marker, and do not take the
lock. Unique remote directories keep concurrent syncs from interleaving before
the activation lock is acquired. Each run prunes older revision-scoped
snapshots before syncing so at most five recent snapshots remain for follow-up
checks; legacy task directories do not match the cleanup boundary. An active
run holds a snapshot lease that pruning skips, then releases the lease and
re-prunes on remote-command exit. Abandoned leases age out after 24 hours.

If a deploy is rejected, update the worktree from `origin/main`, rebuild, then
retry. Inspect contention without deleting lock files:

```bash
set -euo pipefail
ssh nuc '
  set -eu
  hostname="$(hostname)"
  uname="$(uname -a)"
  printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"
  test "$hostname" = "nuc"
'
ssh nuc "sudo cat /run/lock/nixos-deploy.lock.owner"
```

The owner file includes caller, PID, time, working directory, and source
commits. Process exit or interruption releases the kernel lock; the next owner
overwrites stale diagnostics safely. After explicit review, bypass only the
stale-source check with `NUC_DEPLOY_ALLOW_STALE=1 hey nuc-wt switch`; the shared
lock still applies.

## Roll out agents-workspace

Run the rollout from a clean dotfiles host after committing the
agents-workspace change. The default deployment mode also requires tailnet
access to the NUC:

```bash
hey agents-rollout
```

The command pushes `agents-workspace`, updates and commits its exact source pin
and lock entry in dotfiles, pushes dotfiles, builds the pinned pair on the NUC,
and only then switches the NUC. It uses the same isolated worktree,
source-provenance, and deployment-lock path as `hey nuc`; it does not depend on
a checkout on the NUC.
Deployment modes also verify the NUC's tailnet SSH identity before either
repository is pushed; ship-only mode does not require NUC access.

Use a narrower final stage when needed:

```bash
hey agents-rollout --deploy-mode none          # ship and pin only
hey agents-rollout --deploy-mode build         # ship, pin, and remote-build
hey agents-rollout --deploy-mode dry-activate  # build, then preview activation
```

Production deployment remains intentionally operator-triggered rather than a
GitHub Actions job. The agents-workspace Amp project can join the tailnet with
Amp OIDC as an ephemeral `tag:amp-agents-workspace` node; the tailnet grants
that project tag Tailscale SSH access only as `emiller` on `tag:server` hosts.
From that project's orb, use its `scripts/deploy-nuc` wrapper. It passes the
orb checkout through `--workspace`, while this command remains the owner of
pinning, pushing, building, and activation. Keep broader CI on ship-only mode
unless it receives an equally narrow workload identity and an explicit
deployment approval boundary.

## Cron trigger ownership

Systemd is the sole recurring cron executor for Amos Burton, Betty, and
Scintillate. Their `hermes-<profile>-cron-tick.timer` units retain the checked-in
cadence: `OnUnitActiveSec=60s`, `AccuracySec=1s`, and
`RandomizedDelaySec=0s`. The services still invoke `hermes cron tick` (Betty's
existing `flock` wrapper remains in place); the timer cadence and direct CLI
path are unchanged.

Those three host-owned Hermes profiles set `cron.gateway_ticker=false`. Their
gateway services remain enabled for interactive Buzz conversations, but the
gateway does not start an in-process cron ticker. This setting is limited to
the timer-owned profiles; it does not alter Anne or Finn, the Desktop cron
ticker, or a direct `hermes cron tick` invocation.

Each timer service's `ExecStartPost` atomically publishes its fixed profile
path (`/var/lib/hermes-<profile>/.hermes/cron/executor.json`, also exported as
`HERMES_HOME`) with `kind=systemd`, its exact timer unit, `heartbeat_at`, and
`max_age_seconds=180`. `hermes cron status` and
`hermes cron list` treat that marker as authoritative when the profile has
`cron.gateway_ticker=false`: a fresh marker means the host executor is healthy;
a stale, invalid, or missing marker is unhealthy even when the gateway process
is running.

After a deployment, read back all three markers and machine-check the timer,
service, gateway, and `hermes cron status` ownership state. The JSON must name
the matching timer, contain a recent `heartbeat_at`, and set
`max_age_seconds` to `180`. Run the identity check before any of these SSH
commands; it aborts if the alias resolves to anything other than `nuc`:

```bash
set -euo pipefail
ssh nuc '
  set -eu
  hostname="$(hostname)"
  uname="$(uname -a)"
  printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"
  test "$hostname" = "nuc"
'
readback_dir="$(mktemp -d)"
trap 'rm -rf "$readback_dir"' EXIT
profiles=(amosburton betty scintillate)
timer_units=(
  hermes-amosburton-cron-tick.timer
  hermes-betty-cron-tick.timer
  hermes-scintillate-cron-tick.timer
)
service_units=(
  hermes-amosburton-cron-tick.service
  hermes-betty-cron-tick.service
  hermes-scintillate-cron-tick.service
)
gateway_units=(
  hermes-gateway-amosburton.service
  hermes-gateway-betty.service
  hermes-gateway-scintillate.service
)
for index in "${!profiles[@]}"; do
  profile="${profiles[$index]}"
  hermes_home="/var/lib/hermes-${profile}/.hermes"
  timer="${timer_units[$index]}"
  service="${service_units[$index]}"
  gateway="${gateway_units[$index]}"
  ssh nuc "sudo cat \"$hermes_home/cron/executor.json\"" >"$readback_dir/$profile.marker"
  ssh nuc "systemctl show \"$timer\" -p Id -p LoadState -p ActiveState -p UnitFileState -p OnUnitActiveUSec -p AccuracyUSec -p RandomizedDelayUSec" >"$readback_dir/$profile.timer"
  ssh nuc "systemctl show \"$service\" -p Id -p LoadState -p ActiveState -p Type -p User" >"$readback_dir/$profile.service"
  ssh nuc "systemctl show \"$gateway\" -p Id -p LoadState -p ActiveState -p UnitFileState -p MainPID" >"$readback_dir/$profile.gateway"
  ssh nuc "sudo -u emiller env HOME=\"/var/lib/hermes-${profile}\" HERMES_HOME=\"$hermes_home\" hermes cron status" >"$readback_dir/$profile.status"
done

python3 - "$readback_dir" <<'PY'
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys

readback_dir = Path(sys.argv[1])
profiles = ("amosburton", "betty", "scintillate")


def properties(path):
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        key, value = line.split("=", 1)
        values[key] = value
    return values


def seconds(value):
    if value in {"0", "0us"}:
        return 0.0
    units = {"us": 1e-6, "ms": 1e-3, "s": 1.0, "min": 60.0, "h": 3600.0}
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)(us|ms|s|min|h)", value)
    if not match:
        raise AssertionError(f"unparseable systemd duration: {value!r}")
    return float(match.group(1)) * units[match.group(2)]


now = datetime.now(timezone.utc)
for profile in profiles:
    timer_name = f"hermes-{profile}-cron-tick.timer"
    service_name = f"hermes-{profile}-cron-tick.service"
    gateway_name = f"hermes-gateway-{profile}.service"
    marker = json.loads((readback_dir / f"{profile}.marker").read_text(encoding="utf-8"))
    assert marker["kind"] == "systemd", marker
    assert marker["unit"] == timer_name, marker
    assert marker["max_age_seconds"] == 180, marker
    heartbeat = datetime.fromisoformat(marker["heartbeat_at"])
    assert heartbeat.tzinfo is not None, marker
    age = (now - heartbeat).total_seconds()
    assert -5 <= age <= marker["max_age_seconds"], (profile, age, marker)

    timer = properties(readback_dir / f"{profile}.timer")
    assert timer["Id"] == timer_name, timer
    assert timer["LoadState"] == "loaded", timer
    assert timer["ActiveState"] == "active", timer
    assert timer["UnitFileState"] == "enabled", timer
    assert seconds(timer["OnUnitActiveUSec"]) == 60, timer
    assert seconds(timer["AccuracyUSec"]) == 1, timer
    assert seconds(timer["RandomizedDelayUSec"]) == 0, timer

    service = properties(readback_dir / f"{profile}.service")
    assert service["Id"] == service_name, service
    assert service["LoadState"] == "loaded", service
    assert service["Type"] == "oneshot", service
    assert service["User"] == "emiller", service

    gateway = properties(readback_dir / f"{profile}.gateway")
    assert gateway["Id"] == gateway_name, gateway
    assert gateway["LoadState"] == "loaded", gateway
    assert gateway["ActiveState"] == "active", gateway
    assert gateway["UnitFileState"] == "enabled", gateway
    assert int(gateway["MainPID"]) > 0, gateway

    status_text = (readback_dir / f"{profile}.status").read_text(encoding="utf-8")
    assert f"External cron executor is running: {timer_name}" in status_text, status_text
    assert "Jobs fire through the host-managed systemd timer" in status_text, status_text
    assert "External cron executor is not running" not in status_text, status_text
    assert "Gateway is not running" not in status_text, status_text
PY
```

## Deploy

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
# Standard deployment
hey nuc

# Preview from the same remote-evaluation path
hey nuc dry-activate
```

## Dry Run (Preview Changes)

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
hey nuc dry-activate
# Equivalent compatibility aliases:
hey deploy-dry nuc
hey deploy-check
```

## Verify Deployment

After deploying, verify the NUC is healthy:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
# Quick system status
hey nuc-status

# Check specific services
ssh nuc "systemctl status home-assistant"
ssh nuc "systemctl status hermes-scintillate-desktop-dashboard.service"

# Check current generation
ssh nuc "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3"

# Prove the deployed dotfiles and agents-workspace revisions. The
# configurationRevision value must equal:
# dotfiles=<deployed dotfiles HEAD>;agents-workspace=<locked input revision>
expected_dotfiles="$(git rev-parse HEAD)"
expected_agents="$(nix flake metadata --json | jq -r '.locks.nodes["agents-workspace"].locked.rev')"
expected_revision="dotfiles=$expected_dotfiles;agents-workspace=$expected_agents"
ssh nuc "/run/current-system/sw/bin/nixos-version --json" \
  | jq -e --arg expected "$expected_revision" '.configurationRevision == $expected'
ssh nuc "readlink -f /run/current-system"

# View recent logs for a service
hey nuc-logs home-assistant.service 30
```

## Amp Remote Runner

The NUC serves remote Amp threads from the clean manuscript checkout at
`/home/emiller/src/fg/nascent-manuscript-main`. Amp's official installer owns
the mutable, self-updating CLI under `~/.amp/`; Nix owns the persistent
`amp-nascent-manuscript-runner.service`. Do not replace the unrelated CLIamp
package or copy Amp credentials from another host.

Bootstrap a new NUC home once, then complete Amp's displayed browser flow:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh -t nuc 'curl -fsSL https://ampcode.com/install.sh | bash && ~/.amp/bin/amp login'
```

After login and `hey nuc`, verify the service, runner identity, and checkout:

```bash
ssh nuc 'systemctl is-active amp-nascent-manuscript-runner.service'
ssh nuc 'systemctl show amp-nascent-manuscript-runner.service -p User -p WorkingDirectory -p ExecStart -p NRestarts'
ssh nuc '~/.amp/bin/amp version'
ssh nuc 'git -C ~/src/fg/nascent-manuscript-main status --short --branch'
```

The runner appears on ampcode.com as `nuc-nascent-manuscript` and allows remote
terminal control. Amp updates itself in the background; restart the service to
load an updated binary. If authentication expires, stop the service, run
`~/.amp/bin/amp login` interactively, and start it again. The runner inherits no
forwarded SSH agent, so GitHub fetch and push remain host-side operations until
the NUC has its own approved GitHub credential.

## Codex Remote Control

Codex remote control deliberately splits ownership. The foreground `codex` command remains
Nix-managed, while the daemon runs the official installer's mutable binary at
`$HOME/.codex/packages/standalone/current/codex`. The source of truth for this boundary is
`modules/agents/codex/AGENTS.md`.

The standalone installer is a one-time bootstrap for each NUC home directory; `hey nuc` does
not install it. On a new home, connect to the NUC and bootstrap remote control:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex remote-control start
codex remote-control pair
```

`pair` prints a short-lived code for the phone. Keep the Nix profile before
`$HOME/.local/bin` in `PATH`; do not remove the Nix Codex package.

Dotfiles do not install a systemd unit for this daemon. After a NUC reboot, run
`codex remote-control start` before pairing if daemon status is not `running`.

Verify both sides of the ownership boundary:

```bash
set -euo pipefail
command -v codex
codex app-server daemon version
```

`command -v` must resolve to `/etc/profiles/per-user/$USER/bin/codex`. Daemon status must
report `running` and a `managedCodexPath` under
`$HOME/.codex/packages/standalone/current/`.

### Project permission profiles

Each trusted project's `.codex/config.toml` owns its named profile:

- `mill-docs` may write `~/mill-docs` and its Git metadata, read
  `~/obsidian-vault`, and cannot read other host files or persist writes there.
- `obsidian-vault` may write `~/obsidian-vault` and its Git metadata. Its
  `.agents`, `.codex`, and `.qmd` policy directories remain read-only.

Both profiles may read the standalone Codex runtime and disable command network,
so fetch and push remain host-side operations.

The writable `~/.codex/config.toml` must trust `/home/emiller/mill-docs` and
`/home/emiller/obsidian-vault`. The bootstrap source is
`config/codex/config.toml`, but existing homes retain local Codex edits. Never
add a legacy `sandbox_mode`; it overrides named profiles.

Litter must start the thread in the target repository with `permissions` omitted
so the project default applies, or set to that project's named profile. A legacy
`sandbox` request overrides the project profile.

Smoke-test the command boundary:

```bash
set -euo pipefail
codex sandbox -C "$HOME/mill-docs" -P mill-docs test -w "$HOME/mill-docs"
codex sandbox -C "$HOME/mill-docs" -P mill-docs test -r "$HOME/obsidian-vault/AGENTS.md"
codex sandbox -C "$HOME/obsidian-vault" -P obsidian-vault test -w "$HOME/obsidian-vault"
codex sandbox -C "$HOME/obsidian-vault" -P obsidian-vault test -w "$HOME/obsidian-vault/.git"
codex sandbox -C "$HOME/obsidian-vault" -P obsidian-vault test -r "$HOME/.codex/config.toml"
(cd "$HOME/obsidian-vault" && qmd status)
```

The repository checks must exit zero, the host-config check must exit nonzero,
and qmd must report `$HOME/obsidian-vault/.qmd/index.sqlite`.

Permission profiles do not constrain hooks, plugins, browser tools, or MCP
services. Both profiles disable inherited `fff`. The vault retains qmd because
the app-server starts it in the vault and `.qmd` is read-only; its explicit
remote MCP services remain independent capabilities.

Recovery:

- Missing managed standalone install: rerun the official installer, then
  `codex remote-control start`.
- Missing `app-server-control.sock`: the daemon did not start; run
  `codex remote-control start` before `pair`.
- `failed to clean up stale arg0 temp dirs`: restore ownership with
  `sudo chown -R "$USER:users" "$HOME/.codex/tmp/arg0"`.

## Buzz community runtimes

The checked-in final state runs Scintillate, Finn, Amos Burton, Anne, and Betty
through `hermes-gateway-<profile>.service` with Hermes' native Buzz adapter.
Each also has a lifecycle-bound `buzz-presence-<profile>.service`. The presence
companion responds to nobody, has typing disabled, and launches `/bin/false`
instead of an agent. No `buzz-hermes-<profile>.service` ACP response lane may
remain active. Orchestrator stays internal with no Buzz identity, listener, or
presence companion.

Every Hermes profile, gateway, cron executor, one-shot automation, and dashboard
uses the same patched Hermes v0.21.0 (`v2026.8.31`) package. Canonical profile
settings enforce `approvals.mode=smart`, `approvals.cron_mode=deny`, automatic
tool-use enforcement, stall guards, Bot Mode protocol, and Hermes-owned loop
warning/hard-stop thresholds. The trusted one-shot lane remains an intentional
YOLO boundary; cron cannot request interactive approval.

The five public bots show a transient Buzz gear reaction while working and one
durable same-thread final response. Tool cards, reasoning, interim text,
streaming deltas, long-running notices, busy acknowledgements, and steering
acknowledgements remain hidden. Approval, clarification, and terminal failure
controls are allowed because they are required to complete or safely stop a
turn. Steering itself remains silent.

Subscriptions and home channels come from the canonical
`/Users/emiller/src/personal/agents-workspace/deployments/nuc/buzz-bindings.nix`.
Betty is ambient in
`meal-planning` and mention-gated in `mill-docs`; every other declared channel
is mention-gated. Amos Burton and Scintillate cron delivery retains
`agent-reports` and `personal-reports`; Betty's routed jobs retain
`meal-planning` and `fitness`. Each profile reuses its existing dedicated
encrypted Buzz identity without sharing private keys.

MillDocs Buzz replies are owned by the dedicated Cloudflare `mill-docs-buzz`
Worker. The NUC keeps only `mill-docs-coding-agent.timer`, which processes typed
Linear feedback and posts authenticated status callbacks. Its rotated encrypted
Buzz identity remains available for repository credentials and queue execution.

### Staged native cutover

The flake exports four deployable canary configurations plus the final `nuc`
configuration. Unselected profiles receive exactly one ACP fallback service
using the shared v0.21.0 package. Expand in this order:

```text
nuc-buzz-scintillate
nuc-buzz-scintillate-finn
nuc-buzz-scintillate-finn-amosburton
nuc-buzz-scintillate-finn-amosburton-anne
nuc
```

At every stage, build before activation and prove that the selected profile has
one native gateway plus presence while its ACP unit is absent. Also prove that
every unselected profile has one ACP unit and its native gateway is disabled.
Never activate a generation with both response lanes for one identity.

The fallback is deliberately permission-denying
(`BUZZ_ACP_PERMISSION_MODE=dont-ask`). The packaged Buzz bridge is patched and
wire-tested to select `reject_once`, never `allow_once`, for this mode. ACP still
cannot provide Hermes' native smart-approval controls and may show Activity
rows. Keep each fallback stage short and run interaction and approval acceptance
only against identities already migrated to native Buzz.

```bash
set -euo pipefail
stage=nuc-buzz-scintillate
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
hey nuc-wt build "$stage"
# Copy the exact NUC_WORKTREE_REMOTE_DIR printed by the build.
remote_dir='PASTE_NUC_WORKTREE_REMOTE_DIR_VALUE_HERE'
ssh nuc "cd '$remote_dir' && sudo nix-private-github nix build --no-link .#checks.x86_64-linux.nuc-hermes-v0210-package"
ssh nuc "cd '$remote_dir' && sudo nix-private-github nix build --no-link .#checks.x86_64-linux.nuc-buzz-hermes-staged-runtime"

# Validate that the staged snapshot evaluates to the exact source revisions
# about to be activated. Do this before dry-activate or switch; a mismatch
# means the build must be discarded and the source synchronized again.
expected_dotfiles="$(git rev-parse HEAD)"
expected_agents="$(nix flake metadata --json | jq -r '.locks.nodes["agents-workspace"].locked.rev')"
expected_revision="dotfiles=$expected_dotfiles;agents-workspace=$expected_agents"
staged_revision="$(ssh nuc "cd '$remote_dir' && sudo nix-private-github nix eval --raw .#nixosConfigurations.${stage}.config.system.configurationRevision")"
test "$staged_revision" = "$expected_revision"

hey nuc-wt dry-activate "$stage"
hey nuc-wt switch "$stage"

ssh nuc "systemctl show hermes-gateway-<profile>.service -p ActiveState -p MainPID -p NRestarts"
ssh nuc "systemctl show buzz-presence-<profile>.service -p ActiveState -p MainPID -p NRestarts -p BindsTo"
ssh nuc "systemctl show buzz-hermes-<profile>.service -p LoadState -p ActiveState"
ssh nuc 'set -eu; for p in scintillate finn amosburton anne betty; do native=0; acp=0; presence=0; systemctl is-active --quiet "hermes-gateway-$p.service" && native=1 || :; systemctl is-active --quiet "buzz-hermes-$p.service" && acp=1 || :; systemctl is-active --quiet "buzz-presence-$p.service" && presence=1 || :; if [ $((native + acp)) -ne 1 ] || [ "$presence" -ne "$native" ]; then echo "$p: native=$native acp=$acp presence=$presence" >&2; exit 1; fi; done'
```

The first stage is package convergence as well as the Scintillate canary.
Because Scintillate deliberately has `restartIfChanged=false`, explicitly
restart it after the switch, then verify the gateway, cron executor, dashboard,
and remaining ACP fallbacks report Hermes v0.21.0 before expanding the selector.

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc 'sudo systemctl restart hermes-gateway-scintillate.service'
ssh nuc 'sudo podman exec hermes-agent-scintillate hermes --version'
ssh nuc "systemctl show buzz-hermes-finn.service buzz-hermes-amosburton.service buzz-hermes-anne.service buzz-hermes-betty.service -p Environment | grep -E 'BUZZ_ACP_(AGENT_COMMAND|PERMISSION_MODE)='"
ssh nuc "systemctl show hermes-gateway-scintillate hermes-scintillate-cron-tick -p FragmentPath -p ExecStart"
```

If a canary fails, deploy the prior named configuration. Use `hey nuc-rollback`
only if the source state is unavailable. Do not advance the next identity until
service state, routing, and a natural Buzz turn pass.

### Final verification

Verify service ownership after the final deployment:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc "systemctl show hermes-gateway-scintillate.service hermes-gateway-finn.service hermes-gateway-amosburton.service hermes-gateway-anne.service hermes-gateway-betty.service -p Id -p ActiveState -p MainPID -p NRestarts"
ssh nuc "systemctl show buzz-presence-scintillate.service buzz-presence-finn.service buzz-presence-amosburton.service buzz-presence-anne.service buzz-presence-betty.service -p Id -p ActiveState -p MainPID -p NRestarts -p BindsTo"
ssh nuc 'test -z "$(systemctl list-unit-files --no-legend "buzz-hermes-*.service")"'
ssh nuc 'test -z "$(systemctl list-units --all --no-legend "buzz-hermes-*.service")"'
ssh nuc 'systemctl show hermes-gateway-orchestrator.service -p ActiveState -p MainPID -p NRestarts'
ssh nuc 'systemctl show mill-docs-coding-agent.timer mill-docs-coding-agent.service -p ActiveState -p NextElapseUSecRealtime'
ssh nuc 'systemctl status buzz-mill-docs-codex.service --no-pager'
ssh nuc "journalctl -u 'hermes-gateway-*.service' -u 'buzz-presence-*.service' -n 100 --no-pager"
```

Expected: all five native gateways and all five presence companions are active
with zero unexpected restarts; no `buzz-hermes-*` ACP unit exists; Orchestrator
is active and internal. `mill-docs-coding-agent.timer` has a future trigger and
`buzz-mill-docs-codex.service` is absent.

In Buzz, test one allowed owner mention per profile. For each, confirm the gear
appears only while working, disappears, and exactly one final response lands in
the originating thread with no Activity/tool/reasoning rows. Also test an
unmentioned post in Betty's `meal-planning` (accepted), an unmentioned post in
Betty's `mill-docs` (ignored), and one unauthorized-author post (ignored). A
tool requiring confirmation must show the native smart approval control rather
than auto-approve.

Create each Hermes identity through the owner-reviewed Buzz flow so the relay
receives the owner attestation and agent-authored profile event. Never reuse a
private key across profiles. Encrypt `BUZZ_PRIVATE_KEY` and `BUZZ_AUTH_TAG`
directly into the matching agenix file; never print either value.

Amos, Betty, and Scintillate accept signed mentions from the owner and the exact
Moni pubkey in the deployment binding. Anne and Finn remain owner-only. All
inherit repository access from
`services.hermes-agent.profiles.<name>.hostPathMounts`; change that canonical
profile boundary instead of adding service-specific paths. Host Docker and
Podman sockets remain inaccessible.

The Mill Docs worker remains owner-only in `mill-docs`.

## Factory Product Pass ACP

The Edmund-only Factory state is `/var/lib/factory-product-pass-edmund`. Its
Nix-managed commands select `claude-opus-5` and never reuse a local Factory
profile:

```bash
set -euo pipefail

# First-time device authentication on the NUC; complete Factory's displayed flow.
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh -t nuc 'cd /var/empty && factory-product-pass-droid'


# Proves only authenticated ACP startup; the agent has no tools and uses /var/empty.
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc factory-product-pass-canary
```

Do not copy Factory credentials or state from another host. Do not create a
Buzz identity or channel until this canary returns an authenticated response.

## Rollback

If the deployment causes issues:

```bash
set -euo pipefail
# Roll back to previous generation
hey nuc-rollback
# Or via SSH
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc "sudo nix-private-github nixos-rebuild --rollback switch"
```

## Common Issues

### SSH connection refused

- Check Tailscale: `tailscale status | grep nuc`
- The NUC may be rebooting after a kernel update

### Service failed to start after deploy

```bash
set -euo pipefail
# Check the service journal
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc "sudo journalctl -u <service-name> --since '5 minutes ago'"
# Roll back while investigating
hey nuc-rollback
```

### Mill Docs Git pull reports invalid LFS pointers

`mill-docs-git-pull.service` validates `HEAD` with `git lfs fsck --pointers`
before invoking Git's autostash. If this fails, pause
`mill-docs-git-pull.timer`, preserve the checkout and every stash, then repair
the invalid local history. Do not repeatedly start the service or drop the
generated stashes.

After repair, verify the checkout and resume the timer:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc 'cd ~/mill-docs && git lfs fsck --pointers HEAD'
ssh nuc 'sudo systemctl start mill-docs-git-pull.timer'
```

### Private flake authentication fails

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc "sudo test -s /var/lib/opnix/secrets/githubNixToken"
ssh nuc "sudo systemctl restart opnix-secrets.service"
```

The source reference is `op://Agents/GH PA dotfiles flake/credential`. Never
print the materialized value. Verify access through the wrapper:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc "sudo nix-private-github nix flake metadata github:edmundmiller/agents-workspace/main"
```

### Gateway restart behavior after deploy

The Scintillate Desktop dashboard is `hermes-scintillate-desktop-dashboard.service`. It binds to all interfaces with username/password authentication; the NUC firewall exposes port 9121 only to the trusted LAN and tailnet. After rotating either dashboard secret, deploy it, then restart the dashboard to load the new value:

```bash
set -euo pipefail
ssh nuc 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
ssh nuc "sudo systemctl restart hermes-scintillate-desktop-dashboard.service"
```
