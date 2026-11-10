"""Check gateway status protocol parsing on a native binary."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeGatewayStatusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey gateway parser ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name)
        for name in ("gateway-status.bend", "launcher.c"):
            shutil.copy2(SOURCE / name, source)
        (source / "driver.bend").write_text(
            'import Base\nimport ./gateway-status.bend as Gateway\n'
            'def report(pid: Maybe<&2, U32>) -> IO(Unit):\n'
            '  match pid:\n'
            '    case Some{value}:\n'
            '      IO.print(U32.show(value))\n'
            '    case None{}:\n'
            '      IO.print("none")\n'
            'def dispatch(args: List<String>) -> IO(Unit):\n'
            '  match args:\n'
            '    case program <> text <> Nil{}:\n'
            '      report(Gateway.gateway_pid(text))\n'
            '    case args:\n'
            '      IO.exit(2)\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    args : List<String> <- IO.args()\n'
            '    dispatch(args)\n'
            '    IO.exit(0)\n'
        )
        subprocess.run(["bend", str(source / "driver.bend"), "-o", str(source / "generated.c")], check=True)
        cls.binary = source / "gateway-parser"
        subprocess.run(["clang", "-O2", "-pthread", str(source / "launcher.c"), "-o", str(cls.binary), "-lm"], check=True)

    def test_status_formats_select_a_positive_process_id(self):
        cases = {
            'Gateway is running (PID 1234)': '1234',
            '"PID" = 5678;': '5678',
            '(PID 11)\n"PID" \t=\n 22;': '22',
            'unrelated pid=99\n(PID\t42)': '42',
            '"PID" = nope;\n(PID 73)': '73',
            '"PID" = 2147483647;': '2147483647',
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                result = subprocess.run([self.binary, value], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, expected + '\n')

    def test_unrelated_missing_zero_and_overflow_values_are_not_healthy_pids(self):
        for value in ('running', 'PID 12', '(PID12)', '(PID 0)', '"PID" = 0;', '"PID" = 2147483648;', '(PID 999999999999999999)', '(PID 12', '"PID" = 12'):
            with self.subTest(value=value):
                result = subprocess.run([self.binary, value], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, 'none\n')

    def test_large_status_output_does_not_overflow_the_embedding_stack(self):
        value = ('ordinary status detail\n' * 3000) + 'Gateway is running (PID 456)'
        result = subprocess.run([self.binary, value], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '456\n')


if __name__ == '__main__':
    unittest.main()
