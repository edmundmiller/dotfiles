"""Exercise Orb lifecycle scripts with an existing single-user Nix install."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class OrbSetupTests(unittest.TestCase):
    @unittest.skipIf(
        Path("/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh").exists(),
        "system Nix profile takes precedence over store discovery",
    )
    def test_recovers_nix_from_store_when_profile_is_broken(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            home.mkdir()
            (home / ".nix-profile").symlink_to(root / "missing-profile")
            store = root / "store"
            tools = root / "tools"
            tools.mkdir()
            for tool in ("readlink", "sort", "tail", "cut"):
                (tools / tool).symlink_to(shutil.which(tool))
            bash = shutil.which("bash")
            nix = store / "example-nix-2.35.3/bin/nix"
            nix.parent.mkdir(parents=True)
            nix.write_text(f'#!{bash}\necho "fixture Nix"\n')
            nix.chmod(0o755)
            env = {
                "HOME": str(home),
                "PATH": str(tools),
                "NIX_STORE_DIR": str(store),
            }
            command = (
                'source "$1" && test "$(command -v nix)" = "$nix_bin" '
                '&& nix --version'
            )
            result = subprocess.run(
                [bash, "-c", command, "bash", str(ROOT / ".agents/nix-env.sh")],
                env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "fixture Nix")

            other = store / "another-nix-2.36/bin/nix"
            other.parent.mkdir(parents=True)
            other.write_text(f'#!{bash}\necho "newer fixture Nix"\n')
            other.chmod(0o755)
            result = subprocess.run(
                [bash, "-c", command, "bash", str(ROOT / ".agents/nix-env.sh")],
                env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "newer fixture Nix")

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
            (home / "agent-env/bin/mise").symlink_to(shutil.which("mise"))
            config = "[env]\nORB_TRUST_PROBE = \"{{ 'trusted' }}\"\n"
            (repo / "mise.toml").write_text(config)
            unrelated = root / "unrelated"
            unrelated.mkdir()
            (unrelated / "mise.toml").write_text(config)
            env = {
                **os.environ,
                "HOME": str(home),
                "PATH": f"{home / '.local/bin'}:{profile / 'bin'}:{tools}:{os.environ['PATH']}",
                "AMP_ORB": "1",
                "MISE_DATA_DIR": str(root / "mise-data"),
                "MISE_STATE_DIR": str(root / "mise-state"),
                "MISE_CONFIG_DIR": str(root / "mise-config"),
                "MISE_CACHE_DIR": str(root / "mise-cache"),
                "MISE_PARANOID": "1",
            }
            env.pop("BASH_ENV", None)
            env.pop("DOTFILES_AGENT_ENV_ACTIVE", None)
            env.pop("MISE_TRUSTED_CONFIG_PATHS", None)

            def assert_untrusted(cwd):
                result = subprocess.run(
                    [shutil.which("mise"), "env", "--json"],
                    cwd=cwd,
                    env=env,
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("not trusted", result.stderr)

            def run(*args):
                result = subprocess.run(
                    args, cwd=repo, env=env, capture_output=True, text=True
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                return result.stdout

            run("git", "init", "--quiet")
            assert_untrusted(repo)
            assert_untrusted(unrelated)
            for _ in range(2):
                self.assertIn("Orb setup complete.", run(bash, ".agents/setup"))
                self.assertIn("agent commands are ready.", run(bash, ".agents/resume"))
                self.assertEqual(
                    json.loads(run(str(home / ".local/bin/mise"), "env", "--json"))[
                        "ORB_TRUST_PROBE"
                    ],
                    "trusted",
                )
                assert_untrusted(unrelated)
                self.assertEqual(
                    (home / ".local/bin/nix").resolve(), profile / "bin/nix"
                )
                for command in ("agent-run", "hey", "jj", "prek"):
                    self.assertEqual(
                        run(str(home / ".local/bin" / command)).strip(), command
                    )
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
                (home / ".bash_profile")
                .read_text()
                .count("# dotfiles orb agent shell"),
                1,
            )

            if not Path("/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh").exists():
                store_nix = root / "store/example-nix-2.35.3/bin/nix"
                store_nix.parent.mkdir(parents=True)
                shutil.copy2(profile / "bin/nix", store_nix)
                shutil.rmtree(profile)
                profile.symlink_to(root / "missing-profile")
                (home / ".local/bin/nix").unlink()
                for tool in ("git", "readlink", "sort", "tail", "cut", "mkdir", "ln"):
                    (tools / tool).symlink_to(shutil.which(tool))
                env.update(
                    PATH=str(tools),
                    NIX_STORE_DIR=str(root / "store"),
                    ORB_TEST_PROFILE="loaded",
                )
                for _ in range(2):
                    self.assertIn("agent commands are ready.", run(bash, ".agents/resume"))
                    self.assertEqual((home / ".local/bin/nix").resolve(), store_nix)


if __name__ == "__main__":
    unittest.main()
