"""Run native rebuild guards on disposable checkout and credential boundaries."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeSystemGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey guard build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name)
        for path in SOURCE.iterdir():
            if path.suffix in (".bend", ".c", ".h"):
                shutil.copy2(path, source)
        (source / "guard-driver.bend").write_text(
            'import Base\n'
            'import ./system-guards.bend as Guards\n'
            'import ./resources.bend as Resources\n'
            'import ./os.bend as OS\n'
            'def run_guard(mode: String, root: String) -> IO(Unit):\n'
            '  match mode:\n'
            '    case "lock":\n'
            '      Guards.check_flake_lock(root)\n'
            '    case "skills":\n'
            '      Guards.check_local_skill_leaks(root)\n'
            '    case "evaluators":\n'
            '      do IO<Unit>:\n'
            '        result : OS.ProcessResult <- OS.run(["ps", "-axo", "pid=,command="], True{})\n'
            '        IO.print(String.join(Guards.evaluator_lines(result, 0), "\\n"))\n'
            '    case "auth":\n'
            '      do IO<Unit>:\n'
            '        config : String <- Guards.authenticated_nix_config()\n'
            '        result : OS.ProcessResult <- OS.run_with_environment(["nix", "probe"], False{}, "NIX_CONFIG", config)\n'
            '        OS.check(result)\n'
            '        OS.checked(["observer"])\n'
            '    case mode:\n'
            '      IO.exit(2)\n'
            'def dispatch(args: List<String>) -> IO(Unit):\n'
            '  match args:\n'
            '    case program <> mode <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        root : String <- OS.required_environment("MISE_PROJECT_ROOT")\n'
            '        run_guard(mode, root)\n'
            '    case args:\n'
            '      IO.exit(2)\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    args : List<String> <- IO.args()\n'
            '    dispatch(args)\n'
            '    Resources.finish_task(0)\n'
        )
        subprocess.run(["bend", str(source / "guard-driver.bend"), "-o", str(source / "generated.c")], check=True)
        cls.binary = source / "guard-driver"
        subprocess.run(
            ["clang", "-O2", "-pthread", str(source / "launcher.c"), "-o", str(cls.binary), "-lm"], check=True
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey guard fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.env = os.environ | {
            "HOME": str(self.home), "MISE_PROJECT_ROOT": str(self.root),
            "PATH": f"{self.tools}{os.pathsep}{os.environ['PATH']}",
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
            "NIX_CONFIG": "experimental-features = nix-command flakes",
        }
        for name in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"):
            self.env.pop(name, None)
        subprocess.run(["git", "init", "--quiet", str(self.root)], env=self.env, check=True)
        (self.root / "flake.lock").write_text("{}\n")
        (self.root / "flake.nix").write_text("{}\n")
        subprocess.run(["git", "-C", str(self.root), "add", "flake.lock", "flake.nix"], env=self.env, check=True)

    def run_guard(self, mode):
        return subprocess.run(
            [self.binary, mode], cwd=self.root, env=self.env,
            capture_output=True, text=True, timeout=10,
        )

    def executable(self, name, body):
        path = self.tools / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def test_valid_lock_and_clean_checkout_pass(self):
        result = self.run_guard("lock")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_json_and_conflict_markers_fail_with_actionable_errors(self):
        for text, expected in (
            ("not json\n", "flake.lock is not valid JSON"),
            ("<<<<<<< conflict\n", "flake.lock contains git conflict markers"),
        ):
            with self.subTest(text=text):
                (self.root / "flake.lock").write_text(text)
                result = self.run_guard("lock")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, result.stderr)

    def test_tracked_configuration_conflicts_are_not_ignored(self):
        (self.root / "flake.nix").write_text("<<<<<<< conflict\n")
        result = self.run_guard("lock")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tracked config files contain conflict markers", result.stderr)

    def test_git_inspection_failure_is_not_treated_as_no_matches(self):
        shutil.rmtree(self.root / ".git")
        result = self.run_guard("lock")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not a git repository", result.stderr.lower())

    def test_project_local_skill_leaks_are_rejected_without_deleting_them(self):
        local = self.root / ".agents/skills/private-task"
        global_skill = self.home / ".agents/skills/private-task"
        for path in (local, global_skill):
            path.mkdir(parents=True)
            (path / "SKILL.md").write_text("fixture skill")
        result = self.run_guard("skills")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private-task", result.stderr)
        self.assertIn("skills-cleanup-local-leaks", result.stderr)
        self.assertEqual((global_skill / "SKILL.md").read_text(), "fixture skill")
        shutil.rmtree(global_skill)
        result = self.run_guard("skills")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_large_process_inventory_is_filtered_without_exhausting_the_evaluation_stack(self):
        self.executable(
            "ps", "for pid in range(1, 12001):\n"
            "    print(f'{pid} ordinary-worker ' + 'x' * 60)\n"
            "print('876543 nix build .#darwinConfigurations.Test.system')\n"
            "print(\"876544 bash -c 'nix build .#nixosConfigurations.Test.system'\")\n"
            "print('876545 rg nixosConfigurations')\n"
        )
        result = self.run_guard("evaluators")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["876543 nix build .#darwinConfigurations.Test.system"])

    def test_authentication_is_scoped_to_nix_and_never_placed_in_arguments(self):
        self.executable(
            "gh", "import os, sys\n"
            "assert sys.argv[1:] == ['auth', 'token']\n"
            "assert 'fixture-only-token' not in os.environ['NIX_CONFIG']\n"
            "print('fixture-only-token')\n"
            "raise SystemExit(int(os.environ.get('HEY_AUTH_EXIT', '0')))\n"
        )
        self.executable(
            "nix", "import os, sys\n"
            "assert sys.argv[1:] == ['probe']\n"
            "expected = 'experimental-features = nix-command flakes'\n"
            "if os.environ.get('HEY_AUTH_EXIT', '0') == '0': expected += '\\naccess-tokens = github.com=fixture-only-token'\n"
            "raise SystemExit(0 if os.environ['NIX_CONFIG'] == expected else 91)\n"
        )
        self.executable(
            "observer", "import os\n"
            "raise SystemExit(0 if os.environ['NIX_CONFIG'] == 'experimental-features = nix-command flakes' else 92)\n"
        )
        for status in ("0", "23"):
            with self.subTest(auth_status=status):
                self.env["HEY_AUTH_EXIT"] = status
                result = self.run_guard("auth")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("fixture-only-token", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
