"""Exercise local Hermes wiring with temporary manifests and fake runtime CLIs."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeHermesTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey Hermes build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name) / "source"
        shutil.copytree(SOURCE, source)
        posix = source / "posix.c"
        original = '''static Term hey_platform_name(Env e, Term *f, IoWork *w) {
  struct utsname info;
  if (uname(&info)) hey_posix_failure("uname", "");
  return io_str(e, info.sysname, strlen(info.sysname));
}'''
        replacement = '''static Term hey_platform_name(Env e, Term *f, IoWork *w) {
  const char *platform = getenv("TEST_OS");
  const char *name = platform && !strcmp(platform, "macos") ? "Darwin" : "Linux";
  return io_str(e, name, strlen(name));
}'''
        text = posix.read_text()
        if text.count(original) != 1:
            raise RuntimeError("platform boundary changed")
        posix.write_text(text.replace(original, replacement))
        cls.binary = Path(cls.build.name) / "hey-hermes"
        subprocess.run(["bash", str(source / "build"), str(cls.binary), "/unused/mise", "hermes-main.bend"], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey Hermes fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.caller = self.root / "caller"
        self.caller.mkdir()
        self.log = self.root / "commands.jsonl"
        self.manifest_path = self.home / ".config/hermes-local/manifest.json"
        self.manifest_path.parent.mkdir(parents=True)
        self.profiles = ["orchestrator", "scintillate"]
        self.revision = "a" * 40
        self.env = os.environ | {
            "PATH": str(self.tools), "HOME": str(self.home), "TEST_OS": "macos",
            "MISE_PROJECT_ROOT": str(self.root), "HEY_HERMES_ROOT": str(self.root),
            "HEY_HERMES_LOG": str(self.log),
        }
        (self.tools / "jq").symlink_to(shutil.which("jq"))
        common = (
            "import json, os, pathlib, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "args = sys.argv[1:]\n"
            "root = pathlib.Path(os.environ['HEY_HERMES_ROOT'])\n"
            "with open(os.environ['HEY_HERMES_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, args, os.getcwd()]) + '\\n')\n"
        )
        self.hermes = self.executable("hermes", common +
            "assert args == ['profile', 'list']\n"
            "print(os.environ.get('HEY_INVENTORY', 'orchestrator scintillate'))\n")
        self.launchers = {}
        for profile in self.profiles:
            self.launchers[profile] = self.executable(profile + "-hermes", common +
                "profile = name.removesuffix('-hermes')\n"
                "if args == ['config', 'check']:\n"
                "    if os.environ.get('HEY_CONFIG_FAIL') == profile:\n"
                "        print('fixture-only-secret-do-not-log')\n"
                "        raise SystemExit(23)\n"
                "    (pathlib.Path(os.environ['HOME']) / '.hermes/profiles' / profile).mkdir(parents=True, exist_ok=True)\n"
                "elif args[:1] == ['gateway']:\n"
                "    assert profile == 'orchestrator'\n"
                "    if os.environ.get('HEY_GATEWAY_FAIL') == args[1]: raise SystemExit(31)\n"
                "    if args[1] == 'status':\n"
                "        count_file = root / 'status-count'\n"
                "        count = int(count_file.read_text()) if count_file.exists() else 0\n"
                "        count_file.write_text(str(count + 1))\n"
                "        if count < int(os.environ.get('HEY_GATEWAY_PENDING', '0')):\n"
                "            print('starting')\n"
                "        else: print(os.environ.get('HEY_GATEWAY_STATUS', '\"PID\" = 321;'))\n"
                "elif args == ['kanban', 'dispatch', '--dry-run', '--json']:\n"
                "    print('{}')\n"
                "    raise SystemExit(int(os.environ.get('HEY_DISPATCH_EXIT', '0')))\n"
                "else: raise SystemExit(92)\n")
        self.executable("codex", common +
            "assert args == ['login', 'status']\n"
            "sys.stderr.write(os.environ.get('HEY_LOGIN', 'Logged in using ChatGPT'))\n")
        self.executable("mise", common + "raise SystemExit(int(os.environ.get('HEY_MISE_EXIT', '0')))\n")
        self.executable("sleep", common + "assert args == ['1']\n")
        self.manifest = {"agentsWorkspaceRevision": self.revision, "hermes": str(self.hermes),
                         "profiles": self.profiles, "launchers": {name: str(path) for name, path in self.launchers.items()}}
        self.write_manifest()

    def executable(self, name, body):
        path = self.runtime / (name + "-real")
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)
        (self.tools / name).symlink_to(path)
        return path

    def write_manifest(self):
        self.manifest_path.write_text(json.dumps(self.manifest))

    def run_task(self, *args):
        return subprocess.run([self.binary, "hermes:local", *args], cwd=self.caller, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def operations(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_smoke_checks_paths_profiles_login_gateway_and_dispatcher(self):
        result = self.run_task("--smoke-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS hermes-local", result.stdout)
        self.assertFalse(any(name == "mise" for name, args, cwd in self.operations()))
        for profile in self.profiles:
            marker = self.home / ".hermes/profiles" / profile / ".agents-workspace-revision"
            self.assertEqual(marker.read_text(), self.revision)
        self.assertEqual(self.operations()[-1][:2], ["orchestrator-hermes", ["kanban", "dispatch", "--dry-run", "--json"]])

    def test_rebuild_uses_the_selected_checkout_and_stops_on_failure(self):
        self.env["HEY_MISE_EXIT"] = "23"
        result = self.run_task()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.operations(), [["mise", ["--cd", str(self.root), "run", "rebuild"], str(self.caller)]])

    def test_invalid_arguments_or_non_darwin_cannot_start_runtime_tools(self):
        result = self.run_task("--unknown")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.env["TEST_OS"] = "linux"
        linux = self.run_task()
        self.assertNotEqual(linux.returncode, 0)
        self.assertIn("Darwin-only", linux.stderr)
        self.assertEqual(self.operations(), [])

    def test_bad_manifest_cannot_escape_a_profile_directory(self):
        for invalid in ({"profiles": ["../../outside"]}, {"profiles": "orchestrator"}, {"hermes": "relative"}, {"launchers": {}}, {"agentsWorkspaceRevision": ""}):
            with self.subTest(invalid=invalid):
                original = self.manifest.copy()
                self.manifest |= invalid
                self.write_manifest()
                result = self.run_task("--smoke-only")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.operations(), [])
                self.manifest = original
        self.assertFalse((self.home / ".hermes").exists())

    def test_binary_and_launcher_drift_stop_before_profile_mutation(self):
        self.manifest["hermes"] = str(self.runtime / "wrong")
        self.write_manifest()
        result = self.run_task("--smoke-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("binary drift", result.stderr)
        self.assertEqual(self.operations(), [])
        self.manifest["hermes"] = str(self.hermes)
        self.manifest["launchers"]["orchestrator"] = str(self.runtime / "wrong-launcher")
        self.write_manifest()
        launcher = self.run_task("--smoke-only")
        self.assertNotEqual(launcher.returncode, 0)
        self.assertIn("binary drift", launcher.stderr)
        self.assertEqual(self.operations(), [])

    def test_failed_config_check_does_not_write_revision_or_dump_config(self):
        self.env["HEY_CONFIG_FAIL"] = "orchestrator"
        result = self.run_task("--smoke-only")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertNotIn("fixture-only-secret-do-not-log", result.stdout + result.stderr)
        self.assertFalse((self.home / ".hermes/profiles/orchestrator/.agents-workspace-revision").exists())
        self.assertEqual([args for name, args, cwd in self.operations()], [["config", "check"]])

    def test_inventory_and_chatgpt_login_are_required_before_gateway_install(self):
        for overrides in ({"HEY_INVENTORY": "orchestrator"}, {"HEY_LOGIN": "Logged in using an API key"}):
            with self.subTest(overrides=overrides):
                self.log.unlink(missing_ok=True)
                self.env.update(overrides)
                result = self.run_task("--smoke-only")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(args[:1] == ["gateway"] for name, args, cwd in self.operations()))
                for key in overrides:
                    self.env.pop(key)

    def test_gateway_waits_for_a_reported_pid_before_dispatching(self):
        self.env["HEY_GATEWAY_PENDING"] = "2"
        result = self.run_task("--smoke-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "status-count").read_text(), "3")
        self.assertEqual(sum(name == "sleep" for name, args, cwd in self.operations()), 2)

    def test_no_positive_gateway_pid_cannot_report_success_or_dispatch(self):
        self.env["HEY_GATEWAY_STATUS"] = "Gateway running (PID 0)"
        result = self.run_task("--smoke-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "status-count").read_text(), "11")
        self.assertEqual(sum(name == "sleep" for name, args, cwd in self.operations()), 10)
        self.assertFalse(any(args[:1] == ["kanban"] for name, args, cwd in self.operations()))

    def test_gateway_and_dispatcher_failures_propagate(self):
        self.env["HEY_GATEWAY_FAIL"] = "install"
        result = self.run_task("--smoke-only")
        self.assertEqual(result.returncode, 31, result.stderr)
        self.assertFalse(any(args == ["gateway", "start"] for name, args, cwd in self.operations()))
        self.env.pop("HEY_GATEWAY_FAIL")
        self.env["HEY_DISPATCH_EXIT"] = "29"
        result = self.run_task("--smoke-only")
        self.assertEqual(result.returncode, 29, result.stderr)


if __name__ == "__main__":
    unittest.main()
