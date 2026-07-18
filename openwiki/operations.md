---
type: Operations Playbook
title: Rebuild, deploy, and verification workflow
description: Safe command paths for local Darwin rebuilds and remote NUC deployment, including locking, stale-worktree protection, service verification, and rollback.
resource: /bin/hey
tags: [operations, deployment, nix, nuc, verification]
---

# Rebuild, deploy, and verification workflow

`bin/hey` is the Nushell command dispatcher for system lifecycle, remote deployment, tests, skills, and agent-quality gates. It applies the host outputs described in [architecture](architecture.md) and is constrained by [secrets and safety](secrets-and-safety.md) when credentials are required.

## Choose the right execution path

| Change target             | First action                         | Why                                                                     |
| ------------------------- | ------------------------------------ | ----------------------------------------------------------------------- |
| Local Darwin host         | `hey re` (or `hey check` for checks) | Uses the repository wrapper for the local nix-darwin lifecycle.         |
| NUC, preview activation   | `hey nuc dry-activate`               | Runs the same remote-evaluation path without switching the live system. |
| NUC, uncommitted worktree | `hey nuc-wt build`                   | Syncs a bounded worktree snapshot to NUC and builds there.              |
| NUC, live deployment      | `hey nuc`                            | Activates through NUC-side `nixos-rebuild`; verify afterward.           |
| NUC, recovery             | `hey nuc-rollback`                   | Rolls back the system generation while investigation continues.         |

Do not evaluate/build `nixosConfigurations.nuc` locally from a Darwin machine: the repository documents an architecture mismatch in the agent-skills dependency path. The wrapper evaluates and builds on NUC instead, which is the relevant Linux environment.

## NUC deployment contract

The NUC runbook (`docs/runbooks/deploy-nuc.md`) defines the authoritative flow:

1. Confirm SSH/Tailscale access and the actual target host.
2. Preview with `hey nuc dry-activate`.
3. Activate with `hey nuc` only after reviewing the impact.
4. Confirm generation and the affected systemd service or journal.
5. Use `hey nuc-rollback` if activation regresses service behavior.

Mutating NUC modes (`dry-activate`, `test`, `switch`, `boot`) share `/run/lock/nixos-deploy.lock`. Synced worktrees carry HEAD and merge-base metadata and are rejected when stale relative to `origin/main`. This protects a small shared host from concurrent activation and accidental landing of old configuration. Inspect the lock owner rather than removing locks; bypass stale-source protection only after review with the documented environment override.

[Services and agents](services-and-agents.md) explains the target-specific runtime checks for Hermes and Obsidian Sync; a successful build does not prove those processes are healthy.

## Quality workflow for broader work

`AGENT_WORKFLOW.md` requires a worklog and review gates for broad, autonomous, high-risk, or multi-session changes. Its implementation expectations are:

- identify the outcome and verification surface before editing;
- run focused tests continuously and exercise runtime behavior where possible;
- maintain the canonical doc/runbook when behavior or recovery changes;
- finish with `hey agent-audit-tests`, `hey agent-finish`, a landing review, and normal Git landing hygiene.

Treat quality-manifest commands as trusted repository code: they execute shell commands. Do not add secrets or untrusted input to those commands.

## Verification examples

```sh
# Current NUC status and a managed system service
hey nuc-status
ssh nuc "systemctl status hermes-agent.service"

# Inspect a service failure after activation
ssh nuc "sudo journalctl -u <service-name> --since '5 minutes ago'"

# Review recent system generations
ssh nuc "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3"
```

Use the least invasive check that establishes the claim. For credential-dependent behavior, verify a file is present or an authenticated command succeeds without emitting the value; see [secrets and safety](secrets-and-safety.md).

## Key sources

`bin/hey`; `bin/hey.d/{rebuild,remote,test,agent-quality}.nu`; `AGENT_WORKFLOW.md`; `docs/runbooks/deploy-nuc.md`; `hosts/nuc/AGENTS.md`.
