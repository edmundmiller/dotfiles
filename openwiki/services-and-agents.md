---
type: Service Architecture
title: NUC services, managed agents, and Obsidian Sync safety
description: Service integration pattern for the NUC, boundaries for the Hermes agent runtime, and the hybrid Obsidian Sync topology with corruption tripwires.
resource: /modules/services
tags: [services, agents, hermes, obsidian, nuc]
---

# NUC services, managed agents, and Obsidian Sync safety

`modules/services/` wraps NixOS services behind repository options; `hosts/nuc/default.nix` enables and configures the NUC’s chosen services. This domain depends on [architecture](architecture.md) for module loading and on [secrets and safety](secrets-and-safety.md) for credentials and containment. Deployment and runtime confirmation use [operations](operations.md).

## Service integration pattern

For a new self-hosted NUC service, `modules/services/AGENTS.md` defines the expected vertical slice:

1. Create an auto-discovered module with an `enable` option and, where needed, an environment-file path.
2. Enable it in `hosts/nuc/default.nix`.
3. Wire credentials through agenix/opnix rather than plaintext.
4. Add conditional health monitoring in Gatus and a Homepage card when appropriate.
5. Deploy to NUC, then verify the actual service.

Tailscale-served HTTP services expose only their backend port on `tailscale0`; Tailscale terminates HTTPS, so opening generic port 443 in the firewall is explicitly discouraged. Tailnet service definitions and ACL grants live outside this repository in the dedicated tailnet configuration.

The current service tree includes media, home automation, dashboards/monitoring, network access, sync, and agent-adjacent services. This page deliberately maps the integration boundary rather than duplicating each service’s own module documentation.

## Hermes and scheduled agents

`modules/agents/` is for coding-agent configuration. The NixOS Hermes runtime is a managed deployment seam: reusable agent specs and presets come from the `agents-workspace` input, while this repository selects host deployment, profile, credentials, timers, mounts, and service accounts.

Betty is intentionally a background cron executor rather than an interactive gateway. On NUC it has a separate Hermes home and mutable state, a five-minute oneshot timer, and a limited runtime environment. The structural Nix test at `hosts/nuc/_tests/hermes-cron-executors.nix` protects that isolation and asserts its expected secret bindings. Do not change this boundary by adding an interactive gateway or copying another agent’s bot token without verifying the delivery architecture.

## Obsidian Sync topology

The vault has a deliberate hybrid ownership model:

| Device | Sync engine            | Responsibility                                         |
| ------ | ---------------------- | ------------------------------------------------------ |
| Mac    | Obsidian Desktop Sync  | Desktop sync only; Headless Sync must remain disabled. |
| NUC    | Obsidian Headless Sync | Bidirectional sync for the agent-edited vault.         |
| Mobile | Native client          | Requires device-level rollout/audit evidence.          |

The NUC configuration uses bidirectional/desktop mode because agents write to the vault. Its `mill-docs` headless service depends on the main service’s authenticated Obsidian session. Running desktop and headless sync on the same device is prohibited.

## Corruption tripwires

The Obsidian module’s recent hardening makes safety checks part of service lifecycle rather than a manual review:

- before each NUC start, an `ExecStartPre` checks policy, exclusions, unsafe paths, event/log signals, conflict markers, repeated-path loops, churn, and engine conflicts;
- a 30-second systemd timer repeats the guard while the service runs;
- a violation stops `obsidian-sync.service` and can fail its healthcheck ping; it does **not** attempt automated repair or deletion;
- service sandboxing allows only the persistent locations needed for headless setup and sync state.

The structural check `checks.aarch64-darwin.obsidian-sync-safety-assertions` asserts the NUC guard, Mac Headless disablement, required exclusions, pre-start check, stop wrapper, and 30-second NUC/Mac intervals. Run the target-aware deployment flow in [operations](operations.md), then confirm the service is active, the vault is populated, the guard is clean, and logs contain a recent successful sync.

## Change guidance

- Read the nested `AGENTS.md` before changing a service or agent module.
- Keep generic agent-runtime mechanics in the agent module/workspace; keep NUC-specific wiring in the host.
- Add monitoring and user-facing dashboard integration when a new self-hosted service warrants it.
- For sync changes, modify policy and client exclusions together, rollout one peer at a time, and preserve stop-and-alert behavior.
- Never use deployment success as proof that an agent, sync engine, or service works; inspect its target-host status and relevant logs.

## Key sources

`modules/services/AGENTS.md`; `modules/services/obsidian-sync/{default.nix,AGENTS.md,_tests/eval-safety.nix}`; `modules/agents/{AGENTS.md,hermes/}`; `hosts/nuc/{default.nix,_tests/hermes-cron-executors.nix,AGENTS.md}`; `.agents/worklogs/obsidian-sync-hardening.md`.
