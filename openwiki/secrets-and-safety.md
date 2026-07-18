---
type: Security Playbook
title: Secrets, runtime injection, and safety boundaries
description: Credential-management responsibilities for agenix and opnix, secret-safe validation, and the constrained runtime materialization used by NUC automation.
resource: /modules/agenix/default.nix
tags: [security, secrets, agenix, opnix, nuc]
---

# Secrets, runtime injection, and safety boundaries

The repository separates encrypted-at-rest configuration from runtime credential injection. This model protects [services and agents](services-and-agents.md) while allowing [operations](operations.md) to evaluate and deploy host configuration without exposing values.

## Responsibility split

| Mechanism             | Role                                                               | Materialization boundary                                                                    |
| --------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| **agenix**            | Encrypts `.age` files in Git and decrypts them at host activation. | NixOS paths under `/run/agenix/`; Darwin Home Manager paths under `~/.local/share/agenix/`. |
| **opnix / 1Password** | Retrieves runtime secrets using a service-account token.           | Consumer service activation or a dedicated root-owned materialization step.                 |

Agenix discovers host-specific secrets and filters shared recipients based on the active host SSH key. Opnix is for values that must be fetched from 1Password at runtime. Both should be consumed as a file path or environment-file reference, never embedded in a Nix expression, shell transcript, log, worklog, or generated documentation.

## Standard workflows

### Agenix

For a new secret, declare recipients in the appropriate `secrets.nix`, create/edit it through `nix run .#agenix -- -e <path>.age`, reference `config.age.secrets.<name>.path` in configuration, set owner/group only where the consumer requires it, then deploy to the target host. Rekey all affected `.age` files after recipient-key changes.

### Opnix

Rotate the value in 1Password, restart only the consuming service or rebuild the applicable host, and test access without printing the secret. The NUC private-GitHub flake credential is root-only Opnix material consumed through `nix-private-github`; its runbook explicitly requires checking access through the wrapper rather than outputting the token.

The existing rotation runbook includes a command that writes a token; handle this operation interactively and never paste a live token into chat, an agent command, or persistent documentation.

## Safe validation rules

- Test existence/nonempty file state, authenticated command outcomes, or boolean capability checks.
- Pass paths and environment references instead of values.
- Disable shell tracing before secret handling (`set +x`).
- Do not commit plaintext `.env` files; recent Obsidian Sync hardening also excludes `.env` / `.envrc` from the shared sync policy.
- Do not assume a rebuilt secret has refreshed a stale service: restart or deploy the actual consumer and verify it in place.

These rules constrain [operations](operations.md), especially remote deployment logs and quality manifests, and preserve the service containment expectations described in [services and agents](services-and-agents.md).

## Betty’s constrained materialization path

Betty’s NUC cron executor needs credentials from both existing secret files and 1Password references, but it must remain a non-interactive, limited identity. A root activation script creates an ephemeral `/run/hermes-betty-env/secrets.env` via a temporary file, uses restrictive permissions, changes ownership to the Betty user, then atomically moves it into place. The service wrapper exports the required token only for the bounded secret lookup and clears temporary variables.

This exists because the executor cannot safely read the root-owned Opnix service-account token itself. The regression assertions in `hosts/nuc/_tests/hermes-cron-executors.nix` verify the materialization references and expected variables without revealing their values. Betty’s containment additionally uses `NoNewPrivileges`, `PrivateTmp`, protected system paths, and a narrow write allowlist.

Do not expand Betty’s credential or delivery scope without reviewing the host test and service architecture. In particular, its configuration deliberately avoids sharing Scintillate’s Telegram token because concurrent gateways would conflict when polling the same bot.

## Change guidance

1. Identify the mechanism (agenix vs. opnix) and consumer before rotating or adding a secret.
2. Read `modules/agenix/AGENTS.md`, the relevant host instructions, and `docs/runbooks/secret-rotation.md`.
3. Deploy or restart only the consumer, then use a non-secret runtime proof.
4. For NUC changes, follow [operations](operations.md) and inspect the target service—not a local Darwin build.
5. Update the consumer’s test/runbook when ownership, materialization, or recovery behavior changes.

## Key sources

`modules/agenix/{default.nix,AGENTS.md}`; `docs/runbooks/secret-rotation.md`; `docs/runbooks/deploy-nuc.md`; `bin/nix-private-github`; `hosts/nuc/{default.nix,_tests/hermes-cron-executors.nix}`; `modules/agents/hermes/default.nix`.
