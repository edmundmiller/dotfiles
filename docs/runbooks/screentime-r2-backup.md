---
purpose: Preserve rolling macOS app-usage history in an encrypted private R2 backup.
applies_to: MacTraitor-Pro Screen Time archival, credential rotation, backup verification, and restore.
entrypoint: Run `screentime-backup archive` locally; launchd owns the weekly encrypted backup.
verification: Compare source/archive UUID coverage, inspect the latest restic snapshot, and restore one database to a temporary directory.
update_when: The source schema, archive fields, schedule, R2 bucket, Keychain services, or restore procedure changes.
---

# Screen Time R2 backup

## Contract

`knowledgeC.db` retains only a rolling local window. The packaged CLI copies every `/app/usage` record into `~/.local/state/screentime/history.sqlite`, preserving the first row seen for each `ZUUID`. A user LaunchAgent runs Sunday at 23:55 local time and backs up the closed SQLite archive with restic.

The remote target is the private `screentime-backups` bucket in Cloudflare account `57398029d3d0add95bdad89deaa41864`. Do not enable public access, reuse another bucket or repository, or add lifecycle deletion or restic pruning without a separate retention decision.

## Credentials

1Password item `Private/Screen Time R2 Backup` is authoritative:

| Field        | Purpose                                | Keychain service                                     |
| ------------ | -------------------------------------- | ---------------------------------------------------- |
| `username`   | Bucket-scoped R2 access key ID         | `com.emiller.screentime-backup.r2-access-key-id`     |
| `credential` | Bucket-scoped R2 secret access key     | `com.emiller.screentime-backup.r2-secret-access-key` |
| `password`   | Independent restic repository password | `com.emiller.screentime-backup.restic-password`      |

The R2 token must have object read/write access only to `screentime-backups`. Provisioning reads 1Password once and writes those three values to the login Keychain for non-interactive launchd runs. Never print the values or store them in Nix, Git, logs, plist environment variables, or shell history.

## Local verification

```bash
screentime-backup archive \
  --source "$HOME/Library/Application Support/Knowledge/knowledgeC.db" \
  --archive "$HOME/.local/state/screentime/history.sqlite"
```

The command must return JSON, keep the state directory at `0700` and database at `0600`, pass `PRAGMA quick_check`, and leave no duplicate UUIDs.

## Remote verification and restore

After a supervised backup, read the latest restic snapshot from the exact repository. Restore it to a fresh `mktemp -d` target, then compare the restored database's row count and minimum/maximum timestamps with the local archive. Upload or snapshot success without this restore equality is incomplete.

Keep the restored temporary directory until equality is proven. Remove it only after recording the snapshot ID and comparison evidence.
