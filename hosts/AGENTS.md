# Hosts

Usernames are fixed host identities: `mactraitorpro` and `nuc` use `emiller`;
`seqeratop` uses `edmundmiller`. Unifying them breaks home paths, permissions,
and secret wiring.

For host operations, confirm `hostname` and `uname -a`. Darwin activation uses
`hey re`, rollback uses `hey rollback`, and NUC deployment uses `hey nuc`.
Activation/deployment requires authorization, not merely a configuration edit.

For new host setup or redeployment, read [the provisioning guidance](../docs/install.md#nixos-host-setup-and-redeployment)
before disk work. It covers existing disko layouts and staged execution safety.

Secret recipients live in `hosts/<host>/secrets/secrets.nix` and
`hosts/shared/secrets/`. A changed encrypted file is not reflected in decrypted
runtime state until the target rebuilds. Recipient changes also require re-keying.

Run `hey check hosts/<host>` before requesting activation. Use the matching
`hey check --platform <suite>` when the change depends on host evaluation; neither
command activates or deploys the host.
Before Mac activation, require `hey check --platform darwin` or explicitly
requested native CI for the exact candidate. Default CI does not certify Darwin.
