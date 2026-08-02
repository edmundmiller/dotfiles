#!/usr/bin/env bash
# Validate host-scoped Seqera MCP activation without evaluating a full host.
set -euo pipefail

repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
module="$repo_root/modules/agents/codex/default.nix"

python3 - "$module" <<'PY'
import pathlib
import subprocess
import sys
import tempfile
import textwrap

module = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
start = module.index("<<'PY'\n") + len("<<'PY'\n")
end = module.index("\n          PY", start)
activation = textwrap.dedent(module[start:end])

with tempfile.TemporaryDirectory() as directory:
    config = pathlib.Path(directory) / "config.toml"
    config.write_text(
        '[mcp_servers.seqera]\nurl = "https://old.example/mcp"\n\n'
        '[mcp_servers.seqera.headers]\nAuthorization = "Bearer stale"\n\n'
        '[features]\nmemories = true\n\n'
        '[mcp_servers.fff]\ncommand = "fff-mcp"\n',
        encoding="utf-8",
    )

    def activate(enabled):
        subprocess.run([sys.executable, "-c", activation, str(config), str(enabled)], check=True)
        return config.read_text(encoding="utf-8")

    enabled = activate(1)
    assert enabled.count("[mcp_servers.seqera]") == 1, enabled
    assert 'url = "https://mcp.seqera.io/mcp"' in enabled, enabled
    assert "[mcp_servers.fff]" in enabled, enabled
    assert "[mcp_servers.seqera.headers]" not in enabled, enabled
    assert "[features]\nmemories = true\nrmcp_client = true" in enabled, enabled
    assert activate(1) == enabled
    assert "[mcp_servers.seqera]" not in activate(0)
PY
