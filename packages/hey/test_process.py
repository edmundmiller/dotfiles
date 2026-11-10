"""Exercise the native subprocess boundary with disposable executables."""

import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeProcessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="hey process build ")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.source = Path(cls.temp.name)
        for name in ("os.bend", "environment.c", "toolchain.c", "utf8-support.h", "process.c", "process-support.h", "resources.bend", "resources.c", "launcher.c"):
            shutil.copy2(SOURCE / name, cls.source)
        (cls.source / "main.bend").write_text(
            'import Base\nimport ./os.bend as OS\nimport ./resources.bend as Resources\n'
            'def emit_result(result: OS.ProcessResult) -> IO(Unit):\n'
            '  match result:\n'
            '    case OS.ProcessResult{status, out, err}:\n'
            '      do IO<Unit>:\n'
            '        IO.write(out)\n'
            '        IO.print_err(err)\n'
            '        IO.exit(status)\n'
            'def share(args: List<String>) -> List<&2, String>:\n'
            '  match args:\n'
            '    case Nil{}:\n'
            '      Nil{}\n'
            '    case head <> tail:\n'
            '      head <> share(tail)\n'
            'def finish_cleanup(mode: String, token: U32) -> IO(Unit):\n'
            '  match mode:\n'
            '    case "cancel":\n'
            '      do IO<Unit>:\n'
            '        Resources.cancel_cleanup(token)\n'
            '        IO.exit(0)\n'
            '    case "fail":\n'
            '      IO.die(Unit, 23, "expected task failure")\n'
            '    case mode:\n'
            '      Resources.finish_task(0)\n'
            'def dispatch(args: List<String>) -> IO(Unit):\n'
            '  match args:\n'
            '    case Con{program, Con{"cleanup", Con{mode, Con{path, Nil{}}}}}:\n'
            '      do IO<Unit>:\n'
            '        token : U32 <- Resources.defer_command(["rm", "-rf", "--", path])\n'
            '        finish_cleanup(mode, token)\n'
            '    case Con{program, Con{"cleanup-failure", rest}}:\n'
            '      do IO<Unit>:\n'
            '        token : U32 <- Resources.defer_command(rest)\n'
            '        Resources.finish_task(0)\n'
            '    case Con{program, Con{"capture", rest}}:\n'
            '      do IO<Unit>:\n'
            '        result : OS.ProcessResult <- OS.run(rest, True{})\n'
            '        emit_result(result)\n'
            '    case Con{program, Con{"file", rest}}:\n'
            '      do IO<Unit>:\n'
            '        source : String <- OS.required_environment("HEY_TEST_INPUT")\n'
            '        result : OS.ProcessResult <- OS.run_with_input(rest, True{}, source)\n'
            '        emit_result(result)\n'
            '    case Con{program, Con{"file-scoped", rest}}:\n'
            '      do IO<Unit>:\n'
            '        source : String <- OS.required_environment("HEY_TEST_INPUT")\n'
            '        +shared : List<&2, String> = share(rest)\n'
            '        first : OS.ProcessResult <- OS.run_with_input(OS.linear_arguments(shared), True{}, source)\n'
            '        OS.check(first)\n'
            '        result : OS.ProcessResult <- OS.run(OS.linear_arguments(shared), True{})\n'
            '        emit_result(result)\n'
            '    case Con{program, Con{"unscoped", rest}}:\n'
            '      do IO<Unit>:\n'
            '        +shared : List<&2, String> = share(rest)\n'
            '        first : OS.ProcessResult <- OS.run_without_environment(OS.linear_arguments(shared), True{}, "HEY_PROBE")\n'
            '        OS.check(first)\n'
            '        result : OS.ProcessResult <- OS.run(OS.linear_arguments(shared), True{})\n'
            '        emit_result(result)\n'
            '    case Con{program, Con{"scoped", rest}}:\n'
            '      do IO<Unit>:\n'
            '        +shared : List<&2, String> = share(rest)\n'
            '        scoped : OS.ProcessResult <- OS.run_with_environment(OS.linear_arguments(shared), True{}, "HEY_PROBE", "child-only")\n'
            '        OS.check(scoped)\n'
            '        result : OS.ProcessResult <- OS.run(OS.linear_arguments(shared), True{})\n'
            '        emit_result(result)\n'
            '    case Con{program, Con{"inherit", rest}}:\n'
            '      do IO<Unit>:\n'
            '        OS.checked(rest)\n'
            '        IO.exit(0)\n'
            '    case args:\n'
            '      IO.exit(2)\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    args : List<String> <- IO.args()\n'
            '    dispatch(args)\n'
        )
        subprocess.run(
            ["bend", str(cls.source / "main.bend"), "-o", str(cls.source / "generated.c")],
            check=True,
        )
        cls.binary = cls.source / "process-driver"
        subprocess.run(
            ["clang", "-O2", "-pthread", str(cls.source / "launcher.c"), "-o", str(cls.binary), "-lm"],
            check=True,
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey process project ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()

    def executable(self, body):
        path = self.root / "target"
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)
        return path

    def run_process(self, mode, *args, **kwargs):
        return subprocess.run(
            [self.binary, mode, *args], cwd=self.root, capture_output=True, timeout=10, **kwargs
        )

    def test_capture_preserves_literal_arguments_cwd_environment_and_failure(self):
        target = self.executable(
            "import json, os, sys\n"
            "print(json.dumps([sys.argv[1:], os.getcwd(), os.environ['HEY_PROBE']]))\n"
            "sys.stderr.write('diagnostic')\n"
            "sys.exit(23)\n"
        )
        result = self.run_process(
            "capture", target, "a b", "", "$(false)", "line\nbreak", "é",
            env=os.environ | {"HEY_PROBE": "inherited"},
        )
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            [["a b", "", "$(false)", "line\nbreak", "é"], str(self.root), "inherited"],
        )
        self.assertEqual(result.stderr, b"diagnostic\n")

    def test_environment_override_is_child_only_and_not_an_argument(self):
        target = self.executable(
            "import os, pathlib, sys\n"
            "assert sys.argv[1:] == ['literal']\n"
            "path = pathlib.Path('seen')\n"
            "old = path.read_text() if path.exists() else ''\n"
            "path.write_text(old + os.environ['HEY_PROBE'] + '\\n')\n"
        )
        result = self.run_process(
            "scoped", target, "literal", env=os.environ | {"HEY_PROBE": "parent-value"}
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "seen").read_text(), "child-only\nparent-value\n")

    def test_environment_removal_is_child_only(self):
        target = self.executable(
            "import os, pathlib\n"
            "with pathlib.Path('seen').open('a') as seen:\n"
            "    seen.write(os.environ.get('HEY_PROBE', 'absent') + '\\n')\n"
        )
        result = self.run_process("unscoped", target, env=os.environ | {"HEY_PROBE": "parent-value"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "seen").read_text(), "absent\nparent-value\n")

    def test_file_input_preserves_binary_bytes_and_parent_stdin(self):
        source = self.root / "input ' $() data"
        payload = b"binary\x00\xff\nfile input"
        source.write_bytes(payload)
        parent = b"parent stdin remains available"
        target = self.executable(
            "import pathlib, sys\n"
            "assert sys.argv[1:] == ['literal']\n"
            "with pathlib.Path('seen').open('a') as seen:\n"
            "    seen.write(sys.stdin.buffer.read().hex() + '\\n')\n"
        )
        result = self.run_process(
            "file-scoped", target, "literal", input=parent,
            env=os.environ | {"HEY_TEST_INPUT": str(source)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "seen").read_text().splitlines(), [payload.hex(), parent.hex()])
        self.assertEqual(source.read_bytes(), payload)

    def test_missing_input_file_cannot_start_the_command(self):
        target = self.executable("import pathlib\npathlib.Path('ran').write_text('unexpected')\n")
        result = self.run_process(
            "file", target, env=os.environ | {"HEY_TEST_INPUT": str(self.root / "missing")},
        )
        self.assertEqual(result.returncode, 126, result.stderr)
        self.assertIn(b"cannot read subprocess input", result.stderr)
        self.assertFalse((self.root / "ran").exists())

    def test_file_input_works_when_parent_stdin_is_closed(self):
        source = self.root / "input"
        source.write_bytes(b"replacement stdin")
        target = self.executable("import sys\nsys.stdout.buffer.write(sys.stdin.buffer.read())\n")
        result = self.run_process(
            "file", target, env=os.environ | {"HEY_TEST_INPUT": str(source)},
            preexec_fn=lambda: os.close(0),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"replacement stdin")

    def test_invalid_captured_text_is_not_silently_rewritten(self):
        for status, expected in ((0, 126), (23, 23)):
            with self.subTest(status=status):
                target = self.executable(f"import os\nos.write(1, b'\\xff')\nraise SystemExit({status})\n")
                result = self.run_process("capture", target)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(result.stdout, b"")
                self.assertIn(b"stdout is not valid UTF-8", result.stderr)

    def test_capture_drains_both_streams_without_pipe_deadlock(self):
        target = self.executable(
            "import os\n"
            "for _ in range(64):\n"
            "    os.write(1, b'o' * 8192)\n"
            "    os.write(2, b'e' * 8192)\n"
        )
        result = self.run_process("capture", target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"o" * 524288)
        self.assertEqual(result.stderr, b"e" * 524288 + b"\n")

    def test_inherited_streams_are_live_before_stdin_closes(self):
        target = self.executable(
            "import sys\nprint('ready', flush=True)\n"
            "print(sys.stdin.readline(), end='', flush=True)\nsys.stdin.read()\n"
        )
        with subprocess.Popen(
            [self.binary, "inherit", target], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ) as child:
            try:
                self.assertTrue(select.select([child.stdout], [], [], 5)[0])
                self.assertEqual(child.stdout.readline(), b"ready\n")
                child.stdin.write(b"interactive\n")
                child.stdin.flush()
                self.assertTrue(select.select([child.stdout], [], [], 5)[0])
                self.assertEqual(child.stdout.readline(), b"interactive\n")
                child.communicate(timeout=5)
                self.assertEqual(child.returncode, 0)
            finally:
                if child.poll() is None:
                    child.kill()

    def test_inherited_terminal_and_exit_status(self):
        target = self.executable(
            "import os, sys\nprint([os.isatty(fd) for fd in (0, 1, 2)])\nsys.exit(37)\n"
        )
        master, slave = pty.openpty()
        try:
            result = subprocess.run(
                [self.binary, "inherit", target], stdin=slave, stdout=slave, stderr=slave, timeout=10
            )
            self.assertEqual(result.returncode, 37)
            self.assertTrue(select.select([master], [], [], 5)[0])
            self.assertIn(b"[True, True, True]\r\n", os.read(master, 1024))
        finally:
            os.close(master)
            os.close(slave)

    def test_missing_and_invalid_executables_do_not_fall_back_to_a_shell(self):
        missing = self.run_process("inherit", self.root / "missing")
        self.assertEqual(missing.returncode, 127)
        target = self.root / "target"
        target.write_text("echo forbidden\n")
        target.chmod(0o755)
        for name in (str(target), "target"):
            with self.subTest(name=name):
                result = self.run_process("inherit", name, env=os.environ | {"PATH": str(self.root)})
                self.assertEqual(result.returncode, 126)
                self.assertEqual(result.stdout, b"")

    def test_registered_cleanup_runs_on_success_and_task_failure(self):
        for mode, expected in (("finish", 0), ("fail", 23)):
            with self.subTest(mode=mode):
                resource = self.root / mode
                resource.mkdir()
                (resource / "owned").write_text("owned temporary data")
                result = self.run_process("cleanup", mode, resource)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertFalse(resource.exists())

    def test_cancelled_cleanup_preserves_transferred_resource(self):
        resource = self.root / "transferred"
        resource.mkdir()
        (resource / "owned").write_text("now owned elsewhere")
        result = self.run_process("cleanup", "cancel", resource)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((resource / "owned").read_text(), "now owned elsewhere")

    def test_cleanup_failure_cannot_turn_into_task_success(self):
        target = self.executable("raise SystemExit(37)\n")
        result = self.run_process("cleanup-failure", target)
        self.assertEqual(result.returncode, 37, result.stderr)
        self.assertIn(b"cleanup command", result.stderr)

    def test_child_signal_status_is_not_reported_as_success(self):
        target = self.executable("import os, signal\nos.kill(os.getpid(), signal.SIGTERM)\n")
        result = self.run_process("inherit", target)
        self.assertEqual(result.returncode, 128 + signal.SIGTERM)


if __name__ == "__main__":
    unittest.main()
