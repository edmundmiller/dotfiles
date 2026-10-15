#!/usr/bin/env bash
# Verify credential-reference forwarding without resolving a real secret.
set -euo pipefail
repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
launcher="$repo_root/config/codex/codex-ha.sh"
launcher_tmp="$(mktemp -d)"
trap 'rm -rf "$launcher_tmp"' EXIT
fake_op="$launcher_tmp/op"
# shellcheck disable=SC2016
printf '%s\n' \
    '#!/bin/sh' \
    'printf "HASS_TOKEN=%s\n" "$HASS_TOKEN"' \
    'printf "OP_BIOMETRIC_UNLOCK_ENABLED=%s\n" "$OP_BIOMETRIC_UNLOCK_ENABLED"' \
    'printf "ARGS="' \
    'printf "%s|" "$@"' \
    'printf "\n"' >"$fake_op"
chmod 0700 "$fake_op"
launcher_output="$({
    CODEX_BIN=/usr/bin/true \
        CODEX_HOME_ASSISTANT_SECRET_REFERENCE='op://Test/Home Assistant/token' \
        OP_BIN="$fake_op" \
        bash "$launcher" --version
})"
grep -Fqx 'HASS_TOKEN=op://Test/Home Assistant/token' <<<"$launcher_output"
grep -Fqx 'OP_BIOMETRIC_UNLOCK_ENABLED=true' <<<"$launcher_output"
grep -Fqx 'ARGS=run|--|/usr/bin/true|--disable|tui_app_server|--version|' <<<"$launcher_output"

launcher_override_output="$({
    CODEX_BIN=/usr/bin/true \
        CODEX_HOME_ASSISTANT_SECRET_REFERENCE='op://Test/Home Assistant/token' \
        OP_BIOMETRIC_UNLOCK_ENABLED=false \
        OP_BIN="$fake_op" \
        bash "$launcher" --version
})"
grep -Fqx 'OP_BIOMETRIC_UNLOCK_ENABLED=false' <<<"$launcher_override_output"
