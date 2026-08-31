import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules" / "agents" / "hermes-local" / "default.nix"
HEY_HERMES = ROOT / "bin" / "hey.d" / "hermes.nu"


class HermesLocalWiringTests(unittest.TestCase):
    def test_profile_launchers_run_with_darwin_bash(self) -> None:
        module = MODULE.read_text()

        self.assertIn("upstreamLauncher = name:", module)
        self.assertIn(
            'exec /bin/bash ${upstreamLauncher name}/bin/${name}-hermes "$@"',
            module,
        )

    def test_gateway_pid_parser_accepts_current_and_legacy_status(self) -> None:
        source = HEY_HERMES.read_text()
        pattern_match = re.search(
            r"export const GATEWAY_PID_PATTERN = '([^']+)'",
            source,
        )
        self.assertIsNotNone(pattern_match)
        pattern = re.compile(pattern_match.group(1))

        for output, expected in (
            ('"PID" = 12345;', "12345"),
            ("Gateway is supervised by launchd (PID 38696)", "38696"),
        ):
            with self.subTest(output=output):
                match = pattern.search(output)
                self.assertIsNotNone(match)
                self.assertEqual(match.group("pid"), expected)


if __name__ == "__main__":
    unittest.main()
