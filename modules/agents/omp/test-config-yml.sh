#!/usr/bin/env bash
# Validate config/omp/config.yml against the live OMP settings registry.
# Mirrors modules/agents/pi/test-settings-json.sh for OMP's YAML config.
# Run: bash modules/agents/omp/test-config-yml.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
config="${OMP_CONFIG_YML:-$repo_root/config/omp/config.yml}"
omp_bin="${OMP_BIN:-omp}"
yq_bin="${OMP_CONFIG_YQ:-yq}"

if ! command -v "$omp_bin" >/dev/null 2>&1; then
  echo "FAIL: omp not on PATH (set OMP_BIN)" >&2
  exit 1
fi
if ! command -v "$yq_bin" >/dev/null 2>&1; then
  echo "FAIL: yq not on PATH (set OMP_CONFIG_YQ)" >&2
  exit 1
fi
if [[ ! -f "$config" ]]; then
  echo "FAIL: missing $config" >&2
  exit 1
fi

registry_json="$("$omp_bin" config list --json)"
config_json="$("$yq_bin" -o=json "$config")"

OMP_CONFIG_JSON="$config_json" OMP_REGISTRY_JSON="$registry_json" python3 - <<'PY'
import json
import os
import sys

cfg = json.loads(os.environ["OMP_CONFIG_JSON"])
reg = json.loads(os.environ["OMP_REGISTRY_JSON"])

# Stale keys OMP still accepts only to delete, or never owned as settings.
# Map old path -> replacement (None = delete).
LEGACY = {
    "tools.discoveryMode": None,  # stripped in OMP migrateRawSettings
    "tools.essentialOverride": None,
    "tools.grepContextBefore": "grep.contextBefore",
    "tools.grepContextAfter": "grep.contextAfter",
    "hooks.enabled": None,  # hooks load via extensions/, not settings
    "hooks.timeoutMs": None,
}


def flatten(obj, prefix=""):
    out = {}
    if isinstance(obj, dict):
        for key, value in obj.items():
            path = f"{prefix}.{key}" if prefix else str(key)
            if isinstance(value, dict):
                if path in reg and reg[path].get("type") in ("record", "object"):
                    out[path] = value
                    continue
                nested = flatten(value, path)
                if any(child in reg for child in nested):
                    out.update(nested)
                elif path in reg:
                    out[path] = value
                else:
                    out.update(nested if nested else {path: value})
            else:
                out[path] = value
    else:
        out[prefix] = obj
    return out


flat = flatten(cfg)
errors = []

for path, value in sorted(flat.items()):
    if path in LEGACY:
        replacement = LEGACY[path]
        if replacement is None:
            errors.append(f"{path}: removed/legacy setting; delete it")
        else:
            errors.append(f"{path}: renamed; use {replacement}")
        continue
    if path not in reg:
        errors.append(f"{path}: unknown setting (not in omp config list)")
        continue

    expected = reg[path].get("type")
    ok = True
    if expected == "boolean":
        ok = isinstance(value, bool)
    elif expected == "number":
        ok = isinstance(value, (int, float)) and not isinstance(value, bool)
    elif expected in ("string", "enum"):
        ok = isinstance(value, str)
    elif expected == "array":
        ok = isinstance(value, list)
    elif expected in ("record", "object"):
        ok = isinstance(value, dict)
    if not ok:
        errors.append(
            f"{path}: type {type(value).__name__} incompatible with registry type {expected}"
        )

if errors:
    print("FAIL: config/omp/config.yml does not match OMP settings registry", file=sys.stderr)
    for err in errors:
        print(f"  - {err}", file=sys.stderr)
    raise SystemExit(1)

print(f"PASS: config/omp/config.yml ({len(flat)} keys) matches omp config registry")
PY
