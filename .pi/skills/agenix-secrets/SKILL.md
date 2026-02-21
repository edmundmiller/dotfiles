---
name: agenix-secrets
description: >
  Create, edit, and wire up agenix-encrypted secrets in this dotfiles repo.
  Use when adding API keys, tokens, credentials, passwords, or any sensitive
  values to NixOS host configs. Trigger phrases: "add a secret", "encrypt
  with agenix", "new age secret", "hide this value", "agenix secret".
---

# Agenix Secrets

Create age-encrypted secrets and wire them into NixOS modules.

## Repo Secret Layout

```
hosts/<host>/secrets/
├── secrets.nix          # Public key → .age file mapping (NOT imported into NixOS)
├── my-secret.age        # Encrypted secret file
└── restic/              # Subdirectories supported
    └── repo.age
hosts/shared/secrets/
├── secrets.nix          # Shared cross-host secrets
└── host-keys.nix        # Maps hostname → public key for filtering
```

## Auto-Wiring

`modules/agenix.nix` auto-generates `age.secrets` from `secrets.nix`:

- Each `"name.age"` entry becomes `age.secrets.<name>` (`.age` suffix stripped)
- Default `owner = config.user.name` (via `mkDefault` — overridable)
- Default `file` points to `hosts/<host>/secrets/<name>.age`
- Decrypted to `/run/agenix/<name>` at activation time

**You do NOT need to set `age.secrets.<name>.file`** — only override `owner`/`group`/`mode` when the default user shouldn't own it.

## Workflow: Add a New Secret

### 1. Add entry to secrets.nix

```nix
# hosts/<host>/secrets/secrets.nix
let
  edmundmiller = "ssh-ed25519 AAAAC3...";
  nuc = "ssh-ed25519 AAAAC3...";
in {
  "my-secret.age".publicKeys = [ edmundmiller nuc ];
}
```

Both user and host keys are needed — user key to encrypt/edit, host key to decrypt on deploy.

### 2. Create the encrypted file

```bash
cd hosts/<host>/secrets

# Pipe content (non-interactive)
printf 'SECRET_VALUE' | age \
  -r "ssh-ed25519 AAAA...user" \
  -r "ssh-ed25519 AAAA...host" \
  -o my-secret.age

# Verify decryption
age -d -i ~/.ssh/id_ed25519 my-secret.age
```

The `agenix -e` CLI requires an interactive editor. For agent workflows, use `age` directly with `-r` for each recipient public key from `secrets.nix`.

### 3. Reference in NixOS module

```nix
# Simple: file path reference (most common)
services.myapp.environmentFile = config.age.secrets.my-secret.path;

# Override owner when service runs as different user
age.secrets.my-secret = {
  owner = "myapp";
  group = "myapp";
};
```

### 4. Deploy

```bash
git add hosts/<host>/secrets/my-secret.age hosts/<host>/secrets/secrets.nix
git commit -m "secrets: add my-secret"
git push && hey nuc
```

## Pattern: HA secrets.yaml via !secret

Home Assistant's YAML supports `!secret key` references. The nixpkgs HA module
post-processes generated YAML to unquote `!` tags (sed converts `'!secret foo'` → `!secret foo`).

```nix
# In HA module config:
services.home-assistant.config.homeassistant = {
  latitude = "!secret latitude";    # Unquoted by nixpkgs sed post-processor
  longitude = "!secret longitude";
};

# Decrypt with correct owner and symlink into HA config dir:
age.secrets.hass-secrets = {
  owner = "hass";
  group = "hass";
};
systemd.tmpfiles.settings."10-hass-nix-yaml" = {
  "${config.services.home-assistant.configDir}/secrets.yaml" = {
    L.argument = config.age.secrets.hass-secrets.path;
  };
};
```

The `.age` file contains standard HA `secrets.yaml` format:

```yaml
latitude: 33.083423
longitude: -96.820367
```

## Pattern: Update Existing .age File

Decrypt → modify → re-encrypt. Common when adding vars to an existing env file.

```bash
# Decrypt to temp
age -d -i ~/.ssh/id_ed25519 hosts/<host>/secrets/my-env.age > /tmp/my-env.txt

# Modify
echo "NEW_VAR=value" >> /tmp/my-env.txt

# Re-encrypt (overwrites existing .age)
age \
  -r "ssh-ed25519 AAAA...user" \
  -r "ssh-ed25519 AAAA...host" \
  -o hosts/<host>/secrets/my-env.age /tmp/my-env.txt

# Clean up
rm /tmp/my-env.txt

# Verify
age -d -i ~/.ssh/id_ed25519 hosts/<host>/secrets/my-env.age
```

## Pattern: 1Password + Agenix (Login Credentials)

For services needing a username/password — store in both 1Password (human access) and agenix (machine access).

```bash
# 1. Generate creds and store in 1Password
PASSWORD=$(op item create \
  --category=login \
  --title="MyService" \
  --vault="Private" \
  --url="http://nuc:8080" \
  --generate-password="32,letters,digits" \
  username="emiller" \
  --format=json | jq -r '.fields[] | select(.id == "password") | .value')

# 2. Create agenix env file
printf 'MYSERVICE_USER=emiller\nMYSERVICE_PASSWORD=%s' "$PASSWORD" | age \
  -r "ssh-ed25519 AAAA...user" \
  -r "ssh-ed25519 AAAA...host" \
  -o hosts/<host>/secrets/myservice-env.age

# 3. Add to secrets.nix, wire environmentFile, set owner (see below)
```

## Pattern: Service Environment File with Owner Override

Most NixOS services run as a dedicated user (not `emiller`). Override the secret owner so the service can read it.

```nix
# In host config (e.g., hosts/nuc/default.nix):
modules.services.myservice = {
  enable = true;
  environmentFile = config.age.secrets.myservice-env.path;
};

# Override default owner (emiller) → service user
age.secrets.myservice-env.owner = "myservice";
```

The service username typically matches the service name. Check with `grep -r "DynamicUser\|User=" /etc/systemd/system/<service>*` on the target host if unsure.

## Key public keys

Read from `hosts/<host>/secrets/secrets.nix` — don't hardcode. The file defines
`edmundmiller` (user SSH key) and host-specific keys (e.g., `nuc`).

## Common Pitfalls

- **Never `builtins.readFile` a secret path** — leaks plaintext to world-readable Nix store
- **`agenix -e` fails in non-interactive shells** — use `age -r` directly instead
- **Forgot host key in publicKeys** — secret won't decrypt on target machine
- **Wrong owner** — service can't read `/run/agenix/<name>` (default owner is `config.user.name`)
- **Shared secrets** need entry in `hosts/shared/secrets/secrets.nix` AND host key in `host-keys.nix`
