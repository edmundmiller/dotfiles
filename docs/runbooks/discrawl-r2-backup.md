---
purpose: Preserve the local Discrawl archive in an encrypted private R2 backup.
applies_to: MacTraitor-Pro Discrawl backup provisioning, verification, and restore.
entrypoint: Run `discrawl-backup snapshot` locally; launchd owns the daily encrypted backup.
verification: Inspect the latest restic snapshot, restore it, and compare database integrity and message counts.
update_when: The Discrawl database path, schedule, R2 bucket, Keychain services, or restore procedure changes.
---

# Discrawl R2 backup

## Contract

Discrawl stores its live SQLite archive at `~/.local/share/discrawl/discrawl.db`.
The database includes local-only direct messages recovered from the desktop
cache. A user LaunchAgent runs daily at 23:45 local time. It uses SQLite's
online backup API to create a consistent closed snapshot at
`~/.local/state/discrawl-backup/discrawl.db`, validates that snapshot, and
backs it up with restic.

The remote target is the private `discrawl-backups` bucket in Cloudflare
account `57398029d3d0add95bdad89deaa41864`. Do not enable public access, reuse
the Screen Time bucket or credentials, or add lifecycle deletion or restic
pruning without a separate retention decision.

## Credentials

Create a dedicated 1Password item named `Private/Discrawl R2 Backup`:

| Field        | Purpose                                | Keychain service                                   |
| ------------ | -------------------------------------- | -------------------------------------------------- |
| `username`   | Bucket-scoped R2 access key ID         | `com.emiller.discrawl-backup.r2-access-key-id`     |
| `credential` | Bucket-scoped R2 secret access key     | `com.emiller.discrawl-backup.r2-secret-access-key` |
| `password`   | Independent restic repository password | `com.emiller.discrawl-backup.restic-password`      |

The R2 token must have object read/write access only to `discrawl-backups`.
Provisioning reads 1Password once and writes those values to the login
Keychain for non-interactive launchd runs. Never print the values or store
them in Nix, Git, logs, plist environment variables, or shell history.

Initialize the repository once after the bucket and Keychain entries exist:

```bash
export RESTIC_REPOSITORY='s3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/discrawl-backups'
export AWS_ACCESS_KEY_ID="$(security find-generic-password -a "$USER" -s com.emiller.discrawl-backup.r2-access-key-id -w)"
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -a "$USER" -s com.emiller.discrawl-backup.r2-secret-access-key -w)"
export RESTIC_PASSWORD="$(security find-generic-password -a "$USER" -s com.emiller.discrawl-backup.restic-password -w)"
restic init
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD RESTIC_REPOSITORY
```

## Local verification

```bash
discrawl-backup snapshot \
  --source "$HOME/.local/share/discrawl/discrawl.db" \
  --snapshot "$HOME/.local/state/discrawl-backup/discrawl.db"
```

The command must return JSON, keep the state directory at `0700` and database
at `0600`, and pass `PRAGMA quick_check`.

## Remote verification and restore

After a supervised backup, use the credentials above to inspect the latest
snapshot and restore it to a fresh directory:

```bash
restic snapshots --tag discrawl
restore_dir="$(mktemp -d)"
restic restore latest --tag discrawl --target "$restore_dir"
restored_db="$restore_dir$HOME/.local/state/discrawl-backup/discrawl.db"
sqlite3 -readonly "$restored_db" 'PRAGMA quick_check; SELECT COUNT(*) FROM messages;'
sqlite3 -readonly "$HOME/.local/state/discrawl-backup/discrawl.db" \
  'PRAGMA quick_check; SELECT COUNT(*) FROM messages;'
```

Both integrity checks must return `ok`, and the restored and local message
counts must match. Upload or snapshot success without this restore equality is
incomplete. Keep the restore directory until equality is proven, then remove
it and unset the four restic environment variables.
