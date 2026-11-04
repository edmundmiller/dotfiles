import base64
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("pi_update", ROOT / "overlays/pi/update.py")
UPDATER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UPDATER)


class PiUpdateTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.hashes = self.directory / "hashes.json"
        self.lock = self.directory / "package-lock.json"
        self.hashes.write_text('{"version":"1.4.0","sourceHash":"old","npmDepsHash":"old"}\n')
        self.lock.write_text('{"old":true}\n')
        self.original = (self.hashes.read_bytes(), self.lock.read_bytes())

        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz") as package:
            manifest = b'{"name":"@earendil-works/pi-coding-agent","version":"1.5.0"}'
            member = tarfile.TarInfo("package/package.json")
            member.size = len(manifest)
            package.addfile(member, io.BytesIO(manifest))
        self.tarball = archive.getvalue()

        tools = self.directory / "bin"
        tools.mkdir()
        for name, body in {
            "npm": "printf '%s\\n' '{\"version\":\"1.5.0\",\"lockfileVersion\":3}' > package-lock.json\n",
            "prefetch-npm-deps": 'test "$NPM_FETCHER_VERSION" = 2 || exit 1\nprintf "sha256-new-dependencies=\\n"\n',
        }.items():
            tool = tools / name
            tool.write_text("#!/bin/sh\nset -eu\n" + body)
            tool.chmod(0o755)
        environment = patch.dict(os.environ, {"PATH": str(tools)})
        environment.start()
        self.addCleanup(environment.stop)

    def run_update(self, version):
        with patch.object(sys, "argv", ["update.py", str(self.directory), version]):
            UPDATER.main()

    def test_updates_version_source_and_dependency_pins_together(self):
        with patch.object(UPDATER, "urlopen", return_value=io.BytesIO(self.tarball)):
            self.run_update("1.5.0")
        hashes = json.loads(self.hashes.read_text())
        self.assertEqual(hashes["version"], "1.5.0")
        self.assertEqual(
            hashes["sourceHash"],
            "sha256-" + base64.b64encode(hashlib.sha256(self.tarball).digest()).decode(),
        )
        self.assertEqual(hashes["npmDepsHash"], "sha256-new-dependencies=")
        self.assertEqual(json.loads(self.lock.read_text()), {"version": "1.5.0", "lockfileVersion": 3})

    def test_failed_dependency_preparation_preserves_both_pins(self):
        tool = self.directory / "bin/prefetch-npm-deps"
        tool.write_text("#!/bin/sh\nexit 9\n")
        with patch.object(UPDATER, "urlopen", return_value=io.BytesIO(self.tarball)):
            with self.assertRaises(subprocess.CalledProcessError):
                self.run_update("1.5.0")
        self.assertEqual((self.hashes.read_bytes(), self.lock.read_bytes()), self.original)

    def test_same_version_preserves_pins_without_network_access(self):
        with patch.object(UPDATER, "urlopen", side_effect=AssertionError("unexpected download")):
            self.run_update("1.4.0")
        self.assertEqual((self.hashes.read_bytes(), self.lock.read_bytes()), self.original)

    def test_rejects_downgrades_and_non_release_versions_without_writing(self):
        for version in ("1.3.9", "latest", "1.5.0; touch unsafe", "1.5.0-beta.1"):
            with self.subTest(version=version), self.assertRaises(SystemExit):
                self.run_update(version)
            self.assertEqual((self.hashes.read_bytes(), self.lock.read_bytes()), self.original)
