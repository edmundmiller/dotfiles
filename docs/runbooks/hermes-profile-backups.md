---
purpose: Inspect, compare, and restore mutable NUC Hermes profile snapshots.
applies_to: Runtime changes under `/var/lib/hermes-*/.hermes`, including inline-installed skills.
verification: Create a tagged snapshot, restore one profile to a temporary directory, and compare it with the live profile.
update_when: The Hermes profile layout, restic repository, schedule, retention, or restore procedure changes.
---

# Hermes profile snapshots

The NUC backs up every configured Hermes profile home to the `nuc-restic`
Cloudflare R2 repository hourly. Snapshots are tagged
`hermes-profile-state` and retain all snapshots from the last 24 hours, then 7
daily, 5 weekly, and 12 monthly restore points.

These snapshots are rollback and forensic evidence, not canonical agent
configuration. Promote changes worth keeping to `agents-workspace`.

The hourly job captures live profiles without interrupting active conversations.
It reliably preserves completed file changes such as installed skills and config
edits, but it is not an application-consistent checkpoint across multiple open
SQLite databases. Treat a whole-profile database restore as disaster recovery:
restore to staging, run database integrity checks, and schedule downtime before
promotion.

## Create and list snapshots

```bash
ssh nuc 'sudo systemctl start restic-backups-hermes-profile-state.service'
ssh nuc 'sudo hermes-profile-restic snapshots --tag hermes-profile-state'
```

Open a root shell on the NUC for the remaining commands. The
`hermes-profile-restic` wrapper uses the deployed restic package and loads the
R2 credentials without printing them:

```bash
ssh -t nuc 'sudo -i'
```

## Inspect what changed

Restic reports metadata and content changes between two snapshot IDs:

```bash
hermes-profile-restic diff --metadata OLD_SNAPSHOT NEW_SNAPSHOT
```

To inspect the exact content of one profile or skill, restore both snapshots to
temporary directories and compare them:

```bash
old=$(mktemp -d)
new=$(mktemp -d)
hermes-profile-restic restore OLD_SNAPSHOT --target "$old" \
  --include /var/lib/hermes-scintillate/.hermes/skills
hermes-profile-restic restore NEW_SNAPSHOT --target "$new" \
  --include /var/lib/hermes-scintillate/.hermes/skills
diff -ruN \
  "$old/var/lib/hermes-scintillate/.hermes/skills" \
  "$new/var/lib/hermes-scintillate/.hermes/skills"
```

Keep the temporary restores until the wanted change has been identified or
promoted.

## Restore safely

Do not restore an entire profile over a running gateway. First create a fresh
snapshot, restore the selected snapshot to a temporary directory, and inspect
the diff. Then stop only the affected profile and copy only the intended path:

```bash
systemctl start restic-backups-hermes-profile-state.service
restore=$(mktemp -d)
chmod 0700 "$restore"
hermes-profile-restic restore SNAPSHOT --target "$restore" \
  --include /var/lib/hermes-scintillate/.hermes/skills/SKILL_NAME
systemctl stop hermes-gateway-scintillate.service
rsync -a --delete \
  "$restore/var/lib/hermes-scintillate/.hermes/skills/SKILL_NAME/" \
  /var/lib/hermes-scintillate/.hermes/skills/SKILL_NAME/
chown -R emiller:users /var/lib/hermes-scintillate/.hermes/skills/SKILL_NAME
systemctl start hermes-gateway-scintillate.service
```

Confirm the gateway reconnects and the restored skill is visible before
removing the temporary restore. For a full profile recovery, restore to a new
directory first, validate each SQLite database with `PRAGMA integrity_check`,
and schedule downtime rather than replacing the live tree in place.
