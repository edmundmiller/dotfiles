#!/usr/bin/env bash
set -euo pipefail
expected_host=$1
expected_revision=$2
service_one=$3
service_two=$4
disabled_timer=$5
expected_platform=$6
shift 6
hostname=$(hostname -s)
printf 'hostname=%s\n' "$hostname"
uname -a
test "$hostname" = "$expected_host"
platform=$(uname -s)
test "$platform" = "$expected_platform"
"$@"
actual=$(nixos-version --configuration-revision)
printf 'configurationRevision=%s\n' "$actual"
test "$actual" = "$expected_revision"
systemctl is-active "$service_one"
systemctl is-active "$service_two"
if systemctl is-active --quiet "$disabled_timer" || systemctl is-enabled --quiet "$disabled_timer"; then
  printf 'unexpected automatic upgrade timer\n' >&2
  exit 1
fi
systemctl --failed --no-pager
