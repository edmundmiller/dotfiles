# Shared agenix secrets

`secrets.nix` maps encrypted filenames to recipients for the agenix CLI.
`host-keys.nix` maps hostnames to SSH public keys. `modules/agenix/` uses both
to filter shared secrets on NixOS; key strings must match exactly, including
comments. Missing host mappings retain the legacy load-all fallback.

Darwin does not use shared auto-discovery: declare its secrets explicitly in
the module's Home Manager block. New `.nix` and `.age` files must be tracked
for flake evaluation to see them.

From this directory, `agenix -e <name>.age -i ~/.ssh/id_ed25519` edits an encrypted
secret. After recipient changes, `agenix -r -i ~/.ssh/id_ed25519` re-keys it;
the operator needs an identity that can decrypt the existing ciphertext.
Adding a host requires its key in both mappings and re-keying.
