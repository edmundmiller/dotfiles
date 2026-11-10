"""Observe filesystem effects through a native Bend command boundary."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import uuid

SOURCE = Path(__file__).resolve().parent


class NativeFilesystemTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey filesystem build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name)
        for path in SOURCE.iterdir():
            if path.suffix in (".bend", ".c", ".h"):
                shutil.copy2(path, source)
        (source / "filesystem-driver.bend").write_text(
            'import Base\nimport ./posix.bend as Posix\n'
            'def print_names(names: List<&2, String>) -> IO(Unit):\n'
            '  match names:\n'
            '    case Nil{}:\n'
            '      IO.pure(Unit, Unit{})\n'
            '    case name <> rest:\n'
            '      do IO<Unit>:\n'
            '        IO.print(String.quote(name))\n'
            '        print_names(rest)\n'
            'def dispatch(args: List<String>) -> IO(Unit):\n'
            '  match args:\n'
            '    case program <> "uuid" <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        value : String <- Posix.random_uuid()\n'
            '        IO.print(value)\n'
            '    case program <> "absolute" <> path <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        resolved : String <- Posix.absolute_path(path)\n'
            '        IO.print(resolved)\n'
            '    case program <> "dirs" <> path <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        names : List<&2, String> <- Posix.list_directories(path)\n'
            '        print_names(names)\n'
            '    case program <> "entries" <> path <> Nil{}:\n'
            '      do IO<Unit>:\n'
            '        names : List<&2, String> <- Posix.list_entries(path)\n'
            '        print_names(names)\n'
            '    case args:\n'
            '      IO.exit(2)\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    args : List<String> <- IO.args()\n'
            '    dispatch(args)\n'
            '    IO.exit(0)\n'
        )
        subprocess.run(["bend", str(source / "filesystem-driver.bend"), "-o", str(source / "generated.c")], check=True)
        cls.binary = source / "filesystem-driver"
        subprocess.run(["clang", "-O2", "-pthread", str(source / "launcher.c"), "-o", str(cls.binary), "-lm"], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey filesystem fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.env = os.environ | {"HOME": str(self.home)}

    def run_filesystem(self, mode, path=None):
        args = [self.binary, mode]
        if path is not None:
            args.append(path)
        return subprocess.run(args, cwd=self.root, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_uuid_values_are_distinct_canonical_random_version_four_ids(self):
        values = []
        for _ in range(2):
            result = self.run_filesystem("uuid")
            self.assertEqual(result.returncode, 0, result.stderr)
            value = result.stdout.strip()
            parsed = uuid.UUID(value)
            self.assertEqual(parsed.version, 4)
            self.assertEqual(parsed.variant, uuid.RFC_4122)
            self.assertEqual(str(parsed), value)
            values.append(value)
        self.assertNotEqual(values[0], values[1])

    def test_absolute_paths_resolve_relative_home_symlink_and_missing_suffix(self):
        real = self.root / "real parent"
        real.mkdir()
        (real / "Xcode.app").mkdir()
        (self.root / "linked").symlink_to(real)
        (self.home / "Xcode.app").mkdir()
        cases = {
            "linked/Xcode.app": real / "Xcode.app",
            "linked/not-yet/Xcode.app": real / "not-yet/Xcode.app",
            "linked/../New.app": self.root / "New.app",
            "~/Xcode.app": self.home / "Xcode.app",
            "~": self.home,
            ".": self.root,
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                result = self.run_filesystem("absolute", value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, str(expected) + "\n")
        self.assertFalse((real / "not-yet").exists())
        self.assertFalse((self.root / "New.app").exists())

    def test_directory_listing_keeps_real_directories_distinct_from_symlinks(self):
        directory = self.root / "directory"
        directory.mkdir()
        names = {"real folder", "file ' name", "linked folder", "line\nbreak"}
        (directory / "real folder").mkdir()
        (directory / "file ' name").write_text("data")
        (directory / "linked folder").symlink_to(directory / "real folder")
        (directory / "line\nbreak").write_text("data")
        entries = self.run_filesystem("entries", str(directory))
        self.assertEqual(entries.returncode, 0, entries.stderr)
        self.assertEqual({json.loads(line) for line in entries.stdout.splitlines()}, names)
        dirs = self.run_filesystem("dirs", str(directory))
        self.assertEqual(dirs.returncode, 0, dirs.stderr)
        self.assertEqual([json.loads(line) for line in dirs.stdout.splitlines()], ["real folder"])

    def test_missing_directory_is_an_empty_observation(self):
        result = self.run_filesystem("entries", str(self.root / "missing"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
