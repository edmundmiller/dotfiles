#!/usr/bin/env bash
# Validate the OMP MCP configuration rendered for each Darwin host.
set -euo pipefail

repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

declare -A users=(
    ["MacTraitor-Pro"]=emiller
    [Seqeratop]=edmundmiller
)

for host in "${!users[@]}"; do
    attr="path:$repo_root#darwinConfigurations.${host}.config.home-manager.users.${users[$host]}.home.file.\".omp/agent/mcp.json\".source"
    mcp_config="$(nix build --no-link --print-out-paths "$attr")"

    OMP_MCP_CONFIG="$mcp_config" OMP_MCP_HOST="$host" python3 - <<'PY'
import json
import os
from pathlib import Path

config = json.loads(Path(os.environ["OMP_MCP_CONFIG"]).read_text())
host = os.environ["OMP_MCP_HOST"]

assert config["disabledServers"] == ["context7:context7", "strava-mcp"], host
expected_servers = {"fff"}
if host == "Seqeratop":
    expected_servers.add("seqera")
    assert config["mcpServers"]["seqera"] == {
        "type": "http",
        "url": "https://mcp.seqera.io/mcp",
    }, config["mcpServers"]["seqera"]
assert set(config["mcpServers"]) == expected_servers, host
command = config["mcpServers"]["fff"]["command"]
assert command.endswith("/bin/fff-mcp"), command
assert os.access(command, os.X_OK), command
PY
done
