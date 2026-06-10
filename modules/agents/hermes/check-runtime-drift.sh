#!/usr/bin/env bash
# Warning-only Hermes runtime drift check for prek/pre-push.
set -euo pipefail

warned=0
warn() {
  warned=1
  printf 'WARN: %s\n' "$*" >&2
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
hermes_home="${HERMES_HOME:-$HOME/.hermes}"
config_source="$repo_root/config/hermes/config.yml"
soul_source="$repo_root/config/hermes/SOUL.md"

if [ ! -d "$hermes_home" ]; then
  warn "Hermes home not found at $hermes_home; run hey re before using hermes."
else
  config_target="$hermes_home/config.yaml"
  soul_target="$hermes_home/SOUL.md"

  if [ ! -f "$config_target" ]; then
    warn "Hermes config missing at $config_target; run hey re."
  elif [ -f "$config_source" ] && [ "$config_source" -nt "$config_target" ]; then
    warn "Repo Hermes config is newer than $config_target; run hey re."
  fi

  if [ ! -f "$soul_target" ]; then
    warn "Hermes SOUL.md missing at $soul_target; run hey re."
  elif [ -f "$soul_source" ] && ! cmp -s "$soul_source" "$soul_target"; then
    warn "Hermes SOUL.md differs from repo source; run hey re."
  fi

  while IFS= read -r warning; do
    [ -n "$warning" ] && warn "$warning"
  done < <("${PYTHON_BIN:-python3}" - "$repo_root/config/hermes" "$hermes_home" <<'PY' || true
import filecmp
import pathlib
import sys

source_root = pathlib.Path(sys.argv[1])
target_root = pathlib.Path(sys.argv[2])
checks = {
    "skins": {".yaml", ".yml"},
    "hooks": None,
    "plugins": None,
}

for name, suffixes in checks.items():
    source_dir = source_root / name
    target_dir = target_root / name
    if not source_dir.is_dir():
        continue
    if not target_dir.is_dir():
        print(f"Hermes runtime directory missing: {target_dir}; run hey re.")
        continue

    missing = 0
    changed = 0
    for source in source_dir.rglob("*"):
        if not source.is_file():
            continue
        if suffixes is not None and source.suffix.lower() not in suffixes:
            continue
        target = target_dir / source.relative_to(source_dir)
        if not target.exists():
            missing += 1
        elif not filecmp.cmp(source, target, shallow=False):
            changed += 1

    if missing or changed:
        print(
            f"Hermes {name} drift: {missing} missing, {changed} changed repo-managed file(s); run hey re."
        )
PY
)
fi

if ! command -v hermes >/dev/null 2>&1; then
  warn "hermes not found on PATH."
fi

if command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r unit; do
    [ -n "$unit" ] || continue
    state="$(systemctl is-active "$unit" 2>/dev/null || true)"
    case "$state" in
      active|activating|inactive) ;;
      failed) warn "Hermes service unit is failed: $unit" ;;
      *) warn "Hermes service unit has unexpected state '$state': $unit" ;;
    esac
  done < <(systemctl list-unit-files 'hermes*.service' --no-legend --no-pager 2>/dev/null | awk '{print $1}' || true)
fi

if [ "$warned" -ne 0 ]; then
  cat >&2 <<'EOF'
Hermes runtime drift detected. Suggested fix:
  hey re
EOF
fi

exit 0
