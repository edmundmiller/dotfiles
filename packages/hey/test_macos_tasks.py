"""Exercise Xcode preview/apply through fake system tools and real temporary apps."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeXcodeTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey Xcode build ")
        cls.addClassCleanup(cls.build.cleanup)
        base = Path(cls.build.name).resolve()
        cls.host = base / "system-tools"
        source = base / "source"
        shutil.copytree(SOURCE, source)
        cls.env_program = shutil.which("env")
        cls.move_program = shutil.which("mv")
        replacements = {f"/usr/bin/{name}": str(cls.host / name) for name in ("xcode-select", "xcodebuild", "xcrun", "osascript")}
        replacements |= {"/usr/bin/env": cls.env_program, "/bin/mv": cls.move_program}
        for path in source.glob("*.bend"):
            text = path.read_text()
            for original, target in replacements.items():
                original_literal, target_literal = json.dumps(original), json.dumps(target)
                text = text.replace("[" + original_literal + ",", "[" + target_literal + ",")
                text = text.replace(", " + original_literal + ",", ", " + target_literal + ",")
            path.write_text(text)
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
        cls.binary = base / "hey-xcode"
        subprocess.run(["bash", str(source / "build"), str(cls.binary), "/unused/mise", "macos-main.bend"], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey Xcode fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.application = self.root / "Downloaded Xcode ' Special.app"
        self.developer = self.application / "Contents/Developer"
        marker = self.developer / "usr/bin/xcodebuild"
        marker.parent.mkdir(parents=True)
        marker.write_text("expected app")
        self.destination = self.root / "Shared Xcode.app"
        self.previous = str(self.root / "Previous Xcode.app/Contents/Developer")
        self.selected = self.root / "selected"
        self.selected.write_text(self.previous)
        self.log = self.root / "commands.jsonl"
        shutil.rmtree(self.host, ignore_errors=True)
        self.host.mkdir()
        self.env = os.environ | {
            "PATH": str(self.host), "HOME": str(self.root), "TEST_OS": "macos",
            "DEVELOPER_DIR": "ambient-must-not-leak", "HEY_XCODE_ROOT": str(self.root),
            "HEY_XCODE_LOG": str(self.log), "HEY_SELECTED": str(self.selected),
            "HEY_APP_DEVELOPER": str(self.developer), "HEY_ENV_PROGRAM": self.env_program,
            "HEY_MOVE_PROGRAM": self.move_program,
        }
        common = (
            "import json, os, pathlib, shutil, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "args = sys.argv[1:]\n"
            "root = pathlib.Path(os.environ['HEY_XCODE_ROOT'])\n"
            "selected = pathlib.Path(os.environ['HEY_SELECTED'])\n"
            "developer = os.environ.get('DEVELOPER_DIR')\n"
            "with open(os.environ['HEY_XCODE_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, args, developer]) + '\\n')\n"
        )
        self.executable("xcode-select", common +
            "if args == ['-p']:\n"
            "    assert developer is None\n"
            "    print(selected.read_text())\n"
            "elif len(args) == 2 and args[0] == '--switch':\n"
            "    assert pathlib.Path(args[1]).is_relative_to(root)\n"
            "    selected.write_text(args[1])\n"
            "else: raise SystemExit(92)\n")
        self.executable("xcodebuild", common +
            "assert developer == os.environ['HEY_APP_DEVELOPER']\n"
            "if args == ['-version']:\n"
            "    if os.environ.get('HEY_VERSION_FAIL') == '1': raise SystemExit(17)\n"
            "    print('Xcode fixture version')\n"
            "elif args == ['-checkFirstLaunchStatus']:\n"
            "    if os.environ.get('HEY_NEEDS_FIRST') == '1' and not (root / 'initialized').exists(): raise SystemExit(1)\n"
            "elif args == ['-license', 'check']:\n"
            "    if os.environ.get('HEY_LICENSE_OK', '1') != '1': raise SystemExit(1)\n"
            "elif args == ['-runFirstLaunch']: (root / 'initialized').write_text('ready')\n"
            "elif args == ['-downloadComponent', 'MetalToolchain']:\n"
            "    if os.environ.get('HEY_DOWNLOAD_FAIL') == '1': raise SystemExit(19)\n"
            "    (root / 'metal-ready').write_text('ready')\n"
            "else: raise SystemExit(92)\n")
        self.executable("xcrun", common +
            "assert args == ['--no-cache', 'metal', '--version']\n"
            "if developer is None:\n"
            "    assert pathlib.Path(selected.read_text(), 'usr/bin/xcodebuild').exists()\n"
            "    if os.environ.get('HEY_FINAL_METAL_FAIL') == '1': raise SystemExit(5)\n"
            "else: assert developer == os.environ['HEY_APP_DEVELOPER']\n"
            "if os.environ.get('HEY_NEEDS_METAL') == '1' and not (root / 'metal-ready').exists(): raise SystemExit(1)\n"
            "print('Metal fixture version')\n")
        self.executable("sudo", common +
            "assert args[0] == '-n'\n"
            "command = args[1:]\n"
            "if command[0] == os.environ['HEY_MOVE_PROGRAM']:\n"
            "    assert command[1:3] == ['-n', '-T']\n"
            "    source, target = map(pathlib.Path, command[-2:])\n"
            "    assert source.is_relative_to(root) and target.is_relative_to(root)\n"
            "    if os.environ.get('HEY_RACE_DEST') == '1':\n"
            "        target.mkdir()\n"
            "        (target / 'untouched').write_text('existing destination')\n"
            "elif command[0] != os.environ['HEY_ENV_PROGRAM'] and pathlib.Path(command[0]).name != 'xcode-select': raise SystemExit(93)\n"
            "os.execv(command[0], command)\n")
        self.executable("osascript", common +
            "assert args[0] == '-e' and 'administrator privileges' in args[1]\n"
            "assert 'quoted form' in args[1]\n"
            "if '-runFirstLaunch' in args[1]: (root / 'initialized').write_text('ready')\n"
            "elif ' -n -T ' in args[1]:\n"
            "    source, target = map(pathlib.Path, args[2:4])\n"
            "    assert source.is_relative_to(root) and target.is_relative_to(root) and not target.exists()\n"
            "    shutil.move(source, target)\n"
            "elif 'xcode-select --switch' in args[1]: selected.write_text(args[2])\n"
            "else: raise SystemExit(92)\n")

    def executable(self, name, body):
        path = self.host / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def run_task(self, *args):
        return subprocess.run([self.binary, "xcode:setup", *args], cwd=self.root, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def operations(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_preview_only_observes_the_requested_app_and_current_selection(self):
        result = self.run_task(str(self.application))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Dry run", result.stdout)
        self.assertEqual([(name, args) for name, args, developer in self.operations()], [("xcode-select", ["-p"]), ("xcodebuild", ["-version"])])
        self.assertEqual(self.selected.read_text(), self.previous)
        self.assertEqual(self.env["DEVELOPER_DIR"], "ambient-must-not-leak")

    def test_bad_arguments_and_non_macos_platform_cannot_mutate(self):
        for args in ((), ("--unknown", str(self.application)), (str(self.application), "extra"), (str(self.application), "--install-to")):
            with self.subTest(args=args):
                result = self.run_task(*args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(self.operations(), [])
        self.env["TEST_OS"] = "linux"
        result = self.run_task(str(self.application), "--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("only supported on macOS", result.stderr)
        self.assertEqual(self.operations(), [])

    def test_missing_app_and_existing_destination_stop_before_any_system_tool(self):
        missing = self.run_task(str(self.root / "Missing.app"), "--apply")
        self.assertNotEqual(missing.returncode, 0)
        self.destination.mkdir()
        (self.destination / "keep").write_text("existing")
        exists = self.run_task(str(self.application), "--apply", "--install-to", str(self.destination))
        self.assertNotEqual(exists.returncode, 0)
        self.assertEqual(self.operations(), [])
        self.assertEqual((self.destination / "keep").read_text(), "existing")

    def test_inline_destination_and_flags_before_app_remain_preview_only(self):
        result = self.run_task("--prompt-admin", "--install-to=" + str(self.destination), str(self.application))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.destination), result.stdout)
        self.assertFalse(self.destination.exists())
        self.assertFalse(any(name in ("sudo", "osascript") for name, args, developer in self.operations()))

    def test_apply_selects_and_verifies_without_leaking_developer_override(self):
        result = self.run_task(str(self.application), "--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.selected.read_text(), str(self.developer))
        calls = self.operations()
        self.assertTrue(any(name == "sudo" for name, args, developer in calls))
        self.assertFalse(any(args[:1] == ["-downloadComponent"] for name, args, developer in calls))
        self.assertEqual(calls[-1], ["xcrun", ["--no-cache", "metal", "--version"], None])
        self.assertIn(self.previous, result.stdout)
        self.assertEqual(self.env["DEVELOPER_DIR"], "ambient-must-not-leak")

    def test_unaccepted_license_cannot_run_first_launch_or_select(self):
        self.env |= {"HEY_NEEDS_FIRST": "1", "HEY_LICENSE_OK": "0"}
        result = self.run_task(str(self.application), "--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Review and accept", result.stderr)
        self.assertFalse(any(name in ("sudo", "osascript") for name, args, developer in self.operations()))
        self.assertEqual(self.selected.read_text(), self.previous)

    def test_first_launch_and_metal_download_use_the_selected_admin_mode(self):
        self.env |= {"HEY_NEEDS_FIRST": "1", "HEY_NEEDS_METAL": "1"}
        result = self.run_task(str(self.application), "--apply", "--prompt-admin")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "initialized").exists())
        self.assertTrue((self.root / "metal-ready").exists())
        calls = self.operations()
        scripts = [args for name, args, developer in calls if name == "osascript"]
        self.assertEqual(len(scripts), 2)
        self.assertEqual(scripts[0][2:], [str(self.developer)])
        self.assertNotIn(str(self.developer), scripts[0][1])
        self.assertFalse(any(name == "sudo" for name, args, developer in calls))

    def test_failed_download_leaves_source_and_system_selection_unchanged(self):
        self.env |= {"HEY_NEEDS_METAL": "1", "HEY_DOWNLOAD_FAIL": "1"}
        result = self.run_task(str(self.application), "--apply", "--install-to", str(self.destination))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.application.exists())
        self.assertFalse(self.destination.exists())
        self.assertEqual(self.selected.read_text(), self.previous)

    def test_move_and_selection_use_the_destination_and_preserve_app_contents(self):
        result = self.run_task(str(self.application), "--apply", "--install-to", str(self.destination))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.application.exists())
        self.assertEqual((self.destination / "Contents/Developer/usr/bin/xcodebuild").read_text(), "expected app")
        self.assertEqual(self.selected.read_text(), str(self.destination / "Contents/Developer"))
        self.assertEqual(self.operations()[-1][2], None)

    def test_destination_race_cannot_replace_an_app_or_select_a_skipped_move(self):
        self.env["HEY_RACE_DEST"] = "1"
        result = self.run_task(str(self.application), "--apply", "--install-to", str(self.destination))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.application.exists())
        self.assertEqual((self.destination / "untouched").read_text(), "existing destination")
        self.assertEqual(self.selected.read_text(), self.previous)


if __name__ == "__main__":
    unittest.main()
