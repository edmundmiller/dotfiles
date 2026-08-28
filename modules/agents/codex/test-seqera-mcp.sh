#!/usr/bin/env bash
# Validate host-scoped managed MCP activation without evaluating a full host.
set -euo pipefail

if [[ "$(uname -s)" == "Darwin" && "$BASH" != "/bin/bash" ]]; then
    exec /bin/bash "$0" "$@"
fi

repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
module="$repo_root/modules/agents/codex/default.nix"
reconciler="$repo_root/config/codex/reconcile_mcp.py"
launcher="$repo_root/config/codex/codex-ha.sh"
host="$repo_root/hosts/mactraitorpro/default.nix"

grep -Fq "builtins.readFile \"\${configDir}/codex/reconcile_mcp.py\"" "$module"
grep -Fq "builtins.readFile \"\${configDir}/codex/codex-ha.sh\"" "$module"
grep -Fq -- '--legacy-cleanup' "$module"
grep -Fq 'secretReference = "op://Agents/Hermes Laptop HA/credential";' "$host"
test -f "$reconciler"
test -f "$launcher"

python3 - "$reconciler" <<'PY'
import importlib.util
import pathlib
import stat
import subprocess
import sys
import tempfile
import tomllib
from unittest import mock

reconciler = pathlib.Path(sys.argv[1])
assert reconciler.is_file(), reconciler

