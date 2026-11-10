"""Exercise native evaluation leases and pure rebuild policies."""

import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeEvaluationLockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey lock build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name)
        for path in SOURCE.iterdir():
            if path.suffix in (".bend", ".c", ".h"):
                shutil.copy2(path, source)
        (source / "lock-driver.bend").write_text(
            'import Base\n'
            'import ./evaluation-lock.bend as Lock\n'
            'import ./resources.bend as Resources\n'
            'import ./posix.bend as Posix\n'
            'import ./system-policy.bend as Policy\n'
            'def finish_mode(mode: String) -> IO(Unit):\n'
            '  match mode:\n'
            '    case "fail":\n'
            '      IO.die(Unit, 23, "fixture task failed")\n'
            '    case "hold":\n'
            '      do IO<Unit>:\n'
            '        line : String <- Posix.read_line("")\n'
            '        Resources.finish_task(0)\n'
            '    case mode:\n'
            '      Resources.finish_task(0)\n'
            'def warning_case(name: String) -> List<&2, String>:\n'
            '  match name:\n'
            '    case "healthy":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 500, 1000, 500, 0}, [])\n'
            '    case "swap84":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 500, 1000, 840, 0}, [])\n'
            '    case "swap85":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 500, 1000, 850, 0}, [])\n'
            '    case "low":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 50, 0, 0, 0}, [])\n'
            '    case "large-swap":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{4000000000, 2000000000, 4000000000, 3400000000, 0}, [])\n'
            '    case "fractional-threshold":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1005, 100, 0, 0, 0}, [])\n'
            '    case "critical":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 500, 0, 0, 4}, [])\n'
            '    case "warn":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 500, 0, 0, 2}, [])\n'
            '    case "evaluator":\n'
            '      Policy.memory_warnings(Posix.SystemMemory{1000, 500, 0, 0, 0}, ["123 nix build .#darwinConfigurations.X.system"])\n'
            '    case name:\n'
            '      []\n'
            'def show_memory(memory: Posix.SystemMemory) -> IO(Unit):\n'
            '  match memory:\n'
            '    case Posix.SystemMemory{total, available, swap_total, swap_used, level}:\n'
            '      IO.print(U32.show(total) ++ " " ++ U32.show(available) ++ " " ++ U32.show(swap_total) ++ " " ++ U32.show(swap_used) ++ " " ++ U32.show(level))\n'
            'def use_lease(mode: String, lease: Lock.EvaluationLease) -> IO(Unit):\n'
            '  match mode:\n'
            '    case "release-hold":\n'
            '      do IO<Unit>:\n'
            '        Lock.release_evaluation_lock(lease)\n'
            '        IO.print("acquired")\n'
            '        line : String <- Posix.read_line("")\n'
            '        Resources.finish_task(0)\n'
            '    case mode:\n'
            '      do IO<Unit>:\n'
            '        IO.print("acquired")\n'
            '        finish_mode(mode)\n'
            'def dispatch(args: List<String>) -> IO(Unit):\n'
            '  match args:\n'
            '    case program <> "warnings" <> name <> Nil{}:\n'
            '      IO.print(String.join(warning_case(name), "\\n"))\n'
            '    case program <> "memory" <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        memory : Posix.SystemMemory <- Posix.system_memory()\n'
            '        show_memory(memory)\n'
            '    case program <> +mode <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        lease : Lock.EvaluationLease <- Lock.acquire_evaluation_lock("fixture evaluation")\n'
            '        use_lease(mode, lease)\n'
            '    case args:\n'
            '      IO.exit(2)\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    args : List<String> <- IO.args()\n'
            '    dispatch(args)\n'
            '    Resources.finish_task(0)\n'
        )
        subprocess.run(
            ["bend", str(source / "lock-driver.bend"), "-o", str(source / "generated.c")], check=True
        )
        cls.binary = source / "lock-driver"
        subprocess.run(
            ["clang", "-O2", "-pthread", str(source / "launcher.c"), "-o", str(cls.binary), "-lm"], check=True
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey evaluation fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.env = os.environ | {
            "HOME": str(self.root),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "PATH": f"{self.tools}{os.pathsep}{os.environ['PATH']}",
        }
        self.lock = self.root / "cache/hey/system-eval.lock"

    def stop(self, child):
        if child.poll() is None:
            child.kill()
        child.communicate(timeout=10)

    def start(self, mode="hold"):
        child = subprocess.Popen(
            [self.binary, mode], cwd=self.root, env=self.env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        self.addCleanup(self.stop, child)
        return child

    def acquired(self, child):
        self.assertTrue(select.select([child.stdout], [], [], 10)[0], "lease was not acquired")
        self.assertEqual(child.stdout.readline(), "acquired\n")

    def release(self, child):
        _, error = child.communicate("\n", timeout=10)
        self.assertEqual(child.returncode, 0, error)

    def test_success_and_failure_release_owned_directory(self):
        for mode, expected in (("finish", 0), ("fail", 23)):
            with self.subTest(mode=mode):
                result = subprocess.run(
                    [self.binary, mode], cwd=self.root, env=self.env,
                    capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(result.stdout, "acquired\n")
                self.assertFalse(self.lock.exists())

    def test_live_holder_blocks_then_releases_to_waiter(self):
        holder = self.start()
        self.acquired(holder)
        waiter = self.start()
        self.assertTrue(select.select([waiter.stderr], [], [], 10)[0])
        self.assertIn("waiting for the system-evaluation lock", waiter.stderr.readline())
        self.assertFalse(select.select([waiter.stdout], [], [], 0.25)[0], "waiter entered a live lease")
        self.release(holder)
        self.acquired(waiter)
        self.release(waiter)
        self.assertFalse(self.lock.exists())

    def test_explicit_release_does_not_later_delete_the_next_owners_lease(self):
        released = self.start("release-hold")
        self.acquired(released)
        self.assertFalse(self.lock.exists())
        holder = self.start()
        self.acquired(holder)
        self.release(released)
        self.assertTrue(self.lock.exists(), "a released owner's exit deleted the next lease")
        self.release(holder)
        self.assertFalse(self.lock.exists())

    def test_killed_holder_is_reclaimed_without_manual_cleanup(self):
        holder = self.start()
        self.acquired(holder)
        holder.kill()
        holder.communicate(timeout=10)
        self.assertTrue(self.lock.exists())
        waiter = self.start()
        self.acquired(waiter)
        self.release(waiter)
        self.assertFalse(self.lock.exists())

    def test_two_stale_waiters_cannot_reclaim_each_others_new_lease(self):
        self.lock.mkdir(parents=True)
        stale_pid = 2147483647
        (self.lock / "owner.nuon").write_text(
            f'{{pid: {stale_pid}, started: "gone", label: "old", cwd: "/old", acquired: "old"}}'
        )
        barrier = self.root / "barrier"
        barrier.mkdir()
        ps = self.tools / "ps"
        ps.write_text(
            f"#!{sys.executable}\n"
            "import os, pathlib, sys, time\n"
            f"barrier = pathlib.Path({str(barrier)!r})\n"
            f"if sys.argv[-1] == '{stale_pid}':\n"
            "    (barrier / str(os.getppid())).touch()\n"
            "    deadline = time.monotonic() + 5\n"
            "    while len(list(barrier.iterdir())) < 2:\n"
            "        if time.monotonic() > deadline: raise SystemExit(90)\n"
            "        time.sleep(0.01)\n"
            "raise SystemExit(1)\n"
        )
        ps.chmod(0o755)
        children = [self.start(), self.start()]
        ready = select.select([child.stdout for child in children], [], [], 10)[0]
        self.assertEqual(len(ready), 1, "two owners entered the lease")
        first = next(child for child in children if child.stdout is ready[0])
        second = next(child for child in children if child is not first)
        self.assertEqual(first.stdout.readline(), "acquired\n")
        self.assertEqual(len(list(barrier.iterdir())), 2, "the stale-owner race was not exercised")
        self.assertFalse(select.select([second.stdout], [], [], 0.25)[0])
        self.release(first)
        self.acquired(second)
        self.release(second)
        self.assertFalse(self.lock.exists())

    def test_memory_warning_thresholds_remain_behavioral(self):
        expected = {
            "healthy": [],
            "swap84": [],
            "swap85": ["swap is 85% full (850 MiB of 1000 MiB)"],
            "low": ["only 50 MiB of 1000 MiB memory is available"],
            "large-swap": ["swap is 85% full (3400000000 MiB of 4000000000 MiB)"],
            "fractional-threshold": ["only 100 MiB of 1005 MiB memory is available"],
            "critical": ["macOS reports CRITICAL memory pressure"],
            "warn": ["macOS reports memory pressure (warn)"],
            "evaluator": ["1 other full-system evaluation(s) running:", "123 nix build .#darwinConfigurations.X.system"],
        }
        for name, lines in expected.items():
            with self.subTest(name=name):
                result = subprocess.run(
                    [self.binary, "warnings", name], env=self.env, capture_output=True, text=True, timeout=10
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip().splitlines(), lines)

    def test_native_memory_observation_has_consistent_units(self):
        result = subprocess.run(
            [self.binary, "memory"], env=self.env, capture_output=True, text=True, timeout=10
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        total, available, swap_total, swap_used, level = map(int, result.stdout.split())
        self.assertGreater(total, 0)
        self.assertLessEqual(available, total)
        self.assertLessEqual(swap_used, swap_total)


if __name__ == "__main__":
    unittest.main()
