import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AgentTracesConfigTests(unittest.TestCase):
    def test_launchd_is_only_exposed_on_darwin(self) -> None:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--json",
                "--impure",
                "--expr",
                f"builtins.getFlake {json.dumps(str(ROOT))}",
                "--no-write-lock-file",
                "--apply",
                """
                flake: {
                  linuxHasLaunchd = flake.nixosConfigurations.nuc.config ? launchd;
                  darwinCommand = flake.darwinConfigurations.MacTraitor-Pro.config
                    .launchd.user.agents.agent-traces.command;
                }
                """,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads(result.stdout)
        self.assertFalse(config["linuxHasLaunchd"])
        self.assertTrue(config["darwinCommand"].endswith("/bin/python -m agent_traces.ingest"))


if __name__ == "__main__":
    unittest.main()
