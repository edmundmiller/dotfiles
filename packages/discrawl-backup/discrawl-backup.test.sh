#!/usr/bin/env bash
set -euo pipefail

backup_cli="${1:?usage: discrawl-backup.test.sh DISCRAWL_BACKUP_CLI}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/discrawl-backup.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

source_db="$fixture/discrawl.db"
snapshot_db="$fixture/state/discrawl.db"

sqlite3 "$source_db" <<'SQL'
PRAGMA user_version = 5;
PRAGMA journal_mode = WAL;
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  guild_id TEXT NOT NULL,
  content TEXT NOT NULL
);
INSERT INTO messages VALUES
  ('message-a', '@me', 'private message'),
  ('message-b', 'guild-1', 'guild message');
SQL

snapshot_output="$($backup_cli snapshot --source "$source_db" --snapshot "$snapshot_db")"
jq -e '.schemaVersion == 5 and .messages == 2 and .directMessages == 1' <<<"$snapshot_output" >/dev/null
test "$(sqlite3 -readonly "$snapshot_db" 'PRAGMA quick_check;')" = ok
test "$(stat -c '%a' "$(dirname "$snapshot_db")")" = 700
test "$(stat -c '%a' "$snapshot_db")" = 600

sqlite3 "$source_db" "INSERT INTO messages VALUES ('message-c', '@me', 'new private message');"
second_output="$($backup_cli snapshot --source "$source_db" --snapshot "$snapshot_db")"
jq -e '.messages == 3 and .directMessages == 2' <<<"$second_output" >/dev/null
test "$(sqlite3 -readonly "$snapshot_db" 'SELECT COUNT(*) FROM messages;')" = 3

if "$backup_cli" run \
  --source "$source_db" \
  --snapshot "$snapshot_db" \
  --repository 's3:https://wrong-account.r2.cloudflarestorage.com/discrawl-backups' \
  >"$fixture/wrong-account.out" 2>"$fixture/wrong-account.err"; then
  echo 'expected a different R2 repository to fail' >&2
  exit 1
fi
grep -F 'must target the dedicated private discrawl-backups R2 bucket' \
  "$fixture/wrong-account.err" >/dev/null

mkdir -p "$fixture/fake-bin"
security_calls="$fixture/security.calls"
restic_calls="$fixture/restic.calls"

cat >"$fixture/fake-bin/security" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$SECURITY_CALLS"
service=""
while (($# > 0)); do
  if [[ "$1" == "-s" ]]; then
    service="$2"
    break
  fi
  shift
done
case "$service" in
  com.emiller.discrawl-backup.r2-access-key-id) printf '%s\n' 'fake-access-key' ;;
  com.emiller.discrawl-backup.r2-secret-access-key) printf '%s\n' 'fake-secret-key' ;;
  com.emiller.discrawl-backup.restic-password) printf '%s\n' 'fake-restic-password' ;;
  *) printf 'unexpected Keychain service: %s\n' "$service" >&2; exit 1 ;;
esac
SH

cat >"$fixture/fake-bin/restic" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${RESTIC_REPOSITORY:-}" == 's3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/discrawl-backups' ]]
[[ "${AWS_ACCESS_KEY_ID:-}" == 'fake-access-key' ]]
[[ "${AWS_SECRET_ACCESS_KEY:-}" == 'fake-secret-key' ]]
[[ "${RESTIC_PASSWORD:-}" == 'fake-restic-password' ]]
printf '%s\n' "$*" >>"$RESTIC_CALLS"
case "$1" in
  backup)
    snapshot_path="${@: -1}"
    [[ "$(sqlite3 -readonly "$snapshot_path" 'PRAGMA quick_check;')" == ok ]]
    ;;
  snapshots)
    printf '%s\n' '[{"id":"snapshot-1","short_id":"snapshot","paths":["discrawl.db"]}]'
    ;;
  *) printf 'unexpected restic command: %s\n' "$1" >&2; exit 1 ;;
esac
SH
chmod +x "$fixture/fake-bin/security" "$fixture/fake-bin/restic"

run_output="$(
  SECURITY_CALLS="$security_calls" \
  RESTIC_CALLS="$restic_calls" \
  DISCRAWL_BACKUP_SECURITY="$fixture/fake-bin/security" \
  DISCRAWL_BACKUP_RESTIC="$fixture/fake-bin/restic" \
  DISCRAWL_BACKUP_KEYCHAIN_ACCOUNT='test-account' \
    "$backup_cli" run \
      --source "$source_db" \
      --snapshot "$snapshot_db" \
      --repository 's3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/discrawl-backups'
)"

jq -e '.database.messages == 3 and .database.directMessages == 2 and .snapshotId == "snapshot-1"' \
  <<<"$run_output" >/dev/null
grep -F 'com.emiller.discrawl-backup.r2-access-key-id' "$security_calls" >/dev/null
grep -F 'com.emiller.discrawl-backup.r2-secret-access-key' "$security_calls" >/dev/null
grep -F 'com.emiller.discrawl-backup.restic-password' "$security_calls" >/dev/null
grep -F "backup --tag discrawl $snapshot_db" "$restic_calls" >/dev/null
grep -F "snapshots --json --latest 1 --path $snapshot_db" "$restic_calls" >/dev/null
if { cat "$restic_calls"; printf '%s\n' "$run_output"; } | grep -E 'fake-(access-key|secret-key|restic-password)' >/dev/null; then
  echo 'Discrawl backup secret leaked into restic arguments or command output' >&2
  exit 1
fi
