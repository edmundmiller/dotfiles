#!/usr/bin/env bash
set -euo pipefail
expected_host=$1
expected_revision=$2
service_one=$3
service_two=$4
disabled_timer=$5
expected_platform=$6
privilege=$7
guard_revision=$8
home_assistant_flag=$9
target_revision=${10}
shift 10
hostname=$(hostname -s)
printf 'hostname=%s\n' "$hostname"
uname -a
test "$hostname" = "$expected_host"
platform=$(uname -s)
test "$platform" = "$expected_platform"
# Materialize the dispatching source's guard; the installed wrapper may predate it.
# It still acquires the canonical host deployment lock.
source_json=$("$privilege" -n nix-private-github nix flake prefetch --json "github:edmundmiller/dotfiles/$guard_revision")
source=$(printf %s "$source_json" | jq -er .storePath)
test -f "$source/bin/nix-private-github"
"$privilege" -n bash "$source/bin/nix-private-github" "$home_assistant_flag" "$@"
actual=$(nixos-version --configuration-revision)
printf 'configurationRevision=%s\n' "$actual"
test "$actual" = "$expected_revision"
systemctl is-active "$service_one"
systemctl is-active "$service_two"
if systemctl is-active --quiet "$disabled_timer" || systemctl is-enabled --quiet "$disabled_timer"; then
  printf 'unexpected automatic upgrade timer\n' >&2
  exit 1
fi
"$privilege" -n python3 "$source/scripts/verify_hermes_retirement.py" "$target_revision"
systemctl --failed --no-pager
