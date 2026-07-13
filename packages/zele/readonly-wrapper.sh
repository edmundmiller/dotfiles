#!/bin/sh
set -eu

real_zele="${ZELE_REAL_BIN:-@ZELE_REAL@}"
primary=""
secondary=""
skip_account_value=0
has_draft=0
has_dry_run=0
has_meta_flag=0

for arg in "$@"; do
  if [ "$skip_account_value" -eq 1 ]; then
    skip_account_value=0
    continue
  fi

  case "$arg" in
    --account)
      skip_account_value=1
      ;;
    --account=*)
      ;;
    --draft)
      has_draft=1
      ;;
    --dry-run)
      has_dry_run=1
      ;;
    -h|--help|-v|--version)
      has_meta_flag=1
      ;;
    --*)
      ;;
    *)
      if [ -z "$primary" ]; then
        primary="$arg"
      elif [ -z "$secondary" ]; then
        secondary="$arg"
      fi
      ;;
  esac
done

deny() {
  printf '%s\n' 'zele is read-only: outbound mail is disabled; create a draft instead.' >&2
  exit 78
}

if [ -z "$primary" ]; then
  if [ "$has_meta_flag" -eq 1 ]; then
    exec "$real_zele" "$@"
  fi
  deny
fi

case "$primary:$secondary" in
  mail:send|draft:send)
    deny
    ;;
  mail:reply|mail:forward)
    if [ "$has_draft" -ne 1 ]; then
      deny
    fi
    ;;
  mail:unsubscribe)
    if [ "$has_dry_run" -ne 1 ]; then
      deny
    fi
    ;;
esac

exec "$real_zele" "$@"
