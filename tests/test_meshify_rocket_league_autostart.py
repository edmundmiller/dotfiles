import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
AUTOSTART = (
    REPO_ROOT
    / "hosts"
    / "meshify"
    / "omarchy"
    / "local"
    / "bin"
    / "rocket-league-autostart"
)


class RocketLeagueAutostartTest(unittest.TestCase):
    def test_retries_when_steam_drops_the_first_launch_request(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            bin_dir = root / "bin"
            attempts = root / "attempts"
            bin_dir.mkdir()
            attempts.write_text("0\n")

            self._write_command(
                bin_dir / "pgrep",
                f'[[ $(<"{attempts}") -ge 2 ]]\n',
            )
            self._write_command(
                bin_dir / "uwsm-app",
                f'count=$(<"{attempts}")\nprintf "%s\\n" "$((count + 1))" >"{attempts}"\n',
            )
            self._write_command(bin_dir / "sleep", ":\n")

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["ROCKET_LEAGUE_MAX_ATTEMPTS"] = "3"
            env["ROCKET_LEAGUE_RETRY_SECONDS"] = "0"
            result = subprocess.run(
                [AUTOSTART],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(attempts.read_text(), "2\n")

    def _write_command(self, path: Path, body: str) -> None:
        path.write_text("#!/usr/bin/env bash\n" + body)
        path.chmod(0o755)


if __name__ == "__main__":
    unittest.main()
