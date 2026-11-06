"""Exercise Orb lifecycle scripts with an existing single-user Nix install."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class OrbSetupTests(unittest.TestCase):
    def test_single_user_setup_resume_and_login_are_repeatable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            home.mkdir()
            repo = root / "repo"
            (repo / ".agents").mkdir(parents=True)
            for name in ("setup", "resume", "nix-env.sh"):
                shutil.copy2(ROOT / ".agents" / name, repo / ".agents" / name)
            tools = root / "tools"
            tools.mkdir()
            bash = shutil.which("bash")

            def script(path, body):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"#!{bash}\nset -eu\n{body}\n")
                path.chmod(0o755)

            # Keep privileged operations and downloads out of the test.
            script(tools / "sudo", '[ "$1" != systemctl ]')
            script(tools / "systemctl", "exit 1")
            script(tools / "curl", "echo 'Unexpected Nix install' >&2; exit 99")
            script(tools / "gh", "exit 1")
            profile = home / ".nix-profile"
            script(
                profile / "etc/profile.d/nix.sh",
                'export ORB_TEST_PROFILE=loaded\nexport PATH="$HOME/.nix-profile/bin:$PATH"',
            )
            script(
                profile / "bin/nix",
                """test "${ORB_TEST_PROFILE:-}" = loaded
case "$*" in
  'config show eval-cores') exit 1 ;;
  *print-dev-env*) printf 'export ORB_TEST_SHELL=loaded\\n' ;;
  *build*) printf '%s\\n' "$HOME/agent-env" ;;
  --version) echo 'fixture Nix' ;;
  *) exit 98 ;;
esac""",
            )
            for command in ("agent-run", "hey", "jj", "prek"):
                script(home / "agent-env/bin" / command, f"echo {command}")
            env = {
                **os.environ,
                "HOME": str(home),
                "PATH": f"{profile / 'bin'}:{tools}:{os.environ['PATH']}",
                "AMP_ORB": "1",
            }
            env.pop("BASH_ENV", None)
            env.pop("DOTFILES_AGENT_ENV_ACTIVE", None)

            def run(*args):
                result = subprocess.run(
                    args, cwd=repo, env=env, capture_output=True, text=True
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                return result.stdout

            run("git", "init", "--quiet")
            for _ in range(2):
                self.assertIn("Orb setup complete.", run(bash, ".agents/setup"))
                self.assertIn("agent commands are ready.", run(bash, ".agents/resume"))
                self.assertEqual(
                    (home / ".local/bin/nix").resolve(), profile / "bin/nix"
                )
                for command in ("agent-run", "hey", "jj", "prek"):
                    self.assertEqual(run(str(home / ".local/bin" / command)).strip(), command)
                self.assertEqual(
                    run(
                        bash,
                        "-c",
                        'source "$HOME/.bash_profile"; '
                        'test "$ORB_TEST_SHELL" = loaded; nix --version',
                    ).strip(),
                    "fixture Nix",
                )
            self.assertEqual(
                (home / ".bash_profile").read_text().count("# dotfiles orb agent shell"),
                1,
            )


if __name__ == "__main__":
    unittest.main()
