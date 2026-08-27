#!/usr/bin/env bash
# Validate host-scoped managed MCP activation without evaluating a full host.
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
        '[mcp_servers.homeassistant]\nurl = "https://old.example/home"\n\n'
        '[mcp_servers.homeassistant.headers]\nAuthorization = "Bearer stale"\n\n'
        '[features]\nmemories = true\n\n'
        '[mcp_servers.fff]\ncommand = "fff-mcp"\n',
        encoding="utf-8",
    )

    def activate(seqera_enabled, home_assistant_enabled):
        subprocess.run(
            [
                sys.executable,
                "-c",
                activation,
                str(config),
                str(seqera_enabled),
                str(home_assistant_enabled),
            ],
            check=True,
        )
        return config.read_text(encoding="utf-8")

    enabled = activate(1, 0)
    assert enabled.count("[mcp_servers.seqera]") == 1, enabled
    assert 'url = "https://mcp.seqera.io/mcp"' in enabled, enabled
    assert "[mcp_servers.fff]" in enabled, enabled
    assert "[mcp_servers.seqera.headers]" not in enabled, enabled
    assert "[mcp_servers.homeassistant]" not in enabled, enabled
    assert "[features]\nmemories = true\nrmcp_client = true" in enabled, enabled
    assert activate(1, 0) == enabled

    home_assistant = activate(0, 1)
    assert "[mcp_servers.seqera]" not in home_assistant, home_assistant
    assert home_assistant.startswith("mcp_oauth_callback_port = 12345\n"), home_assistant
    assert home_assistant.count("[mcp_servers.homeassistant]") == 1, home_assistant
    assert 'url = "https://homeassistant.cinnamon-rooster.ts.net/api/mcp"' in home_assistant
    assert 'auth = "oauth"' in home_assistant
    assert 'oauth = { client_id = "http://127.0.0.1:12345" }' in home_assistant
    assert activate(0, 1) == home_assistant

    config.write_text(
        home_assistant.replace(
            "mcp_oauth_callback_port = 12345",
            "mcp_oauth_callback_port = 23456",
        ),
        encoding="utf-8",
    )
    custom_callback = activate(0, 1)
    assert 'oauth = { client_id = "http://127.0.0.1:23456" }' in custom_callback
    assert "[mcp_servers.homeassistant]" not in activate(0, 0)
PY
