import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AgentResponseContractTests(unittest.TestCase):
    def test_codex_bootstrap_instructions_stay_bounded(self) -> None:
        config = tomllib.loads((ROOT / "config/codex/config.toml").read_text())
        instructions = config["developer_instructions"]

        self.assertLessEqual(len(instructions.split()), 150)

    def test_host_provided_packages_are_never_declared_as_pi_packages(self) -> None:
        """Pi bundles these inside its binary and injects them through the
        extension loader. A declared copy lands in ~/.pi/agent/npm and can
        shadow the host module, which Pi warns creates duplicate runtime
        modules. See HOST_PROVIDED_EXTENSION_PACKAGES in the Pi binary."""
        host_provided = (
            "@earendil-works/pi-agent-core",
            "@earendil-works/pi-ai",
            "@earendil-works/pi-coding-agent",
            "@earendil-works/pi-tui",
            "@mariozechner/pi-agent-core",
            "@mariozechner/pi-ai",
            "@mariozechner/pi-coding-agent",
            "@mariozechner/pi-tui",
            "@sinclair/typebox",
            "typebox",
        )
        declarations = (
            (ROOT / "config/pi/settings.jsonc").read_text()
            + (ROOT / "modules/agents/pi/lib/_settings.nix").read_text()
        )

        for package in host_provided:
            with self.subTest(package=package):
                self.assertNotIn(f"npm:{package}", declarations)


if __name__ == "__main__":
    unittest.main()
