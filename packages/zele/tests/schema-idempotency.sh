#!/usr/bin/env bash
set -euo pipefail

schema_path=$1

check_schema() {
  awk '
    /^CREATE TABLE / && $0 !~ /^CREATE TABLE sqlite_sequence/ {
      found = 1
      if ($0 !~ /^CREATE TABLE IF NOT EXISTS /) {
        print
        invalid = 1
      }
    }
    END {
      if (!found) {
        print "No application table DDL found" > "/dev/stderr"
        exit 1
      }
      exit invalid ? 1 : 0
    }
  ' "$schema_path"
}

if [[ ${EXPECT_FAILURE:-0} == 1 ]]; then
  if check_schema; then
    echo "XPASS: generated table DDL is idempotent" >&2
    exit 1
  fi
  echo "XFAIL: generated table DDL is not idempotent"
  exit 0
fi

check_schema
