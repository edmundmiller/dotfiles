# Shared Secrets (agenix)

Cross-host secrets encrypted with [agenix](https://github.com/ryantm/agenix).

## Architecture

**Two layers, different purposes:**

- **`secrets.nix`** — CLI-only. Tells `agenix -r` which public keys encrypt each `.age` file. NOT imported into NixOS config directly (agenix design).
- **`modules/agenix.nix`** — Our custom module that auto-loads secrets. Imports `secrets.nix` to discover shared secrets, then **filters by host key** so each host only gets secrets it can decrypt.

**Host-key filtering:** `host-keys.nix` maps hostnames → SSH public keys. The module looks up `effectiveHostName` in this map and only loads shared secrets where that key appears in `publicKeys`. If a host isn't in `host-keys.nix` or the file is missing, it falls back to loading all (backwards compat).

**Darwin is different:** Darwin hosts don't use the shared secrets auto-loader. They declare secrets explicitly in the home-manager block in `modules/agenix.nix`.

## Files

| File            | Purpose                                          |
| --------------- | ------------------------------------------------ |
| `secrets.nix`   | Public key → secret mapping (for `agenix` CLI)   |
| `host-keys.nix` | Hostname → SSH public key (for module filtering) |
| `*.age`         | Encrypted secrets (safe to commit)               |

## Adding a Secret

```bash
cd hosts/shared/secrets

# 1. Add entry to secrets.nix with publicKeys list
# 2. Create encrypted file
agenix -e new-secret.age -i ~/.ssh/id_ed25519

# 3. If new host needs it, add host key to host-keys.nix too
# 4. NixOS: auto-loaded if host key is in publicKeys
# 5. Darwin: must add explicit declaration in modules/agenix.nix home-manager block
```

## Re-keying

After changing `publicKeys` in `secrets.nix`:

```bash
cd hosts/shared/secrets
agenix -r -i ~/.ssh/id_ed25519
```

You must have a private key that can decrypt the current secrets.

## Adding a New Host

1. Add hostname → public key to `host-keys.nix`
2. Add the same key to relevant secrets in `secrets.nix`
3. Re-key: `agenix -r -i ~/.ssh/id_ed25519`

## Gotchas

- **`secrets.nix` is for the CLI, not NixOS** — agenix docs say "not imported into your NixOS configuration." Our module imports it for convenience but filters by host key.
- **Darwin secrets are manual** — the home-manager block in `modules/agenix.nix` explicitly lists which secrets Darwin gets. Adding a shared secret doesn't auto-expose it on Darwin.
- **Key strings must match exactly** — the key in `host-keys.nix` must be identical to the key in `secrets.nix` `publicKeys` lists (same string, no trailing comment differences).
- **New files must be git-tracked** — flake eval can't see untracked files. `git add` new `.nix` or `.age` files before testing.
