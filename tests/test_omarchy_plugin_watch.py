import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
WATCH = (
    REPO_ROOT
    / "hosts"
    / "meshify"
    / "omarchy"
    / "local"
    / "bin"
    / "omarchy-plugin-watch"
)


class OmarchyPluginWatchTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        (self.home / "src" / "obsishell").mkdir(parents=True)

        self.write_executable(
            "journalctl",
            """#!/usr/bin/env bash
if [[ " $* " == *" --after-cursor "* ]]; then
  printf '%s\n' '{"__CURSOR":"cursor-3","PRIORITY":"6","MESSAGE":"unrelated healthy event"}'
else
  printf '%s\n' \\
    '{"__CURSOR":"cursor-1","PRIORITY":"6","MESSAGE":"unrelated event"}' \\
    '{"__CURSOR":"cursor-stop","PRIORITY":"6","_SYSTEMD_USER_UNIT":"obsishell.service","MESSAGE":"Stopping Obsidian Headless continuous sync..."}' \\
    '{"__CURSOR":"cursor-2","PRIORITY":"4","_COMM":"omarchy-shell","MESSAGE":"file:///home/test/.config/omarchy/plugins/io.github.edmundmiller.obsishell/Panel.qml: TypeError: broken"}'
fi
""",
        )
        self.write_executable(
            "pi",
            """#!/usr/bin/env bash
printf 'run\n' >>"$WATCH_TEST_DIR/pi-runs"
for argument in "$@"; do
  if [[ $argument == @* ]]; then
    grep -Fq 'TypeError: broken' "${argument#@}"
    grep -Fq 'Stopping Obsidian Headless' "${argument#@}"
  fi
done
printf '# Plugin log report\n\nVerdict: actionable\nAffected: obsishell.service\n'
""",
        )
        self.write_executable(
            "notify-send",
            """#!/usr/bin/env bash
printf '%s\n' "$*" >>"$WATCH_TEST_DIR/notifications"
if [[ " $* " == *" --action=fix="* ]]; then printf 'fix\n'; fi
""",
        )
        self.write_executable(
            "systemd-run",
            """#!/usr/bin/env bash
printf '%s\n' "$*" >>"$WATCH_TEST_DIR/systemd-runs"
""",
        )
        self.write_executable(
            "uwsm-app",
            """#!/usr/bin/env bash
printf '%s\n' "$*" >>"$WATCH_TEST_DIR/agent-launches"
""",
        )

    def write_executable(self, name: str, contents: str) -> None:
        path = self.bin / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_watch(self) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(
            {
                "HOME": str(self.home),
                "PATH": f"{self.bin}:/usr/bin:/bin",
                "WATCH_TEST_DIR": str(self.root),
                "XDG_STATE_HOME": str(self.root / "state"),
            }
        )
        return subprocess.run(
            [WATCH], check=False, capture_output=True, text=True, env=env
        )

    def test_reports_only_new_suspicious_custom_plugin_logs(self) -> None:
        first = self.run_watch()

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual((self.root / "pi-runs").read_text(), "run\n")
        reports = list(
            (self.root / "state" / "omarchy-plugin-watch" / "reports").glob("*.md")
        )
        self.assertEqual(len(reports), 1)
        self.assertIn("Verdict: actionable", reports[0].read_text())
        self.assertIn("notify-report", (self.root / "systemd-runs").read_text())
        self.assertEqual(
            (
                self.root / "state" / "omarchy-plugin-watch" / "journal.cursor"
            ).read_text(),
            "cursor-2\n",
        )

        second = self.run_watch()

        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual((self.root / "pi-runs").read_text(), "run\n")
        self.assertEqual(
            (
                self.root / "state" / "omarchy-plugin-watch" / "journal.cursor"
            ).read_text(),
            "cursor-3\n",
        )
        state_files = {
            path.name
            for path in (self.root / "state" / "omarchy-plugin-watch").iterdir()
        }
        self.assertNotIn("journal.jsonl", state_files)
        self.assertNotIn("findings.jsonl", state_files)
        self.assertNotIn("prompt.txt", state_files)

        notification = subprocess.run(
            [WATCH, "notify-report", reports[0]],
            check=False,
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "HOME": str(self.home),
                "PATH": f"{self.bin}:/usr/bin:/bin",
                "WATCH_TEST_DIR": str(self.root),
            },
        )
        self.assertEqual(notification.returncode, 0, notification.stderr)
        launch = (self.root / "agent-launches").read_text()
        self.assertIn("xdg-terminal-exec", launch)
        self.assertIn(str(reports[0]), launch)


if __name__ == "__main__":
    unittest.main()
