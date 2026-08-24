#!/usr/bin/env bash
set -euo pipefail

backup_cli="${1:?usage: screentime-backup.test.sh SCREENTIME_BACKUP_CLI}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/screentime-backup.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

source_db="$fixture/knowledgeC.db"
archive_db="$fixture/state/history.sqlite"

sqlite3 "$source_db" <<'SQL'
CREATE TABLE ZOBJECT (
  Z_PK INTEGER PRIMARY KEY,
  ZUUID TEXT,
  ZSTREAMNAME TEXT,
  ZSTARTDATE REAL,
  ZENDDATE REAL,
  ZVALUESTRING TEXT,
  ZSECONDSFROMGMT INTEGER,
  ZCREATIONDATE REAL,
  ZLOCALCREATIONDATE REAL,
  ZVALUEINTEGER INTEGER,
  ZVALUEDOUBLE REAL,
  ZMETADATA BLOB
);
INSERT INTO ZOBJECT VALUES
  (1, 'uuid-a', '/app/usage', 100.0, 160.0, 'com.example.alpha', -18000, 161.0, 161.0, NULL, NULL, X'0102'),
  (2, 'uuid-b', '/app/usage', 200.0, 320.0, 'com.example.beta', -18000, 321.0, 321.0, NULL, NULL, NULL),
  (3, 'uuid-media', '/app/mediaUsage', 100.0, 999.0, 'com.example.media', -18000, 999.0, 999.0, NULL, NULL, NULL);
SQL

mkdir -p "$(dirname "$archive_db")"
sqlite3 "$archive_db" 'PRAGMA user_version = 0;'
chmod 0755 "$(dirname "$archive_db")"
chmod 0644 "$archive_db"

first_output="$($backup_cli archive --source "$source_db" --archive "$archive_db")"
grep -F '"inserted":2' <<<"$first_output" >/dev/null
grep -F '"total":2' <<<"$first_output" >/dev/null
grep -E '"archivedAt":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' <<<"$first_output" >/dev/null

test "$(sqlite3 "$archive_db" 'SELECT COUNT(*) FROM app_usage;')" = 2
test "$(sqlite3 "$archive_db" "SELECT bundle_id FROM app_usage WHERE uuid='uuid-a';")" = com.example.alpha
test "$(sqlite3 "$archive_db" "SELECT hex(metadata) FROM app_usage WHERE uuid='uuid-a';")" = 0102
test "$(stat -c '%a' "$(dirname "$archive_db")")" = 700
test "$(stat -c '%a' "$archive_db")" = 600

sqlite3 "$source_db" <<'SQL'
UPDATE ZOBJECT SET ZVALUESTRING = 'com.example.changed' WHERE ZUUID = 'uuid-a';
INSERT INTO ZOBJECT VALUES
  (4, 'uuid-c', '/app/usage', 400.0, 430.0, 'com.example.gamma', -18000, 431.0, 431.0, NULL, NULL, NULL);
SQL

second_output="$($backup_cli archive --source "$source_db" --archive "$archive_db")"
grep -F '"inserted":1' <<<"$second_output" >/dev/null
grep -F '"total":3' <<<"$second_output" >/dev/null

test "$(sqlite3 "$archive_db" 'SELECT COUNT(*) FROM app_usage;')" = 3
test "$(sqlite3 "$archive_db" "SELECT bundle_id FROM app_usage WHERE uuid='uuid-a';")" = com.example.alpha
test "$(sqlite3 "$archive_db" "SELECT bundle_id FROM app_usage WHERE uuid='uuid-c';")" = com.example.gamma

sqlite3 "$source_db" <<'SQL'
INSERT INTO ZOBJECT VALUES
  (5, NULL, '/app/usage', 500.0, 530.0, 'com.example.missing-uuid', -18000, 531.0, 531.0, NULL, NULL, NULL);
SQL

