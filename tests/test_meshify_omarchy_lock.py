import json
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
OMARCHY = REPO_ROOT / "hosts" / "meshify" / "omarchy"
LOCK_PLUGIN = OMARCHY / "config" / "omarchy" / "plugins" / "edmundmiller.lock"


class LockPolicyTest(unittest.TestCase):
    def test_unlock_prompt_stays_awake_for_thirty_seconds(self) -> None:
        service = (LOCK_PLUGIN / "Service.qml").read_text()
        timer = re.search(
            r"Timer\s*\{\s*id:\s*idleBlankTimer(?P<body>.*?)\n\s*\}",
            service,
            re.DOTALL,
        )

        self.assertIsNotNone(timer)
        self.assertRegex(timer.group("body"), r"interval:\s*30000\b")

    def test_local_lock_clone_replaces_the_builtin_service(self) -> None:
        plugin_manifest = json.loads((LOCK_PLUGIN / "manifest.json").read_text())
        shell_config = json.loads(
            (OMARCHY / "config" / "omarchy" / "shell.json").read_text()
        )
        recovery_manifest = json.loads((OMARCHY / "manifest.json").read_text())
        file_targets = {entry["target"] for entry in recovery_manifest["files"]}

        self.assertEqual(plugin_manifest["id"], "edmundmiller.lock")
        self.assertEqual(plugin_manifest["omarchy"]["clonedFrom"], "omarchy.lock")
        self.assertIn({"id": "edmundmiller.lock"}, shell_config["plugins"])
        self.assertIn("omarchy.lock", shell_config["disabledPlugins"])
        self.assertTrue(
            {
                ".config/omarchy/plugins/edmundmiller.lock/LockView.qml",
                ".config/omarchy/plugins/edmundmiller.lock/Service.qml",
                ".config/omarchy/plugins/edmundmiller.lock/manifest.json",
            }.issubset(file_targets)
        )


if __name__ == "__main__":
    unittest.main()
