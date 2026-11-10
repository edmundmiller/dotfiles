"""Check task text serialization on real native binaries and a shell parser."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeTaskTextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey text build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name)
        for name in ("task-text.bend", "launcher.c"):
            shutil.copy2(SOURCE / name, source)
        (source / "text-driver.bend").write_text(
            'import Base\nimport ./task-text.bend as Text\n'
            'def share(args: List<String>) -> List<&2, String>:\n'
            '  match args:\n'
            '    case Nil{}:\n'
            '      Nil{}\n'
            '    case head <> rest:\n'
            '      head <> share(rest)\n'
            'def dispatch(args: List<String>) -> IO(Unit):\n'
            '  match args:\n'
            '    case program <> "replace" <> text <> key <> value <> Nil{}:\n'
            '      IO.write(Text.replace_task_text(text, key, value))\n'
            '    case program <> "concat" <> rest:\n'
            '      IO.write(Text.concat_task_text(share(rest)))\n'
            '    case program <> "quote" <> text <> Nil{}:\n'
            '      IO.write(Text.quote_shell_argument(text))\n'
            '    case args:\n'
            '      IO.exit(2)\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    args : List<String> <- IO.args()\n'
            '    dispatch(args)\n'
            '    IO.exit(0)\n'
        )
        subprocess.run(["bend", str(source / "text-driver.bend"), "-o", str(source / "generated.c")], check=True)
        cls.binary = source / "text-driver"
        subprocess.run(
            ["clang", "-O2", "-pthread", str(source / "launcher.c"), "-o", str(cls.binary), "-lm"], check=True
        )

    def run_text(self, *args):
        return subprocess.run([self.binary, *args], capture_output=True, text=True, timeout=10)

    def test_replacement_matches_nonoverlapping_literal_string_semantics(self):
        cases = [
            ("", "key", "value"),
            ("aaaaa", "aa", "b"),
            ("__RELEASE__ and __RELEASE__", "__RELEASE__", "literal $() ' \\ text"),
            ("key", "key", "key inside replacement"),
            ("é\n'quoted'", "'", "'\\''"),
        ]
        for text, key, value in cases:
            with self.subTest(text=text, key=key):
                result = self.run_text("replace", text, key, value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, text.replace(key, value))

    def test_large_template_replacement_and_concatenation_use_bounded_stack(self):
        text = "line __VALUE__ literal\n" * 2500
        result = self.run_text("replace", text, "__VALUE__", "a b '$x'")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, text.replace("__VALUE__", "a b '$x'"))
        result = self.run_text("concat", "prefix\n", text, "suffix\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "prefix\n" + text + "suffix\n")

    def test_large_shell_argument_roundtrips_without_execution(self):
        with tempfile.TemporaryDirectory(prefix="hey quote fixture ") as temporary:
            marker = Path(temporary) / "must-not-exist"
            text = ("a'b $x \\ é\n" * 2500) + f"$(touch {marker})"
            quoted = self.run_text("quote", text)
            self.assertEqual(quoted.returncode, 0, quoted.stderr)
            result = subprocess.run(
                [shutil.which("bash"), "-c", "printf '%s' " + quoted.stdout],
                cwd=temporary, env=os.environ, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, text)
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
