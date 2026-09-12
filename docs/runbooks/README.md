---
purpose: Index operational recovery runbooks for this repository.
applies_to: Choosing which runbook to read for a host, secret, or automation failure.
entrypoint: Use the table row that matches the failure.
verification: Follow the linked runbook and run its named live check.
update_when: A runbook is added, renamed, or changes ownership.
---

# Runbooks

Operational runbooks for the dotfiles infrastructure.

## Index

| Runbook                                                            | When to use                                                       |
| ------------------------------------------------------------------ | ----------------------------------------------------------------- |
| [rebuild-failure.md](rebuild-failure.md)                           | `darwin-rebuild` or `nixos-rebuild` fails                         |
| [deploy-nuc.md](deploy-nuc.md)                                     | Deploying to the NUC server via deploy-rs                         |
| [renovate.md](renovate.md)                                         | Renovate is quiet, noisy, or its Action is failing                |
| [secret-rotation.md](secret-rotation.md)                           | Rotating secrets managed by agenix                                |
| [remove-installer-nix-profile.md](remove-installer-nix-profile.md) | `nix` resolves to a stale installer profile instead of system nix |
