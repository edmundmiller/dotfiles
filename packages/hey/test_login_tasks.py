"""Drive login routing with fake SSH, sudo and container boundaries."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeLoginTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey login build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name) / "source"
        shutil.copytree(SOURCE, source)
        for path in source.glob("*.bend"):
            text = path.read_text()
            for original in ("/run/wrappers/bin", "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin"):
                text = text.replace(original, str(source / "no-system-tools"))
            path.write_text(text)
        posix = source / "posix.c"
        original = '''static Term hey_host_name(Env e, Term *f, IoWork *w) {
  char name[256];
  if (gethostname(name, sizeof(name))) hey_posix_failure("gethostname", "");
  name[sizeof(name) - 1] = 0;
  char *dot = strchr(name, '.');
  if (dot) *dot = 0;
  return hey_posix_text(e, name, strlen(name), "host name");
}'''
        replacement = '''static Term hey_host_name(Env e, Term *f, IoWork *w) {
  const char *name = getenv("HEY_TEST_HOST");
  return io_str(e, name ? name : "desktop", name ? strlen(name) : 7);
}'''
        text = posix.read_text()
        if text.count(original) != 1:
            raise RuntimeError("hostname boundary changed")
        posix.write_text(text.replace(original, replacement))
        cls.binary = Path(cls.build.name) / "hey-login"
        subprocess.run(["bash", str(source / "build"), str(cls.binary), "/unused/mise", "login-main.bend"], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey login fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.log = self.root / "commands.jsonl"
        self.env = os.environ | {
            "PATH": str(self.tools), "HOME": str(self.root), "HEY_TEST_HOST": "nuc",
            "HEY_LOGIN_LOG": str(self.log), "HEY_REAL_BASH": shutil.which("bash"),
        }
        for name in ("bash", "sort"):
            (self.tools / name).symlink_to(shutil.which(name))
        common = (
            "import json, os, pathlib, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "args = sys.argv[1:]\n"
            "with open(os.environ['HEY_LOGIN_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, args]) + '\\n')\n"
        )
        self.executable("docker", common +
            "assert args[0] == 'exec'\n"
            "if os.environ.get('HEY_AUTH_FAIL') == '1' and 'auth add' in ' '.join(args): raise SystemExit(23)\n")
        self.executable("sudo", common +
            "assert args[0] in ('docker', 'find')\n"
            "os.execvp(args[0], args)\n")
        self.executable("find", common +
            "assert args[:3] == ['/var/lib/hermes-betty', '-maxdepth', '3']\n"
            "print('z metadata')\nprint('a metadata')\n")
        self.executable("ssh", common +
            "if args[0] == '-t': args = args[1:]\n"
            "assert len(args) == 2 and args[0] == 'nuc'\n"
            "os.execv(os.environ['HEY_REAL_BASH'], ['bash', '-c', args[1]])\n")
        auth = self.root / ".codex/auth.json"
        auth.parent.mkdir()
        auth.write_text("fixture-parent-credentials-not-for-containers")

    def executable(self, name, body):
        path = self.tools / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def run_task(self, task, *args):
        return subprocess.run([self.binary, task, *args], cwd=self.root, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def operations(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_scintillate_local_login_keeps_container_and_auth_provider_explicit(self):
        result = self.run_task("login:scintillate")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.operations()
        self.assertEqual(calls[0], ["docker", ["exec", "-it", "hermes-agent-scintillate", "hermes", "auth", "add", "openai-codex", "--no-browser"]])
        self.assertEqual([name for name, args in calls], ["docker", "docker"])
        self.assertEqual(calls[1][1][:3], ["exec", "hermes-agent-scintillate", "bash"])
        self.assertIn("--provider openai-codex", calls[1][1][-1])
        self.assertNotIn("fixture-parent-credentials-not-for-containers", result.stdout + result.stderr)
        self.assertEqual((self.root / ".codex/auth.json").read_text(), "fixture-parent-credentials-not-for-containers")

    def test_betty_local_login_uses_privileged_tools_and_checks_independent_auth(self):
        result = self.run_task("login:betty")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.operations()
        docker = [args for name, args in calls if name == "docker"]
        self.assertEqual(len(docker), 3)
        self.assertEqual(docker[0][:4], ["exec", "-it", "hermes-agent-betty", "bash"])
        self.assertEqual(docker[0][-1], "hermes auth add openai-codex --type oauth")
        self.assertEqual(docker[1][1], "hermes-agent-betty")
        self.assertEqual(docker[2][1], "hermes-agent-scintillate")
        self.assertEqual(sum(name == "sudo" for name, args in calls), 4)
        self.assertIn("a metadata\nz metadata", result.stdout)
        self.assertFalse(any(name == "ssh" for name, args in calls))

    def test_remote_login_uses_a_tty_only_for_the_interactive_step(self):
        self.env["HEY_TEST_HOST"] = "desktop"
        result = self.run_task("login:scintillate")
        self.assertEqual(result.returncode, 0, result.stderr)
        ssh = [args for name, args in self.operations() if name == "ssh"]
        self.assertEqual(ssh[0][:2], ["-t", "nuc"])
        self.assertEqual(len(ssh[0]), 3)
        self.assertEqual(ssh[1][0], "nuc")
        self.assertEqual(len(ssh[1]), 2)
        self.assertEqual(sum(name == "docker" for name, args in self.operations()), 2)

    def test_remote_betty_preserves_sudo_search_path_and_literal_command_arguments(self):
        self.env["HEY_TEST_HOST"] = "desktop"
        result = self.run_task("login:betty")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(name == "sudo" for name, args in self.operations()), 4)
        docker = [args for name, args in self.operations() if name == "docker"]
        self.assertIn('Reply with exactly: OK', docker[1][-1])
        self.assertEqual(docker[1][-1].count('"'), 2)
        self.assertIn("a metadata\nz metadata", result.stdout)

    def test_auth_failure_stops_before_verification_and_other_profile_access(self):
        self.env["HEY_AUTH_FAIL"] = "1"
        result = self.run_task("login:betty")
        self.assertEqual(result.returncode, 23, result.stderr)
        calls = self.operations()
        self.assertEqual([name for name, args in calls], ["sudo", "docker"])
        self.assertEqual(calls[-1][1][2], "hermes-agent-betty")

    def test_unknown_arguments_cannot_start_a_login(self):
        result = self.run_task("login:betty", "--unknown")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(self.operations(), [])


if __name__ == "__main__":
    unittest.main()
