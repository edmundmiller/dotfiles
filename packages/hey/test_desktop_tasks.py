"""Check desktop task behavior with temporary files and fake privileged tools."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeDesktopTaskTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey desktop build ")
        cls.addClassCleanup(cls.build.cleanup)
        base = Path(cls.build.name).resolve()
        cls.host = base / "host"
        source = base / "source"
        shutil.copytree(SOURCE, source)
        for path in source.glob("*.bend"):
            path.write_text(path.read_text().replace("/etc/nix/nix.conf", str(cls.host / "nix.conf")).replace("/Applications/Keymapp.app", str(cls.host / "Keymapp.app")))
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
        cls.binary = base / "hey-task"
        subprocess.run(["bash", str(source / "build"), str(cls.binary), "/unused/mise", "desktop-main.bend"], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey desktop fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve() / "project with spaces"
        self.root.mkdir()
        self.caller = self.root / "caller"
        self.caller.mkdir()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        (self.root / "tmp").mkdir()
        (self.root / "bin").mkdir()
        (self.root / "config/ergodox").mkdir(parents=True)
        (self.root / "packages/ergodox-firmware/src").mkdir(parents=True)
        shutil.rmtree(self.host, ignore_errors=True)
        self.host.mkdir()
        self.cache = self.host / "nix.conf"
        self.log = self.root / "operations.jsonl"
        self.env = os.environ | {
            "PATH": str(self.tools), "HOME": str(self.home), "TMPDIR": str(self.root / "tmp"),
            "MISE_PROJECT_ROOT": str(self.root), "FLAKE_HOST": "fixture-host", "TEST_OS": "macos",
            "HEY_DESKTOP_LOG": str(self.log), "HEY_DESKTOP_ROOT": str(self.root),
            "HEY_HOST_BOUNDARY": str(self.host), "NIX_CONFIG": "fixture-config", "DOTFILES": "/stale",
        }
        for name in ("bash", "cp", "find", "mkdir", "touch", "tee", "ls", "grep", "chmod", "rm", "dirname"):
            tool = shutil.which(name)
            if not tool:
                raise RuntimeError(f"test tool missing: {name}")
            (self.tools / name).symlink_to(tool)
        self.recorder = (
            "import json, os, pathlib, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "root = pathlib.Path(os.environ['HEY_DESKTOP_ROOT'])\n"
            "with open(os.environ['HEY_DESKTOP_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, sys.argv[1:], os.getcwd(), os.environ.get('DOTFILES')]) + '\\n')\n"
            "if os.environ.get('HEY_FAIL_ARG') in sys.argv[1:]: raise SystemExit(23)\n"
        )
        self.executable("nix", self.recorder +
            "if sys.argv[1:2] == ['repl']: (root / 'repl-expression').write_text(pathlib.Path(sys.argv[-1]).read_text())\n")
        for name in ("uvx", "open", "launchctl", "systemctl", "editor"):
            self.executable(name, self.recorder)
        self.executable("git", self.recorder +
            "if os.environ.get('HEY_GIT_FAIL') == '1': raise SystemExit(23)\nprint('abc123')\n")
        self.executable("sudo", self.recorder +
            "args = sys.argv[1:]\n"
            "if args[0] in ('mkdir', 'touch', 'tee'):\n"
            "    boundary = pathlib.Path(os.environ['HEY_HOST_BOUNDARY'])\n"
            "    for value in args[1:]:\n"
            "        if not value.startswith('-'): assert pathlib.Path(value).is_relative_to(boundary)\n"
            "elif args[0] not in ('launchctl', 'systemctl'): raise SystemExit(94)\n"
            "os.execvp(args[0], args)\n")
        self.executable("skillkit-sync", self.recorder, self.root / "bin")
        self.executable("zbench-report", self.recorder +
            "(root / 'benchmark-report.json').write_text(json.dumps({'args': sys.argv[1:], 'stdin': sys.stdin.read()}))\n"
            "raise SystemExit(int(os.environ.get('HEY_REPORT_EXIT', '0')))\n", self.root / "bin")

    def executable(self, name, body, directory=None):
        path = (directory or self.tools) / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)
        return path

    def run_task(self, *args, **kwargs):
        return subprocess.run([self.binary, *args], cwd=self.caller, env=self.env,
                              capture_output=True, text=True, timeout=10, **kwargs)

    def operations(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_firmware_build_copies_all_hex_and_checksum_outputs(self):
        result_dir = self.root / "result"
        result_dir.mkdir()
        expected = {"default.hex": b"first", "other layout.hex": b"second", "firmware.md5": b"checksum"}
        for name, content in expected.items():
            (result_dir / name).write_bytes(content)
        result = self.run_task("ergodox:build")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name, content in expected.items():
            self.assertEqual((self.root / "config/ergodox" / name).read_bytes(), content)
        self.assertEqual(self.operations()[0][:3], ["nix", ["build", ".#ergodox-firmware", "--print-build-logs"], str(self.root)])

    def test_failed_or_incomplete_firmware_build_cannot_report_success(self):
        self.env["HEY_FAIL_ARG"] = ".#ergodox-firmware"
        result = self.run_task("ergodox:build")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.env.pop("HEY_FAIL_ARG")
        result = self.run_task("ergodox:build")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no .hex", result.stderr)
        self.assertEqual(list((self.root / "config/ergodox").iterdir()), [])

    def test_editor_arguments_and_source_path_remain_literal(self):
        self.env["EDITOR"] = "editor --wait"
        result = self.run_task("ergodox:edit")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations()[0][:3], ["editor", ["--wait", str(self.root / "packages/ergodox-firmware/src")], str(self.caller)])

    def test_missing_firmware_cannot_open_or_flash_a_tool(self):
        result = self.run_task("ergodox:flash", "missing.hex")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Firmware not found", result.stderr)
        self.assertEqual(self.operations(), [])

    def test_gui_flash_route_does_not_run_the_usb_loader(self):
        firmware = self.root / "firmware.hex"
        firmware.write_text("firmware")
        (self.host / "Keymapp.app").mkdir()
        self.executable("teensy_loader_cli", self.recorder)
        result = self.run_task("ergodox:flash", str(firmware))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row[:2] for row in self.operations()], [["open", ["-a", "Keymapp"]]])

    def test_cli_flash_waits_for_enter_and_preserves_the_file_argument(self):
        firmware = self.root / "firmware ' $().hex"
        firmware.write_text("firmware")
        self.executable("teensy_loader_cli", self.recorder)
        result = self.run_task("ergodox:flash", str(firmware), input="\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row[:2] for row in self.operations()], [["teensy_loader_cli", ["-mmcu=atmega32u4", "-w", str(firmware)]]])

    def test_eof_cannot_bypass_the_flash_confirmation(self):
        firmware = self.root / "firmware.hex"
        firmware.write_text("firmware")
        self.executable("teensy_loader_cli", self.recorder)
        result = self.run_task("ergodox:flash", str(firmware), input="")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.operations(), [])

    def test_draw_and_info_use_the_selected_checkout(self):
        config = self.root / "packages/ergodox-firmware/src/config.h"
        config.write_text("#define DEBOUNCE 7\n#define TAPPING_TERM 180\n")
        drawn = self.run_task("ergodox:draw")
        self.assertEqual(drawn.returncode, 0, drawn.stderr)
        self.assertEqual(self.operations()[0][:2], ["uvx", ["--from", "keymap-drawer", "keymap", "draw", str(self.root / "config/ergodox/keymap.yaml"), "-o", str(self.root / "config/ergodox/layout.svg")]])
        info = self.run_task("ergodox:info")
        self.assertEqual(info.returncode, 0, info.stderr)
        self.assertIn("#define DEBOUNCE 7", info.stdout)
        self.assertIn("#define TAPPING_TERM 180", info.stdout)

    def test_repl_uses_a_private_expression_and_cleans_it_after_exit(self):
        result = self.run_task("repl")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "repl-expression").read_text(), f'(builtins.getFlake {json.dumps(str(self.root))})')
        command = self.operations()[0]
        self.assertEqual(command[1][:2], ["repl", "<nixpkgs>"])
        self.assertFalse(Path(command[1][-1]).exists())
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_skillkit_receives_a_child_only_checkout_override(self):
        result = self.run_task("skillkit:sync")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations()[0], ["skillkit-sync", [], str(self.caller), str(self.root)])
        self.assertEqual(self.env["DOTFILES"], "/stale")

    def test_skill_cleanup_preserves_unrelated_and_symlinked_local_skills(self):
        local = self.root / ".agents/skills"
        global_skills = self.home / ".agents/skills"
        for base, name in ((local, "leaked"), (global_skills, "leaked"), (global_skills, "unrelated"), (global_skills, "shared")):
            (base / name).mkdir(parents=True)
            (base / name / "SKILL.md").write_text(name)
        shared = self.root / "shared-source"
        shared.mkdir()
        (shared / "SKILL.md").write_text("shared")
        (local / "shared").symlink_to(shared)
        result = self.run_task("skills:cleanup-local-leaks")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((global_skills / "leaked").exists())
        self.assertEqual((global_skills / "unrelated/SKILL.md").read_text(), "unrelated")
        self.assertEqual((global_skills / "shared/SKILL.md").read_text(), "shared")
        self.assertIn("removed 1", result.stdout)

    def test_ztest_discovers_nested_paths_without_splitting_newlines(self):
        self.executable("zunit", self.recorder)
        files = [self.root / "config/a.zunit", self.root / "config/nested/line\nbreak.zunit"]
        for path in files:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        result = self.run_task("ztest")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row[:3] for row in self.operations()], [["zunit", [str(path)], str(self.root)] for path in files])

    def test_ztest_forwards_explicit_arguments_and_rejects_an_empty_discovery(self):
        self.executable("zunit", self.recorder)
        result = self.run_task("ztest", "--tap", "a b.zunit")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations()[0][:2], ["zunit", ["--tap", "a b.zunit"]])
        self.log.unlink()
        empty = self.run_task("ztest")
        self.assertNotEqual(empty.returncode, 0)
        self.assertIn("no .zunit tests", empty.stderr)
        self.assertEqual(self.operations(), [])

    def test_benchmark_modes_forward_raw_output_host_and_report_failure(self):
        raw = "first_prompt_lag_ms=1\ninput_lag_ms=2\n"
        self.executable("zsh-bench", self.recorder + f"sys.stdout.write({raw!r})\n")
        for task, mode in (("zbench", "run"), ("zbench:check", "check"), ("zbench:compare", "compare"), ("zbench:save", "save")):
            with self.subTest(task=task):
                self.env["HEY_REPORT_EXIT"] = "29"
                result = self.run_task(task, "--iters", "4")
                self.assertEqual(result.returncode, 29, result.stderr)
                report = json.loads((self.root / "benchmark-report.json").read_text())
                self.assertEqual(report, {"args": ["--mode", mode, "--host", "fixture-host", "--dir", str(self.root / "benchmarks/zsh-bench"), "--git-rev", "abc123"], "stdin": raw})
                self.assertEqual(self.operations()[-3][:2], ["zsh-bench", ["--iters", "4"]])
                self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_failed_benchmark_does_not_update_a_report(self):
        self.executable("zsh-bench", self.recorder + "raise SystemExit(23)\n")
        result = self.run_task("zbench:save")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual([row[0] for row in self.operations()], ["zsh-bench"])
        self.assertFalse((self.root / "benchmark-report.json").exists())

    def test_cache_preview_and_nonliteral_confirmation_never_use_sudo(self):
        preview = self.run_task("setup-caches")
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn("Dry run", preview.stdout)
        self.assertIn("https://cache.numtide.com", preview.stdout)
        for answer in ("no\n", " yes\n", "YES\n", "\n"):
            with self.subTest(answer=answer):
                result = self.run_task("setup-caches", "--apply", input=answer)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("aborted", result.stdout)
        self.assertEqual(self.operations(), [])
        self.assertFalse(self.cache.exists())

    def test_eof_cannot_authorize_cache_configuration(self):
        result = self.run_task("setup-caches", "--apply", input="")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.operations(), [])
        self.assertFalse(self.cache.exists())

    def test_cache_apply_appends_once_and_restarts_only_the_selected_daemon(self):
        for platform, daemon in (("macos", ["launchctl", "kickstart", "-k", "system/org.nixos.nix-daemon"]), ("linux", ["systemctl", "restart", "nix-daemon"])):
            with self.subTest(platform=platform):
                self.cache.write_text("existing = keep\n")
                self.log.unlink(missing_ok=True)
                self.env["TEST_OS"] = platform
                result = self.run_task("setup-caches", "--apply", input="yes\n")
                self.assertEqual(result.returncode, 0, result.stderr)
                content = self.cache.read_text()
                self.assertTrue(content.startswith("existing = keep\n"))
                self.assertEqual(content.count("# BEGIN dotfiles binary caches"), 1)
                self.assertNotIn("accept-flake-config =", content)
                self.assertEqual([row[:2] for row in self.operations() if row[0] == "sudo"], [["sudo", ["mkdir", "-p", str(self.host)]], ["sudo", ["touch", str(self.cache)]], ["sudo", ["tee", "-a", str(self.cache)]], ["sudo", daemon]])
                self.assertEqual(list((self.root / "tmp").iterdir()), [])
                self.log.unlink()
                repeated = self.run_task("setup-caches", "--apply", input="yes\n")
                self.assertEqual(repeated.returncode, 0, repeated.stderr)
                self.assertEqual(self.cache.read_text(), content)
                self.assertEqual(self.operations(), [])


if __name__ == "__main__":
    unittest.main()
