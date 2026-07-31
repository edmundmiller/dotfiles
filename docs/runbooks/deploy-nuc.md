---
purpose: Deploy and verify the NUC from the dotfiles worktree.
applies_to: NUC builds, switches, rollbacks, and deployment recovery.
entrypoint: Run `hey nuc dry-activate`, then `hey nuc`.
verification: Confirm the generation and relevant systemd services on the NUC.
update_when: NUC authentication, build location, commands, or verification changes.
---

# Runbook: Deploy to NUC

## Overview

The NUC is a NixOS server managed from this dotfiles repo — there is no CI-driven deployment. `hey nuc` evaluates and builds on the NUC for consistent cross-platform behavior: when run off-NUC it syncs the current worktree to `nuc:/tmp/dotfiles-worktree-$USER` and runs `nixos-rebuild` there; when run on the NUC it runs a local `nixos-rebuild`. NUC rebuilds pass `--max-jobs 1` to keep builds stable on the small host.

## Prerequisites

- SSH access to `nuc` (configured in `~/.ssh/config` via home-manager)
- Tailscale connected (the NUC is on the tailnet)
- `/var/lib/opnix/secrets/githubNixToken` materialized by `opnix-secrets.service`
- Clean working tree recommended (`git stash` uncommitted work)

Private `github:` flake inputs use `nix-private-github`. It reads the root-only
opnix credential and supplies Nix `access-tokens` without logging the token.
`hey nuc`, local NUC `hey re`, and `nixos-upgrade.service` use this wrapper.
Darwin `hey re` obtains the same narrow credential from the local `gh` keyring.

Mutating NUC rebuilds (`dry-activate`, `test`, `switch`, and `boot`) share the
NUC-side lock `/run/lock/nixos-deploy.lock`. Worktree deploys also send their
HEAD and merge-base; the wrapper compares them with live GitHub `origin/main`
before activation. Old synced snapshots without metadata and stale worktrees
are rejected. `build` and `vm` remain parallel and do not take the lock.

If a deploy is rejected, update the worktree from `origin/main`, rebuild, then
retry. Inspect contention without deleting lock files:

```bash
ssh nuc "sudo cat /run/lock/nixos-deploy.lock.owner"
```

The owner file includes caller, PID, time, working directory, and source
commits. Process exit or interruption releases the kernel lock; the next owner
overwrites stale diagnostics safely. After explicit review, bypass only the
stale-source check with `NUC_DEPLOY_ALLOW_STALE=1 hey nuc-wt switch`; the shared
lock still applies.

## Deploy

```bash
# Standard deployment
hey nuc

# Preview from the same remote-evaluation path
hey nuc dry-activate
```

## Dry Run (Preview Changes)

```bash
hey nuc dry-activate
# Equivalent compatibility aliases:
hey deploy-dry nuc
hey deploy-check
```

## Verify Deployment

After deploying, verify the NUC is healthy:

```bash
# Quick system status
hey nuc-status

# Check specific services
ssh nuc "systemctl status home-assistant"
ssh nuc "systemctl status hermes-agent.service"

# Legacy OpenClaw deployments only
ssh nuc "systemctl --user status openclaw-gateway.service"

# Check current generation
ssh nuc "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3"

# View recent logs for a service
hey nuc-logs home-assistant.service 30
```

## Codex Remote Control

Codex remote control deliberately splits ownership. The foreground `codex` command remains
Nix-managed, while the daemon runs the official installer's mutable binary at
`$HOME/.codex/packages/standalone/current/codex`. The source of truth for this boundary is
`modules/agents/codex/AGENTS.md`.

The standalone installer is a one-time bootstrap for each NUC home directory; `hey nuc` does
not install it. On a new home, connect to the NUC and bootstrap remote control:

