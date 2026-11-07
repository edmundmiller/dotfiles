"""Exercise hey's process boundary without running any host operations."""

import json
import os
from pathlib import Path
import pty
import resource
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class HeyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey build ")
        cls.addClassCleanup(cls.build.cleanup)
        cls.binary = Path(cls.build.name) / "hey"
        cls.mise = Path(cls.build.name) / "mise"
        subprocess.run(
            ["bash", str(SOURCE / "build"), str(cls.binary), str(cls.mise)],
            env=os.environ | {"TMPDIR": cls.build.name},
            check=True,
        )
        cls.probe = Path(cls.build.name) / "probe"
        subprocess.run(
            ["clang", "-x", "c", "-", "-o", str(cls.probe)],
            input="""
#include <signal.h>
#include <stdio.h>
int main(void) {
    struct sigaction bus, segv;
    sigset_t pending, blocked;
    sigaction(SIGBUS, NULL, &bus);
    sigaction(SIGSEGV, NULL, &segv);
    sigpending(&pending);
    sigprocmask(SIG_SETMASK, NULL, &blocked);
    printf("%d %d %d %d\\n", bus.sa_handler == SIG_IGN,
        segv.sa_handler == SIG_IGN, sigismember(&pending, SIGPIPE),
        sigismember(&blocked, SIGPIPE));
    return 23;
}
""",
            text=True,
            check=True,
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey project ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = os.environ | {
            "PATH": f"{self.root}{os.pathsep}{self.build.name}",
            "BENDRTS": "not-a-runtime-option",
            "HEY_FIXTURE": "inherited",
        }
        self.addCleanup(self.mise.unlink, missing_ok=True)

    def fixture(self, body):
        self.mise.write_text(f"#!{sys.executable}\n" + body)
        self.mise.chmod(0o755)

    def run_hey(self, *args, **kwargs):
        return subprocess.run(
            [str(self.binary), *args],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            timeout=10,
            **kwargs,
        )

    def checkout_launcher(self):
        checkout = self.root / "checkout"
        (checkout / "bin").mkdir(parents=True)
        source = os.environ.get("HEY_TEST_LAUNCHER", SOURCE.parents[1] / "bin/hey")
        shutil.copy2(source, checkout / "bin/hey")
        (checkout / "flake.nix").write_text("{}\n")
        output = self.root / "output"
        (output / "bin").mkdir(parents=True)
        (output / "bin/hey").symlink_to(self.binary)
        tools = self.root / "tools"
        tools.mkdir()
        nix = tools / "nix"
        # Model the build process's signal side effects, not Nix internals.
        # Supporting run as well lets this regression fail on the old launcher.
        nix.write_text(
            f"#!{sys.executable}\n"
            "import os, pathlib, signal, sys\n"
            "signal.signal(signal.SIGSEGV, signal.SIG_DFL)\n"
            "signal.signal(signal.SIGPIPE, signal.SIG_IGN)\n"
            "flake = next(a[:-4] for a in sys.argv[2:] if a.endswith('#hey'))\n"
            "if not (pathlib.Path(flake) / 'flake.nix').is_file(): sys.exit(41)\n"
            "status = int(os.environ.get('HEY_TEST_BUILD_STATUS', '0'))\n"
            "if status: sys.exit(status)\n"
            "output = os.environ['HEY_TEST_OUTPUT']\n"
            "if sys.argv[1] == 'build': print(output)\n"
            "else:\n"
            "    binary = output + '/bin/hey'\n"
            "    os.execv(binary, [binary, *sys.argv[sys.argv.index('--') + 1:]])\n"
        )
        nix.chmod(0o755)
        self.env.update(
            PATH=f"{tools}{os.pathsep}{os.environ['PATH']}", HEY_TEST_OUTPUT=str(output)
        )
        return "checkout/bin/hey"

    def test_checkout_launcher_preserves_inherited_signals(self):
        launcher = self.checkout_launcher()
        self.mise.symlink_to(self.probe)

        def setup_signals():
            for sig in (signal.SIGBUS, signal.SIGSEGV):
                signal.signal(sig, signal.SIG_IGN)
            signal.signal(signal.SIGPIPE, signal.SIG_DFL)
            signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGPIPE])
            os.kill(os.getpid(), signal.SIGPIPE)

        result = subprocess.run(
            [shutil.which("bash"), launcher, "task"],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            preexec_fn=setup_signals,
            timeout=10,
        )
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(result.stdout, b"1 1 1 1\n")

    def test_checkout_launcher_preserves_project_arguments_and_process(self):
        launcher = self.checkout_launcher()
        self.env["CDPATH"] = "."
        self.fixture(
            "import json, os, sys\n"
            "print(json.dumps([os.getpid(), os.getcwd(), os.environ['CDPATH'], "
            "os.fstat(int(os.environ['HEY_TEST_FD'])).st_size, "
            "[os.fsencode(x).hex() for x in sys.argv[1:]]]))\n"
            "sys.exit(23)\n"
        )
        args = [b"task", b"a b", b"", b"$(false)", b"\xff", b"--help"]
        with tempfile.TemporaryFile() as inherited:
            inherited.write(b"inherited bytes")
            inherited.flush()
            self.env["HEY_TEST_FD"] = str(inherited.fileno())
            with subprocess.Popen(
                [shutil.which("bash"), launcher, *args],
                cwd=self.root,
                env=self.env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                pass_fds=(inherited.fileno(),),
            ) as child:
                stdout, stderr = child.communicate(timeout=10)
                self.assertEqual(child.returncode, 23, stderr)
                self.assertEqual(
                    json.loads(stdout),
                    [
                        child.pid,
                        str(self.root.resolve()),
                        ".",
                        15,
                        [x.hex() for x in [b"run", *args]],
                    ],
                )
        self.env["HEY_TEST_BUILD_STATUS"] = "37"
        result = subprocess.run(
            [shutil.which("bash"), launcher, "task"],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 37, result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_build_preserves_literal_executable_path(self):
        names = [r"mise\\name", 'mise "\\\n\ré']
        # APFS rejects non-UTF-8 filenames before the executable can be built.
        if sys.platform.startswith("linux"):
            names.append(os.fsdecode(b"mise\xff"))
        for name in names:
            with self.subTest(name=name):
                target = self.root / name
                target.symlink_to(self.probe)
                binary = self.root / "hey-literal"
                build = subprocess.run(
                    ["bash", str(SOURCE / "build"), str(binary), str(target)],
                    capture_output=True,
                    timeout=60,
                )
                self.assertEqual(build.returncode, 0, build.stderr)
                result = subprocess.run(
                    [binary, "task"], capture_output=True, timeout=10
                )
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertEqual(result.stdout, b"0 0 0 0\n")

    def test_dispatch_preserves_literal_argument_bytes(self):
        self.fixture(
            "import json, os, sys\n"
            "print(json.dumps([os.fsencode(x).hex() for x in sys.argv[1:]]))\n"
        )
        cases = [([], [b"tasks"])]
        tail = [b"a b", b"", b"$(false)", b"line\nbreak", b"\xff", b"--help"]
        # Exercise native argv handling before the proved Bend dispatch runs.
        for help_arg in (b"help", b"-h", b"--help", b""):
            cases.extend(
                [
                    ([help_arg], [b"tasks"]),
                    ([help_arg, b"re", *tail], [b"run", b"re", *tail, b"--help"]),
                ]
            )
        for command in (b"re", b"helpful", b"--help=1", b"--", b"\xff"):
            args = [command, *tail, b"+RTS", b"--threads", b"8", b"-RTS", b"--RTS"]
            cases.append((args, [b"run", *args]))
        for args, expected in cases:
            with self.subTest(args=args):
                result = self.run_hey(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), [x.hex() for x in expected])
                self.assertEqual(result.stderr, b"")

    def test_environment_directory_streams_and_exit_status(self):
        self.fixture(
            "import os, sys\n"
            "assert os.getcwd() == os.environ['HEY_EXPECT_CWD']\n"
            "assert os.environ['HEY_FIXTURE'] == 'inherited'\n"
            "assert os.environ['BENDRTS'] == 'not-a-runtime-option'\n"
            "sys.stdout.buffer.write(sys.stdin.buffer.read())\n"
            "sys.stderr.buffer.write(b'error\\x00bytes')\n"
            "sys.exit(23)\n"
        )
        self.env["HEY_EXPECT_CWD"] = str(self.root.resolve())
        data = b"stdin\x00\xff\n" * 10000
        result = self.run_hey("task", input=data)
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(result.stdout, data)
        self.assertEqual(result.stderr, b"error\x00bytes")

    def test_exec_keeps_pid_and_streams_before_stdin_closes(self):
        self.fixture(
            "import os, sys\n"
            "print(os.getpid(), flush=True)\n"
            "print(sys.stdin.readline(), end='', flush=True)\n"
            "sys.stdin.read()\n"
        )
        with subprocess.Popen(
            [self.binary, "task"],
            cwd=self.root,
            env=self.env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ) as child:
            try:
                self.assertTrue(select.select([child.stdout], [], [], 5)[0])
                self.assertEqual(int(child.stdout.readline()), child.pid)
                child.stdin.write(b"interactive\n")
                child.stdin.flush()
                self.assertTrue(select.select([child.stdout], [], [], 5)[0])
                self.assertEqual(child.stdout.readline(), b"interactive\n")
                child.send_signal(signal.SIGTERM)
                self.assertEqual(child.wait(timeout=5), -signal.SIGTERM)
            finally:
                if child.poll() is None:
                    child.kill()

    def test_terminal_descriptors_are_inherited(self):
        self.fixture("import os\nprint([os.isatty(fd) for fd in (0, 1, 2)])\n")
        master, slave = pty.openpty()
        try:
            result = subprocess.run(
                [self.binary, "task"],
                cwd=self.root,
                env=self.env,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                timeout=10,
            )
            self.assertEqual(result.returncode, 0)
            self.assertTrue(select.select([master], [], [], 5)[0])
            self.assertEqual(os.read(master, 1024), b"[True, True, True]\r\n")
        finally:
            os.close(master)
            os.close(slave)

    def test_only_caller_file_descriptors_survive_exec(self):
        self.fixture(
            "import json, os\n"
            "opened = []\n"
            "for fd in range(3, 256):\n"
            "    try: os.fstat(fd)\n"
            "    except OSError: continue\n"
            "    opened.append(fd)\n"
            "print(json.dumps(opened))\n"
        )
        with tempfile.TemporaryFile() as inherited:
            result = self.run_hey("task", pass_fds=(inherited.fileno(),))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), [inherited.fileno()])

    def test_inherited_sigpipe_disposition_is_preserved(self):
        self.mise.write_text(f"#!{shutil.which('bash')}\nkill -PIPE $$\nexit 23\n")
        self.mise.chmod(0o755)
        for restore, expected in ((True, -signal.SIGPIPE), (False, 23)):
            with self.subTest(restore=restore):
                result = self.run_hey("task", restore_signals=restore)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_ignored_fault_signals_and_pending_sigpipe_survive_exec(self):
        self.mise.symlink_to(self.probe)
        for ignored, pending in (
            (False, False),
            (True, False),
            (False, True),
            (True, True),
        ):
            with self.subTest(ignored=ignored, pending=pending):

                def setup_signals():
                    for sig in (signal.SIGBUS, signal.SIGSEGV):
                        signal.signal(
                            sig, signal.SIG_IGN if ignored else signal.SIG_DFL
                        )
                    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
                    if pending:
                        signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGPIPE])
                        os.kill(os.getpid(), signal.SIGPIPE)

                result = self.run_hey("task", preexec_fn=setup_signals)
                self.assertEqual(result.returncode, 23, result.stderr)
                expected = (
                    f"{int(ignored)} {int(ignored)} {int(pending)} {int(pending)}\n"
                )
                self.assertEqual(result.stdout, expected.encode())

    def test_forwarding_with_one_spare_descriptor(self):
        self.mise.symlink_to(self.probe)
        result = self.run_hey(
            "task",
            preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_NOFILE, (4, 4)),
        )
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(result.stdout, b"0 0 0 0\n")

    @unittest.skipUnless(sys.platform == "linux", "Linux address-space limit")
    def test_forwarding_under_one_gib_address_space_limit(self):
        self.mise.symlink_to(self.probe)
        for args in (["task"], ["help", "task", *(["x"] * 100000)]):
            with self.subTest(argument_count=len(args)):
                result = self.run_hey(
                    *args,
                    preexec_fn=lambda: resource.setrlimit(
                        resource.RLIMIT_AS, (2**30, 2**30)
                    ),
                )
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertEqual(result.stdout, b"0 0 0 0\n")

    def test_invalid_executable_formats_are_rejected_without_a_shell(self):
        self.mise.write_text('[[ $1 == run && $2 == "a b" ]] && exit 23\nexit 24\n')
        self.mise.chmod(0o755)
        result = self.run_hey("a b")
        self.assertEqual(result.returncode, 126, result.stderr)
        self.assertEqual(result.stdout, b"")

        subprocess.run(
            ["clang", "-x", "c", "-c", "-", "-o", str(self.mise)],
            input="int not_an_executable;\n",
            text=True,
            check=True,
        )
        self.mise.chmod(0o755)
        result = self.run_hey("task")
        self.assertEqual(result.returncode, 126, result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_target_is_fixed_at_build_time_not_selected_by_path(self):
        self.fixture("import sys\nprint('pinned mise')\nsys.exit(23)\n")
        decoy = self.root / "mise"
        decoy.write_text(f"#!{sys.executable}\nraise SystemExit(29)\n")
        decoy.chmod(0o755)
        for path in (str(self.root), "", "~/bin", None):
            with self.subTest(path=path):
                if path is None:
                    self.env.pop("PATH", None)
                else:
                    self.env["PATH"] = path
                result = self.run_hey("task")
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertEqual(result.stdout, b"pinned mise\n")
        self.mise.unlink()
        self.env["PATH"] = str(self.root)
        self.assertEqual(self.run_hey("task").returncode, 127)

    def test_exec_failures_use_shell_exit_codes(self):
        for executable, expected in ((False, 127), (True, 126)):
            with self.subTest(executable=executable):
                if executable:
                    self.mise.write_text("not executable\n")
                result = self.run_hey("task")
                self.assertEqual(result.returncode, expected)
                self.assertEqual(result.stdout, b"")
                self.assertIn(b"hey: cannot execute", result.stderr)


if __name__ == "__main__":
    unittest.main()
