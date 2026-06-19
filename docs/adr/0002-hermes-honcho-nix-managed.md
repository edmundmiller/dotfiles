# ADR 0002: Hermes Honcho memory is Nix-managed on the NUC

## Status

Accepted

## Context

Hermes profiles on the NUC use Honcho for persistent memory. A profile can be configured with `memory.provider = "honcho"`, but Honcho only works if both requirements are true at service start:

1. `HONCHO_API_KEY` is present in the profile environment / `$HERMES_HOME/.env`.
2. The Hermes package includes the `honcho` optional dependency group, which provides `honcho-ai`.

The NUC has historically had multiple overlapping ways to materialize Hermes state:

- the upstream-style `services.hermes-agent.profiles` module, which merges `environmentFiles` into each profile's `$HERMES_HOME/.env`;
- canonical agent rendering from `agents-workspace`, which knows each agent's Honcho reference;
- host-local custom scripts that write `/run/hermes-*-env/secrets.env` for gateway services;
- occasional manual debugging inside the container.

That made the setup easy for agents to break. In particular, Scintillate could have `memory.provider = "honcho"` while the host-local secret set omitted `HONCHO_API_KEY`, and the Nix-built Hermes package omitted the Honcho Python dependency. Hermes then silently fell back to built-in memory and hit the small built-in memory cap.

The Hermes Nix documentation is explicit that NixOS module deployments should be declarative: secrets come from `environmentFiles`, optional memory provider dependencies come from `extraDependencyGroups`, and agents should not use `pip install` or `hermes config set` to repair managed services.

## Decision

On the NUC, Honcho is a declarative service dependency, not a runtime repair step.

- Any Hermes profile that uses Honcho receives `HONCHO_API_KEY` through a root-managed secret file and the profile's `environmentFiles` path.
- Honcho keys are sourced from 1Password through OpNix materialization under `/var/lib/opnix/secrets/*`; plaintext keys are never committed to Nix or git.
- The NUC Hermes service package is `pkgs.llm-agents."hermes-agent"` with repo-local overlay adjustments under `overlays/hermes-agent/`. Prefer the llm-agents package because its Nix expression is maintained as a package boundary; upstream Hermes app development has outpaced its own flake/Nix packaging.
- The repo overlay wraps the llm-agents Hermes package to add the Nix-built `honcho-ai` wheel to `PYTHONPATH`. If/when the active package supports upstream `extraDependencyGroups`, this should become `services.hermes-agent.extraDependencyGroups = [ "honcho" ];` instead.
- Manual container `pip install`, manual `$HERMES_HOME/.env` editing, and `hermes config set memory.provider ...` are not accepted fixes for Nix-managed profiles.

## Consequences

- If an agent enables Honcho memory but forgets the key/dependency wiring, the Nix configuration is the place to fix it.
- `nixos-rebuild switch` / `hey nuc` is sufficient to recreate the desired service state.
- `$HERMES_HOME/.env` remains generated operational state; it may be inspected for debugging, but durable changes belong in Nix or 1Password/OpNix.
- The writable container layer is no longer part of the correctness story for Honcho, so container recreation cannot remove the Honcho SDK.

## Verification

After deployment, verify a profile with:

```bash
hermes honcho status
hermes memory status
```

Expected result: Honcho is installed, has an API key, and is the active memory provider.