```bash
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

`hosts/nuc/default.nix` generates one `buzz-hermes-<profile>.service` for every
configured NUC Hermes profile. Each service runs `buzz-acp -> hermes acp` with
the profile's materialized home, provider environment, and declared repository
mounts. Its dedicated identity and owner attestation live in
`hosts/nuc/secrets/buzz-hermes-<profile>-agent-env.age`.
Subscriptions and home channels come from the canonical
`agents-workspace/deployments/nuc/buzz-bindings.nix` deployment binding.
Project profiles watch `mill-docs` or `finances`; Orchestrator watches
`general`; Amos watches `general` plus `agent-reports`; Radar watches
`general`; Scintillate watches `general` plus `personal-reports`; Betty watches
`mill-docs`, `meal-planning`, and `fitness`.

Active cron executors use Hermes' native Buzz adapter for outbound delivery.
Amos Burton uses `agent-reports`; Scintillate uses `personal-reports`. Betty
keeps `mill-docs` as home while her meal-plan and Lift jobs resolve logical
routes to `meal-planning` and `fitness`. Radar cron delivers only to Edmund by
email and does not load Buzz delivery credentials. Buzz executors load the
same dedicated identity as their profile's inbound runtime. `buzz-acp` remains
mention-scoped inbound transport.

MillDocs Buzz replies are owned by the dedicated Cloudflare `mill-docs-buzz`
Worker. The NUC keeps only `mill-docs-coding-agent.timer`, which processes typed
Linear feedback and posts authenticated status callbacks. Its encrypted Buzz
identity remains available for repository credentials and queue execution.

Verify after a deploy or recovery:

```bash
ssh nuc "systemctl list-units --all --no-legend 'buzz-hermes-*.service'"
ssh nuc "systemctl show 'buzz-hermes-*.service' -p Id -p ActiveState -p MainPID -p NRestarts"
ssh nuc 'systemctl is-active mill-docs-coding-agent.timer'
ssh nuc 'systemctl status buzz-mill-docs-codex.service --no-pager'
ssh nuc "journalctl -u 'buzz-hermes-*.service' -n 50 --no-pager"
```

Expected: every configured Hermes unit is active with zero restarts and connected to
`wss://millers.communities.buzz.xyz`. Lazy mode starts the Hermes ACP child
only after an accepted mention. The services expose no listener.
`mill-docs-coding-agent.timer` is active, and
`buzz-mill-docs-codex.service` is not found.

```bash
ssh nuc "sudo systemctl restart 'buzz-hermes-*.service'"
ssh nuc 'sudo systemctl start mill-docs-coding-agent.service'
```

Create each Hermes identity through the owner-reviewed Buzz flow so the relay
receives the owner attestation and agent-authored profile event. Never reuse a
private key across profiles. Encrypt `BUZZ_PRIVATE_KEY` and `BUZZ_AUTH_TAG`
directly into the matching agenix file; never print either value.

Amos, Betty, Radar, and Scintillate accept signed mentions from the owner and
the exact Moni pubkey in the deployment binding. Anne, Finn, and Orchestrator
remain owner-only. All inherit repository access from
`services.hermes-agent.profiles.<name>.hostPathMounts`; change that canonical
profile boundary instead of adding service-specific paths. Host Docker and
Podman sockets remain inaccessible.

The Mill Docs worker remains owner-only in `mill-docs`.

## Rollback

If the deployment causes issues:

```bash
# Roll back to previous generation
hey nuc-rollback
# Or via SSH
ssh nuc "sudo nix-private-github nixos-rebuild --rollback switch"
```

## Common Issues

### SSH connection refused

- Check Tailscale: `tailscale status | grep nuc`
- The NUC may be rebooting after a kernel update

### Service failed to start after deploy

```bash
# Check the service journal
ssh nuc "sudo journalctl -u <service-name> --since '5 minutes ago'"
# Roll back while investigating
hey nuc-rollback
```

### Private flake authentication fails

```bash
ssh nuc "sudo test -s /var/lib/opnix/secrets/githubNixToken"
ssh nuc "sudo systemctl restart opnix-secrets.service"
```

The source reference is `op://Agents/GH PA dotfiles flake/credential`. Never
print the materialized value. Verify access through the wrapper:

```bash
ssh nuc "sudo nix-private-github nix flake metadata github:edmundmiller/agents-workspace/main"
```

### Gateway restart behavior after deploy

The active NUC gateway is `hermes-agent.service`, a system service that is restarted by activation during `hey nuc`, so no manual post-deploy restart is normally needed.

For older OpenClaw deployments only, the legacy user unit still uses `X-RestartIfChanged=false`, so you may need:

```bash
ssh nuc "systemctl --user try-restart openclaw-gateway.service"
```
