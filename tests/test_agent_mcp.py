import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import json5
import tomlkit


SCRIPT = Path(__file__).resolve().parents[1] / "config/agents/reconcile_mcp.py"
PATHS = {
    "pi": ".pi/agent/mcp.json",
    "omp": ".omp/agent/mcp.json",
    "claude": ".claude.json",
    "codex": ".codex/config.toml",
    "opencode": ".config/opencode2/opencode/opencode.jsonc",
    "amp": ".config/amp/settings.json",
}
EXPECTED = {
    "pi": {
        "tools": {
            "command": "tool-runner",
            "args": ["--mode", "safe"],
            "env": {"WORKSPACE": "/work/demo"},
            "exposure": "codemode",
        },
        "remote": {
            "url": "https://mcp.example.test/v1",
            "exposure": "codemode",
            "headers": {"Authorization": "Bearer ${MCP_TEST_TOKEN}"},
        },
    },
    "omp": {
        "tools": {
            "type": "stdio",
            "command": "tool-runner",
            "args": ["--mode", "safe"],
            "env": {"WORKSPACE": "/work/demo"},
        },
        "remote": {
            "type": "http",
            "url": "https://mcp.example.test/v1",
            "headers": {"Authorization": "Bearer ${MCP_TEST_TOKEN}"},
        },
    },
    "claude": {
        "tools": {
            "type": "stdio",
            "command": "tool-runner",
            "args": ["--mode", "safe"],
            "env": {"WORKSPACE": "/work/demo"},
        },
        "remote": {
            "type": "http",
            "url": "https://mcp.example.test/v1",
            "headers": {"Authorization": "Bearer ${MCP_TEST_TOKEN}"},
        },
    },
    "codex": {
        "tools": {
            "command": "tool-runner",
            "args": ["--mode", "safe"],
            "env": {"WORKSPACE": "/work/demo"},
        },
        "remote": {
            "url": "https://mcp.example.test/v1",
            "bearer_token_env_var": "MCP_TEST_TOKEN",
        },
    },
    "opencode": {
        "tools": {
            "type": "local",
            "command": ["tool-runner", "--mode", "safe"],
            "environment": {"WORKSPACE": "/work/demo"},
        },
        "remote": {
            "type": "remote",
            "url": "https://mcp.example.test/v1",
            "oauth": False,
            "headers": {"Authorization": "Bearer {env:MCP_TEST_TOKEN}"},
        },
    },
    "amp": {
        "tools": {
            "command": "tool-runner",
            "args": ["--mode", "safe"],
            "env": {"WORKSPACE": "/work/demo"},
        },
        "remote": {
            "url": "https://mcp.example.test/v1",
            "headers": {"Authorization": "Bearer ${MCP_TEST_TOKEN}"},
        },
    },
}


class AgentMcpCliTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.manifest_path = self.root / "manifest.json"
        self.manifest = {
            "agents": list(PATHS),
            "servers": {
                "tools": {
                    "enable": True,
                    "transport": "stdio",
                    "command": "tool-runner",
                    "args": ["--mode", "safe"],
                    "env": {"WORKSPACE": "/work/demo"},
                    "excludeAgents": [],
                },
                "remote": {
                    "enable": True,
                    "transport": "http",
                    "url": "https://mcp.example.test/v1",
                    "bearerTokenEnv": "MCP_TEST_TOKEN",
                    "excludeAgents": [],
                },
            },
        }

    def run_cli(self, *, dry_run=False, success=True, detach=False):
        self.manifest_path.write_text(json.dumps(self.manifest))
        env = dict(
            os.environ, HOME=str(self.home), MCP_TEST_TOKEN="never-expand-this-secret"
        )
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--home",
                str(self.home),
                *(["--dry-run"] if dry_run else []),
                *(["--detach-store-links"] if detach else []),
                str(self.manifest_path),
            ],
            capture_output=True,
            text=True,
            env=env,
            cwd=self.root,
            timeout=30,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def write(self, relative, text):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def read_config(self, agent):
        path = self.home / PATHS[agent]
        return (
            tomlkit.parse(path.read_text()).unwrap()
            if agent == "codex"
            else json5.loads(path.read_text())
        )

    def servers(self, agent):
        data = self.read_config(agent)
        if agent == "opencode":
            return data["mcp"]["servers"]
        return data[
            {"codex": "mcp_servers", "amp": "amp.mcpServers"}.get(agent, "mcpServers")
        ]

    def snapshot(self):
        return {
            str(path.relative_to(self.home)): (
                ("symlink", os.readlink(path))
                if path.is_symlink()
                else ("file", path.read_bytes())
                if path.is_file()
                else ("directory",)
            )
            for path in self.home.rglob("*")
        }

    def seed_configs(self):
        for agent, relative in PATHS.items():
            if agent == "codex":
                self.write(
                    relative,
                    """# User-owned settings
model = "personal-model"
[auth."account.example"]
token = "keep-auth"
[mcp_servers."personal.tool"]
command = "personal-runner"
args = ["--private"]
[mcp_servers.tools]
command = "obsolete-runner"
""",
                )
                continue
            data = {"settings": {"theme": "dark"}, "auth": {"token": "keep-auth"}}
            servers = {
                "personal.tool": {"command": "personal-runner", "args": ["--private"]},
                "tools": {"command": "obsolete-runner"},
            }
            if agent == "opencode":
                data["mcp"] = {"servers": servers, "enabled": False}
            else:
                data["amp.mcpServers" if agent == "amp" else "mcpServers"] = servers
            self.write(relative, "// User-owned settings\n" + json.dumps(data))

    def test_six_adapters_have_exact_stdio_and_bearer_http_shapes(self):
        self.run_cli()
        for agent in PATHS:
            with self.subTest(agent=agent):
                self.assertEqual(self.servers(agent), EXPECTED[agent])
        self.assertIs(self.read_config("pi")["autoEnableCodemode"], True)

    def test_each_agent_exclusion_removes_previously_managed_entry(self):
        self.run_cli()
        for agent in PATHS:
            with self.subTest(agent=agent):
                self.manifest["servers"]["remote"]["excludeAgents"] = [agent]
                self.run_cli()
                for target in PATHS:
                    expected = (
                        {"tools": EXPECTED[target]["tools"]}
                        if target == agent
                        else EXPECTED[target]
                    )
                    self.assertEqual(self.servers(target), expected)

    def test_disable_then_remove_catalog_name_and_disable_host_targets(self):
        self.seed_configs()
        self.run_cli()
        self.manifest["servers"]["remote"]["enable"] = False
        self.run_cli()
        for agent in PATHS:
            self.assertNotIn("remote", self.servers(agent))
            self.assertIn("tools", self.servers(agent))
        del self.manifest["servers"]["tools"]
        self.run_cli()
        personal = {
            "personal.tool": {"command": "personal-runner", "args": ["--private"]}
        }
        for agent in PATHS:
            self.assertEqual(self.servers(agent), personal)
        self.manifest["servers"]["remote"]["enable"] = True
        self.run_cli()
        self.manifest["agents"] = []
        self.run_cli()
        for agent in PATHS:
            self.assertEqual(self.servers(agent), personal)

    def test_preserves_unrelated_servers_settings_auth_and_quoted_toml_tables(self):
        self.seed_configs()
        self.run_cli()
        for agent in PATHS:
            with self.subTest(agent=agent):
                self.assertEqual(
                    self.servers(agent),
                    {
                        **EXPECTED[agent],
                        "personal.tool": {
                            "command": "personal-runner",
                            "args": ["--private"],
                        },
                    },
                )
                data = self.read_config(agent)
                if agent == "codex":
                    self.assertEqual(data["model"], "personal-model")
                    self.assertEqual(
                        data["auth"], {"account.example": {"token": "keep-auth"}}
                    )
                else:
                    self.assertEqual(data["settings"], {"theme": "dark"})
                    self.assertEqual(data["auth"], {"token": "keep-auth"})
        self.assertIs(self.read_config("opencode")["mcp"]["enabled"], False)

    @unittest.skipUnless(
        os.environ.get("MCP_NIX_FIXTURE"), "requires a Nix store fixture"
    )
    def test_store_symlink_migrates_to_writable_file_without_losing_settings(self):
        fixture = Path(os.environ["MCP_NIX_FIXTURE"])
        original = fixture.read_bytes()
        path = self.home / PATHS["pi"]
        path.parent.mkdir(parents=True)
        path.symlink_to(fixture)
        self.run_cli(detach=True)
        self.assertFalse(path.is_symlink())
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.run_cli()
        self.assertEqual(self.read_config("pi")["custom"], "preserved")
        self.assertEqual(fixture.read_bytes(), original)
        with path.open("a") as handle:
            handle.write("\n")

    def test_amp_jsonc_is_used_and_ambiguous_files_are_rejected_without_writes(self):
        path = self.write(
            ".config/amp/settings.jsonc", '// retained data\n{"amp.theme": "dark"}'
        )
        self.run_cli()
        data = json.loads(path.read_text())
        self.assertEqual(data["amp.theme"], "dark")
        self.assertEqual(data["amp.mcpServers"], EXPECTED["amp"])
        self.assertFalse((self.home / PATHS["amp"]).exists())
        self.write(PATHS["amp"], "{}")
        before = self.snapshot()
        self.run_cli(success=False)
        self.assertEqual(self.snapshot(), before)

    def test_repeated_runs_are_config_byte_idempotent(self):
        self.seed_configs()
        self.run_cli()
        before = self.snapshot()
        self.run_cli()
        self.run_cli()
        self.assertEqual(self.snapshot(), before)

    def test_omp_exclusions_block_inherited_servers_and_release_only_owned_names(self):
        self.write(
            PATHS["omp"],
            json.dumps(
                {
                    "disabledServers": ["personal", "tools"],
                    "enabledServers": ["remote", "other"],
                }
            ),
        )
        self.run_cli()
        self.assertEqual(self.read_config("omp")["disabledServers"], ["personal"])
        self.assertEqual(self.read_config("omp")["enabledServers"], ["other"])
        self.manifest["servers"]["remote"]["excludeAgents"] = ["omp"]
        self.run_cli()
        self.assertEqual(
            self.read_config("omp")["disabledServers"], ["personal", "remote"]
        )
        del self.manifest["servers"]["remote"]
        self.run_cli()
        self.assertEqual(self.read_config("omp")["disabledServers"], ["personal"])
        self.manifest["servers"]["tools"]["enable"] = False
        self.run_cli()
        self.assertEqual(
            self.read_config("omp")["disabledServers"], ["personal", "tools"]
        )
        self.manifest["agents"].remove("omp")
        self.run_cli()
        self.assertEqual(self.read_config("omp")["disabledServers"], ["personal"])

    def test_dry_run_creates_nothing_and_does_not_update_existing_configs(self):
        for seeded in (False, True):
            with self.subTest(seeded=seeded):
                if seeded:
                    self.seed_configs()
                    self.run_cli()
                    del self.manifest["servers"]["remote"]
                before = self.snapshot()
                result = self.run_cli(dry_run=True)
                self.assertEqual(self.snapshot(), before)
                self.assertEqual(
                    set(json.loads(result.stdout)["would_change"]),
                    {str(self.home / relative) for relative in PATHS.values()},
                )

    def test_malformed_config_fails_before_any_target_or_state_is_touched(self):
        for agent in ("pi", "codex"):
            with self.subTest(agent=agent):
                self.seed_configs()
                self.run_cli()
                self.write(
                    PATHS[agent], "[broken" if agent == "codex" else '{"broken":'
                )
                self.manifest["servers"]["remote"]["enable"] = False
                before = self.snapshot()
                self.run_cli(success=False)
                self.assertEqual(self.snapshot(), before)

    def test_refuses_non_nix_symlink_without_mutating_link_referent_or_other_targets(
        self,
    ):
        self.seed_configs()
        external = self.root / "external.json"
        external.write_text('{"mcpServers": {"private": {"command": "keep"}}}\n')
        path = self.home / PATHS["pi"]
        path.unlink()
        path.symlink_to(external)
        before = self.snapshot()
        result = self.run_cli(success=False)
        self.assertIn("Refusing non-Nix config symlink", result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(
            external.read_bytes(), b'{"mcpServers": {"private": {"command": "keep"}}}\n'
        )


if __name__ == "__main__":
    unittest.main()