with tempfile.TemporaryDirectory() as directory:
    config = pathlib.Path(directory) / "config.toml"
    sentinel = pathlib.Path(directory) / "unrelated"
    sentinel.write_text("untouched\n", encoding="utf-8")
    config.write_text(
        '[[hooks.PostToolUse]]\n\n'
        '[[hooks.PostToolUse.hooks]]\n'
        'command = "/Users/emiller/.git-ai/bin/git-ai checkpoint codex --hook-input stdin"\n'
        'type = "command"\n\n'
        '[ mcp_servers . seqera ] # stale\nurl = "https://old.example/mcp"\n\n'
        '[ mcp_servers . seqera . headers ]\nAuthorization = "Bearer stale"\n\n'
        '[ features ] # retained\nmemories = true\n\n'
        '  [mcp_servers.fff] # unrelated and indented\ncommand = "fff-mcp"\n\n'
        '  [ mcp_servers . homeassistant ] # stale and indented\n'
        'url = "https://old.example/home"\n\n'
        '\t[ mcp_servers . homeassistant . headers ]\n'
        'Authorization = "Bearer stale"\n\n'
        '  [ mcp_servers . codegraph ] # legacy and indented\n'
        'command = "codegraph-mcp"\n\n'
        '  [ mcp_servers . node_repl ] # legacy and indented\n'
        'command = "node-repl-mcp"\n',
        encoding="utf-8",
    )
    config.chmod(0o600)

    def activate(
        seqera_enabled,
        home_assistant_enabled,
        *,
        dry_run=False,
        legacy_cleanup=False,
    ):
        command = [sys.executable, str(reconciler)]
        if dry_run:
            command.append("--dry-run")
        if legacy_cleanup:
            command.append("--legacy-cleanup")
        command.extend([str(config), str(seqera_enabled), str(home_assistant_enabled)])
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
        return config.read_text(encoding="utf-8"), result.stdout

    before_dry_run = config.read_text(encoding="utf-8")
    after_dry_run, dry_run_output = activate(1, 0, dry_run=True)
    assert after_dry_run == before_dry_run
    assert dry_run_output == "would_change=true\n"
    assert sentinel.read_text(encoding="utf-8") == "untouched\n"

    before_inode = config.stat().st_ino
    enabled, output = activate(1, 0)
    assert output == "changed=true\n"
    assert config.stat().st_ino != before_inode
    assert stat.S_IMODE(config.stat().st_mode) == 0o600
    assert enabled.count("[mcp_servers.seqera]") == 1, enabled
    assert 'url = "https://mcp.seqera.io/mcp"' in enabled, enabled
    unrelated_fff = (
        '  [mcp_servers.fff] # unrelated and indented\ncommand = "fff-mcp"\n'
    )
    assert unrelated_fff in enabled, enabled
    assert "Bearer stale" not in enabled, enabled
    assert "old.example" not in enabled, enabled
    assert "[ mcp_servers . codegraph ] # legacy and indented" in enabled, enabled
    assert "[ mcp_servers . node_repl ] # legacy and indented" in enabled, enabled
    assert "git-ai checkpoint codex" in enabled, enabled
    assert (
        "[ features ] # retained\nmemories = true\nrmcp_client = true" in enabled
    ), enabled
    assert "fff-mcp" in enabled, enabled
    assert "memories = true" in enabled, enabled
    parsed_enabled = tomllib.loads(enabled)
    assert parsed_enabled["features"]["rmcp_client"] is True
    assert "rmcp_client" not in parsed_enabled["mcp_servers"]["fff"]
    assert activate(1, 0) == (enabled, "changed=false\n")

    normal_activation, _ = activate(1, 0, legacy_cleanup=True)
    assert "codegraph-mcp" not in normal_activation, normal_activation
    assert "node-repl-mcp" not in normal_activation, normal_activation
    assert "git-ai checkpoint codex" not in normal_activation, normal_activation

    home_assistant, _ = activate(0, 1)
    assert "[mcp_servers.seqera]" not in home_assistant, home_assistant
    assert "mcp_oauth_callback_port" not in home_assistant, home_assistant
    assert home_assistant.count("[mcp_servers.homeassistant]") == 1, home_assistant
    assert 'url = "https://homeassistant.cinnamon-rooster.ts.net/api/mcp"' in home_assistant
    assert 'bearer_token_env_var = "HASS_TOKEN"' in home_assistant
    assert 'auth = "oauth"' not in home_assistant
    assert "oauth =" not in home_assistant
    assert "Bearer stale" not in home_assistant
    assert unrelated_fff in home_assistant
    assert "memories = true" in home_assistant
    parsed_home_assistant = tomllib.loads(home_assistant)
    assert parsed_home_assistant["features"]["rmcp_client"] is True
    assert "rmcp_client" not in parsed_home_assistant["mcp_servers"]["fff"]
    assert activate(0, 1) == (home_assistant, "changed=false\n")

    config.write_text(
        "mcp_oauth_callback_port = 23456\n\n" + home_assistant,
        encoding="utf-8",
    )
    custom_callback, _ = activate(0, 1)
    assert custom_callback.startswith("mcp_oauth_callback_port = 23456\n")
    assert 'bearer_token_env_var = "HASS_TOKEN"' in custom_callback
    disabled, _ = activate(0, 0)
    assert "[mcp_servers.homeassistant]" not in disabled
    assert disabled.startswith("mcp_oauth_callback_port = 23456\n")
    assert sentinel.read_text(encoding="utf-8") == "untouched\n"
    assert not list(pathlib.Path(directory).glob(".config.toml.*"))

    spec = importlib.util.spec_from_file_location("codex_mcp_reconciler", reconciler)
    reconcile_module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(reconcile_module)
    before_failed_replace = config.read_text(encoding="utf-8")
    with mock.patch.object(
        reconcile_module.os,
        "replace",
        side_effect=OSError("simulated replace failure"),
    ):
        try:
            reconcile_module.replace_atomically(config, "replacement\n")
        except OSError as error:
            assert str(error) == "simulated replace failure"
        else:
            raise AssertionError("atomic replacement failure was not propagated")
    assert config.read_text(encoding="utf-8") == before_failed_replace
    assert not list(pathlib.Path(directory).glob(".config.toml.*"))

    referent = pathlib.Path(directory) / "referent.toml"
    referent.write_text('[features]\nrmcp_client = true\n', encoding="utf-8")
    symlink = pathlib.Path(directory) / "symlink.toml"
    symlink.symlink_to(referent)
    rejected = subprocess.run(
        [sys.executable, str(reconciler), str(symlink), "0", "1"],
        capture_output=True,
        text=True,
    )
    assert rejected.returncode != 0
    assert referent.read_text(encoding="utf-8") == '[features]\nrmcp_client = true\n'

    non_file = pathlib.Path(directory) / "non-file"
    non_file.mkdir()
    rejected = subprocess.run(
        [sys.executable, str(reconciler), str(non_file), "0", "1"],
        capture_output=True,
        text=True,
    )
    assert rejected.returncode != 0

    unsupported = pathlib.Path(directory) / "unsupported.toml"
    unsupported.write_text(
        '["mcp_servers"."homeassistant"]\nurl = "https://stale.example/mcp"\n',
        encoding="utf-8",
    )
    before_unsupported = unsupported.read_text(encoding="utf-8")
    rejected = subprocess.run(
        [sys.executable, str(reconciler), str(unsupported), "0", "1"],
        capture_output=True,
        text=True,
    )
    assert rejected.returncode != 0
    assert unsupported.read_text(encoding="utf-8") == before_unsupported
PY

launcher_tmp="$(mktemp -d)"
trap 'rm -rf "$launcher_tmp"' EXIT
fake_op="$launcher_tmp/op"
# shellcheck disable=SC2016
printf '%s\n' \
    '#!/bin/sh' \
    'printf "HASS_TOKEN=%s\n" "$HASS_TOKEN"' \
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
grep -Fqx 'ARGS=run|--|/usr/bin/true|--version|' <<<"$launcher_output"
