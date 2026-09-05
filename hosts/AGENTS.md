# Hosts

Usernames are fixed host identities: `mactraitorpro` and `nuc` use `emiller`;
`seqeratop` uses `edmundmiller`. Unifying them breaks home paths, permissions,
and secret wiring.

For host operations, confirm `hostname` and `uname -a`. Darwin activation uses
`hey re`, rollback uses `hey rollback`, and NUC deployment uses `hey nuc`.
Activation/deployment requires authorization, not merely a configuration edit.

Secret recipients live in `hosts/<host>/secrets/secrets.nix` and
`hosts/shared/secrets/`. A changed encrypted file is not reflected in decrypted
runtime state until the target rebuilds. Recipient changes also require re-keying.