if "$backup_cli" archive --source "$source_db" --archive "$archive_db" >"$fixture/missing.out" 2>"$fixture/missing.err"; then
  echo "expected an app usage row without ZUUID to fail" >&2
  exit 1
fi
grep -F '1 /app/usage row(s) have no UUID' "$fixture/missing.err" >/dev/null
test "$(sqlite3 "$archive_db" 'SELECT COUNT(*) FROM app_usage;')" = 3

sqlite3 "$source_db" "DELETE FROM ZOBJECT WHERE ZUUID IS NULL;"
mkdir -p "$fixture/fake-bin"
security_calls="$fixture/security.calls"
restic_calls="$fixture/restic.calls"

if "$backup_cli" run \
  --source "$source_db" \
  --archive "$archive_db" \
  --repository 's3:https://wrong-account.r2.cloudflarestorage.com/screentime-backups' \
  >"$fixture/wrong-account.out" 2>"$fixture/wrong-account.err"; then
  echo 'expected a different R2 account hostname to fail' >&2
  exit 1
fi
grep -F 'repository must target the dedicated private screentime-backups R2 bucket' \
  "$fixture/wrong-account.err" >/dev/null

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
  com.emiller.screentime-backup.r2-access-key-id) printf '%s\n' 'fake-access-key' ;;
  com.emiller.screentime-backup.r2-secret-access-key) printf '%s\n' 'fake-secret-key' ;;
  com.emiller.screentime-backup.restic-password) printf '%s\n' 'fake-restic-password' ;;
  *) printf 'unexpected Keychain service: %s\n' "$service" >&2; exit 1 ;;
esac
SH

cat >"$fixture/fake-bin/restic" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${RESTIC_REPOSITORY:-}" == 's3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/screentime-backups' ]]
[[ "${AWS_ACCESS_KEY_ID:-}" == 'fake-access-key' ]]
[[ "${AWS_SECRET_ACCESS_KEY:-}" == 'fake-secret-key' ]]
[[ "${RESTIC_PASSWORD:-}" == 'fake-restic-password' ]]
printf '%s\n' "$*" >>"$RESTIC_CALLS"
case "$1" in
  backup)
    archive_path="${@: -1}"
    [[ -s "$archive_path" ]]
    ;;
  snapshots)
    printf '%s\n' '[{"id":"snapshot-1","short_id":"snapshot","paths":["history.sqlite"]}]'
    ;;
  *) printf 'unexpected restic command: %s\n' "$1" >&2; exit 1 ;;
esac
SH
chmod +x "$fixture/fake-bin/security" "$fixture/fake-bin/restic"

run_output="$(
  SECURITY_CALLS="$security_calls" \
  RESTIC_CALLS="$restic_calls" \
  SCREENTIME_BACKUP_SECURITY="$fixture/fake-bin/security" \
  SCREENTIME_BACKUP_RESTIC="$fixture/fake-bin/restic" \
  SCREENTIME_BACKUP_KEYCHAIN_ACCOUNT='test-account' \
    "$backup_cli" run \
      --source "$source_db" \
      --archive "$archive_db" \
      --repository 's3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/screentime-backups'
)"

grep -F '"snapshotId":"snapshot-1"' <<<"$run_output" >/dev/null
grep -F 'com.emiller.screentime-backup.r2-access-key-id' "$security_calls" >/dev/null
grep -F 'com.emiller.screentime-backup.r2-secret-access-key' "$security_calls" >/dev/null
grep -F 'com.emiller.screentime-backup.restic-password' "$security_calls" >/dev/null
grep -F "backup --tag screentime $archive_db" "$restic_calls" >/dev/null
grep -F "snapshots --json --latest 1 --path $archive_db" "$restic_calls" >/dev/null
if { cat "$restic_calls"; printf '%s\n' "$run_output"; } | grep -E 'fake-(access-key|secret-key|restic-password)' >/dev/null; then
  echo 'secret leaked into restic arguments or command output' >&2
  exit 1
fi
