#!/usr/bin/env bash
# Validate the shared OMP MCP policy before Nix renders host overlays.
# Run: bash modules/agents/omp/test-mcp-json.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
config="${OMP_MCP_JSON:-$repo_root/config/omp/mcp.json}"

if [[ ! -f "$config" ]]; then
  echo "FAIL: missing $config" >&2
  exit 1
fi

OMP_MCP_JSON="$config" python3 - <<'PY'
import json
import os
from pathlib import Path

config = json.loads(Path(os.environ["OMP_MCP_JSON"]).read_text())
expected_servers = {"fff": {"command": "fff-mcp"}}
expected_disabled = ["context7:context7", "strava-mcp"]

if config.get("mcpServers") != expected_servers:
    raise SystemExit(f"FAIL: expected only {expected_servers!r} in mcpServers")
if config.get("disabledServers") != expected_disabled:
    raise SystemExit(f"FAIL: expected disabledServers {expected_disabled!r}")

print("PASS: shared OMP MCP policy is valid")
PY
