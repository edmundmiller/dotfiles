# Shared Secrets Management

Secrets encrypted with [agenix](https://github.com/ryantm/agenix) for multi-host access.

## Key Concepts

- **secrets.nix**: Defines which SSH public keys can decrypt each secret
- **\*.age files**: Encrypted secrets (safe to commit)
- Decryption happens at system activation using SSH private keys

## Re-encrypting Secrets

When adding a new host's SSH key to a secret:

### 1. Update secrets.nix

Add the new system key to the secret's `publicKeys` list:

```nix
"taskchampion-sync.age".publicKeys = [
  users.emiller
  systems.mactraitor
  systems.nuc        # <-- Add new host
  systems.seqeratop
];
```

### 2. Re-encrypt the secret

```bash
cd hosts/shared/secrets
agenix -e <secret>.age
# Editor opens with decrypted content
# Save and exit - agenix re-encrypts with updated key list
```

**Important:** You must have a private key that can decrypt the current secret. The `-e` flag decrypts, opens editor, then re-encrypts with all keys from secrets.nix.

### 3. Commit both files

```bash
jj desc -m "Add <host> key to <secret>"
# or: git add secrets.nix <secret>.age && git commit
```

## Adding New Secrets

```bash
cd hosts/shared/secrets

# 1. Define in secrets.nix
echo '"new-secret.age".publicKeys = [ users.emiller systems.nuc ];' >> secrets.nix

# 2. Create the encrypted file
agenix -e new-secret.age
# Enter secret content, save and exit
```

## Viewing Secret Recipients

Check which keys can decrypt a secret:

```bash
# From secrets.nix definition
grep -A5 "secret-name.age" secrets.nix

# Or inspect the .age file directly (shows key fingerprints)
age-keygen -y < ~/.ssh/id_ed25519  # Your key fingerprint
```

## Common Secrets

| Secret | Purpose | Hosts |
|--------|---------|-------|
| `taskchampion-sync.age` | TaskWarrior sync credentials | mactraitor, nuc, seqeratop |
| `wakatime-api-key.age` | WakaTime API key | mactraitor, seqeratop |

## Troubleshooting

**"no identity matched any of the recipients"**
- Your SSH key isn't in the secret's publicKeys list
- Re-encrypt with your key added, or use a machine that has access

**Secret not decrypted at login**
- Check `age.identityPaths` includes your SSH key path
- Verify the secret is defined in `age.secrets` for your host type (Darwin vs NixOS)

**Permission denied reading secret**
- Check `mode` and `owner` in secret definition
- Default is root-owned; set `owner = config.user.name` for user access
