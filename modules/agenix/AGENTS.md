# Agenix wiring

NixOS uses system `age.secrets` decrypted into `/run/agenix`; Darwin uses Home
Manager age secrets under `~/.local/share/agenix`. Identity is
`~/.ssh/id_ed25519`, with `id_rsa` fallback on NixOS.

NixOS discovers `hosts/<host>/secrets/secrets.nix` entries and strips `.age`
from option names. Shared secret filtering uses host-key/recipient mappings;
see [shared secrets](../../hosts/shared/secrets/AGENTS.md). Darwin secrets are
explicitly declared in this module's Home Manager block, not auto-discovered.

Consumers use `config.age.secrets.<name>.path`, usually as `EnvironmentFile` or
a token-file option. Ownership defaults to `config.user.name`; override it for
service users that need access. Encryption/re-keying belongs to agenix, not
plaintext Nix expressions.
