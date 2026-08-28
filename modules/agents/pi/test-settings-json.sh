#!/usr/bin/env bash
# Validate Pi settings source JSONC against the local JSON schema.
# Run: bash modules/agents/pi/test-settings-json.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
settings="$repo_root/config/pi/settings.jsonc"
schema="$repo_root/config/pi/settings-schema.json"
python_bin="${PI_SETTINGS_JSON_PYTHON:-python3}"

# If the active Python cannot import jsonschema, re-exec once with a Nix Python
# before the inline validator emits its normal missing-module error.
if ! "$python_bin" -c 'import jsonschema' >/dev/null 2>&1; then
  if [[ -z "${PI_SETTINGS_JSON_PYTHON:-}" && -z "${PI_SETTINGS_JSON_NIX_FALLBACK:-}" ]] \
    && command -v nix >/dev/null 2>&1; then
    export PI_SETTINGS_JSON_NIX_FALLBACK=1
    exec nix shell --impure \
      --expr 'with import <nixpkgs> { overlays = []; }; python3.withPackages (ps: [ ps.jsonschema ])' \
      -c bash "$0" "$@"
  fi
fi

exec "$python_bin" "$repo_root/modules/agents/pi/validate-settings-json.py" "$settings" "$schema"
