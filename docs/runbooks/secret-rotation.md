# Runbook: Secret Rotation

## Overview

Secrets are managed by **agenix** (encrypted `.age` files) and **opnix** (1Password runtime injection). This runbook covers rotating both types.

## Agenix Secrets

Agenix secrets are encrypted at rest in `hosts/nuc/secrets/` and decrypted at activation time on the target host.

### Rotating an existing secret

1. **Edit the secret** (agenix decrypts, opens in `$EDITOR`, re-encrypts):

   ```bash
   cd ~/.config/dotfiles
   nix run .#agenix -- -e hosts/nuc/secrets/<secret-name>.age
   ```

2. **Commit the updated `.age` file:**

   ```bash
   git add hosts/nuc/secrets/<secret-name>.age
   git commit -m "chore: rotate <secret-name>"
   ```

3. **Deploy to apply the new secret:**

   ```bash
   hey nuc   # For NUC secrets
   hey re    # For local Darwin secrets
   ```

### Adding a new secret

1. **Add the secret path to `hosts/nuc/secrets/secrets.nix`** — this file defines which keys can decrypt each secret.

2. **Create the secret:**

   ```bash
   nix run .#agenix -- -e hosts/nuc/secrets/<new-secret>.age
   ```

3. **Reference it in Nix config** via `config.age.secrets.<name>.file`.

4. **Commit and deploy.**

### Re-keying all secrets

If an SSH key is rotated or a new host key is added:

```bash
cd ~/.config/dotfiles
nix run .#agenix -- -r  # re-encrypts all secrets with current keys
git add hosts/nuc/secrets/*.age
git commit -m "chore: rekey all secrets"
```

## Opnix (1Password) Secrets

Opnix reads secrets from 1Password at runtime using a service account token.

### Rotating an opnix secret

1. **Update the secret in 1Password** (via 1Password app or `op` CLI).
2. **Restart the service** that consumes it — opnix re-reads on service activation:

   ```bash
   # On NUC
   ssh nuc "sudo systemctl restart <service>"
   # On macOS
   hey re
   ```

### Rotating the 1Password service account token

1. Generate a new token in 1Password.
2. Update `/etc/opnix-token` on the NUC:

   ```bash
   ssh nuc "sudo tee /etc/opnix-token <<< '<new-token>'"
   ```

3. Rebuild to re-activate opnix:

   ```bash
   hey nuc
   ```

## Security Reminders

- **Never log secret values** — pass by file path, not by value.
- **Never commit plaintext secrets** — `.gitignore` blocks `.env` files but stay vigilant.
- **Use `set +x`** in shell scripts before handling secrets to avoid bash trace leaks.
