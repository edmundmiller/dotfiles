---
name: nix-rebuild
description: Activates dotfiles on managed hosts through hey. Use when a system rebuild, activation, or rollback is explicitly requested, not after every Nix edit.
---

# Activate Nix configuration

Source edits do not update the running host. When activation is authorized,
confirm the target with `hostname` / `uname -a` and use `hey re` or
`hey rebuild` for Darwin. Sudo availability is host-specific; Seqeratop may
require the user at an interactive terminal.

NUC operations follow `docs/runbooks/deploy-nuc.md` through `hey nuc`;
`hey nuc-wt build` prepares isolated build evidence without activation.
Do not evaluate NUC configuration on Darwin.

After activation, check the changed runtime config/service. `hey rollback`
returns to the previous generation when rollback is requested. Edit repository
sources, not deployed store symlinks; raw rebuild commands bypass repository
command policy.
