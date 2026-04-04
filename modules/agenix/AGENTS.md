# Agenix Module

Encrypts secrets at rest in the nix store, decrypts at activation using SSH host keys. Handles both NixOS (system-level) and Darwin (user-level via home-manager).

## How It Works

- **NixOS**: Imports `agenix.nixosModules.age`. Secrets decrypt to `/run/agenix/` (tmpfs). System-level `age.secrets.*`.
- **Darwin**: Imports `agenix.homeManagerModules.age` via home-manager. Secrets decrypt to `~/.local/share/agenix/`. User-level, since nix-darwin has no system-level agenix support.

Identity keys: `~/.ssh/id_ed25519` (primary), `~/.ssh/id_rsa` (fallback, NixOS only).

## Secret Organization

```
hosts/
├── nuc/secrets/
│   ├── secrets.nix          # { "foo.age" = { publicKeys = [...]; }; }
│   └── *.age                # Encrypted files
├── shared/secrets/
│   ├── host-keys.nix        # hostname → SSH pubkey mapping
│   ├── secrets.nix          # Shared secrets (filtered per-host at eval time)
│   └── *.age
└── <host>/secrets/          # Same pattern for other NixOS hosts
```

**Per-host secrets** (`hosts/<hostname>/secrets/`): Auto-discovered on NixOS. Every `.age` entry in `secrets.nix` becomes `config.age.secrets.<name>` (minus the `.age` suffix).

**Shared secrets** (`hosts/shared/secrets/`): Cross-host secrets. Filtered at eval time — only secrets whose `publicKeys` list includes the current host's key (from `host-keys.nix`) are loaded.

**Darwin secrets**: Hardcoded in the module (currently `wakatime-api-key`). No auto-discovery — add entries directly to the `home-manager.users.*.age.secrets` block in `default.nix`.

## Adding a New Secret

### NixOS (per-host)

1. Add the public keys to `hosts/<hostname>/secrets/secrets.nix`:
   ```nix
   "my-secret.age".publicKeys = [ edmundmiller nuc ];
   ```
2. Encrypt: `cd hosts/<hostname>/secrets && agenix -e my-secret.age`
3. The module auto-discovers it — `config.age.secrets.my-secret.path` is now available.

### Shared (cross-host)

1. Add to `hosts/shared/secrets/secrets.nix` with all target host keys in `publicKeys`.
2. Encrypt: `cd hosts/shared/secrets && agenix -e my-secret.age`
3. On NixOS hosts with matching keys, auto-discovered as `config.age.secrets.my-secret`.
4. On Darwin, manually add to the `age.secrets` block in this module.

### Re-encrypting after key changes

```bash
cd hosts/<dir>/secrets && agenix -r  # Re-encrypt all secrets in directory
```

## Consuming Secrets in Modules

Reference decrypted paths via `config.age.secrets.<name>.path`:

```nix
# As an environment file (systemd services)
serviceConfig.EnvironmentFile = config.age.secrets.my-env.path;

# Direct path reference
settings.tokenFile = config.age.secrets.my-token.path;

# In scripts
script = ''
  export API_KEY=$(cat ${config.age.secrets.my-key.path})
'';
```

Common patterns in this repo:

- `EnvironmentFile` for systemd services (`openclaw`, `bugster`, `qb`)
- Individual `path` refs for config files (`homepage`, `hass`, `gatus`, `vault-sync`)
- `owner` defaults to `config.user.name` (overridable per-secret)

## Key Files

| File                                 | Purpose                                                      |
| ------------------------------------ | ------------------------------------------------------------ |
| `modules/agenix/default.nix`         | Module definition                                            |
| `hosts/shared/secrets/host-keys.nix` | Hostname → SSH pubkey map (used for shared secret filtering) |
| `hosts/<host>/secrets/secrets.nix`   | Per-host secret declarations                                 |
| `hosts/shared/secrets/secrets.nix`   | Shared secret declarations                                   |
