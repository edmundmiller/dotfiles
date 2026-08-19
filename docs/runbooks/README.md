# Runbooks

- [LookAway Busylight / Luxafor integration](./lookaway-busylight.md)
- [Remove Installer Nix Profile](./remove-installer-nix-profile.md)

Operational runbooks for the dotfiles infrastructure.

## Index

| Runbook                                                            | When to use                                                       |
| ------------------------------------------------------------------ | ----------------------------------------------------------------- |
| [rebuild-failure.md](rebuild-failure.md)                           | `darwin-rebuild` or `nixos-rebuild` fails                         |
| [deploy-nuc.md](deploy-nuc.md)                                     | Deploying to the NUC server via deploy-rs                         |
| [secret-rotation.md](secret-rotation.md)                           | Rotating secrets managed by agenix                                |
| [remove-installer-nix-profile.md](remove-installer-nix-profile.md) | `nix` resolves to a stale installer profile instead of system nix |
