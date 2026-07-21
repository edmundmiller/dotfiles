import json
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/shell/herdr/default.nix"


def bootstrap_program() -> str:
    module = MODULE.read_text()
    start_marker = "<<'PY'\n"
    start = module.index(start_marker, module.index("home.activation.herdr-config-bootstrap"))
    start += len(start_marker)
    end = module.index("\n          PY", start)
    return textwrap.dedent(module[start:end])


class HerdrConfigBootstrapTest(unittest.TestCase):
    def test_duplicate_unmanaged_command_keys_are_deduplicated(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            config = Path(tempdir) / "config.toml"
            config.write_text(
                """
[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "tab-smart-rename.rename-now"
description = "smart rename current tab"

[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "tab-smart-rename.rename-now"
description = "smart rename current tab"

[[keys.command]]
key = "prefix+y"
type = "shell"
command = "user-command"
""".lstrip()
            )

            result = subprocess.run(
                [
                    "python3",
                    "-c",
                    bootstrap_program(),
                    str(config),
                    "ctrl+c",
                    "terminal",
                    json.dumps({"text": "#ffffff"}),
                ],
                capture_output=True,
                text=True,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            updated = config.read_text()
            self.assertEqual(1, updated.count('key = "prefix+t"'))
            self.assertEqual(1, updated.count('command = "tab-smart-rename.rename-now"'))
            self.assertIn('key = "prefix+y"', updated)
            self.assertIn('command = "user-command"', updated)


if __name__ == "__main__":
    unittest.main()
