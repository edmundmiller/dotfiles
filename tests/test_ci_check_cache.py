"""Candidate cache confidentiality, provenance and cache-miss behavior."""

import base64
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from scripts import ci_check_cache as cache


class CheckCacheTests(unittest.TestCase):
    def setUp(self):
        self.sha, self.base = "a" * 40, "b" * 40
        self.url = "https://github.com/edmundmiller/dotfiles/actions/runs/123"
        self.run = dict(
            run_attempt=2,
            repository=dict(full_name="edmundmiller/dotfiles"),
            head_repository=dict(full_name="edmundmiller/dotfiles"),
        )
        self.artifact = dict(
            id=456,
            expired=False,
            size_in_bytes=600,
            name=f"{cache.VERSION}-{self.sha}-2",
        )
        self.entry = dict(
            check="done-delivery-tests",
            kind="regular",
            deriver="",
            path="/nix/store/" + "0" * 32 + "-done-delivery-tests",
        )
        self.entry["export"] = base64.b64encode(
            cache.empty_export(self.entry["path"], "regular", "")
        ).decode()
        self.addCleanup(patch.stopall)
        patch.dict(
            os.environ,
            dict(
                GITHUB_SHA=self.sha,
                VALIDATION_BASE=self.base,
                GITHUB_EVENT_NAME="push",
                GITHUB_REF="refs/heads/main",
            ),
        ).start()
        patch.object(cache.candidate_ci, "git", return_value=self.sha).start()

    def archive(self, entries):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as zipped:
            zipped.writestr(
                "checks.json", json.dumps(dict(version=cache.VERSION, entries=entries))
            )
        return data.getvalue()

    def restore(self, entries=None, denial=None):
        def api(endpoint):
            if "/artifacts?" in endpoint:
                return dict(artifacts=[self.artifact])
            return self.run

        imported = []
        with (
            patch.object(
                cache.candidate_ci,
                "passing_candidate",
                side_effect=denial,
                return_value=self.url,
            ),
            patch.object(cache.candidate_ci, "github", side_effect=api),
            patch.object(
                cache.subprocess,
                "check_output",
                return_value=self.archive([self.entry] if entries is None else entries),
            ),
            patch.object(
                cache.subprocess,
                "run",
                side_effect=lambda *a, **kw: imported.append(kw["input"]),
            ),
            patch.object(cache.sys, "argv", ["ci_check_cache", "restore"]),
            contextlib.redirect_stdout(io.StringIO()) as output,
        ):
            result = cache.main()
        self.assertEqual(result, 0)
        return imported, output.getvalue()

    def test_restore_workflow_step_preserves_source_files(self):
        source = Path(__file__).resolve().parents[1]
        workflow = (source / ".github/workflows/ci.yml").read_text()
        step = workflow.split(
            "      - name: Restore exact successful candidate check outputs\n", 1
        )[1].split("      - name:", 1)[0]
        command = shlex.split(step.split("        run: ", 1)[1].strip())
        env = os.environ.copy()
        env.pop("PYTHONDONTWRITEBYTECODE", None)
        env["GITHUB_EVENT_NAME"] = "workflow_dispatch"
        for key, value in re.findall(r"^          (\w+): (.+)$", step, re.MULTILINE):
            if "${{" not in value:
                env[key] = value.strip("\"'")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            for name in ("ci_check_cache.py", "candidate_ci.py", "validation.py"):
                shutil.copyfile(source / "scripts" / name, root / "scripts" / name)
            before = {path.relative_to(root) for path in root.rglob("*")}
            subprocess.run(
                command, cwd=root, env=env, check=True, capture_output=True, text=True
            )
            self.assertEqual(
                {path.relative_to(root) for path in root.rglob("*")}, before
            )

    def test_successful_candidate_imports_empty_output(self):
        imported, output = self.restore()
        self.assertEqual(imported, [base64.b64decode(self.entry["export"])])
        self.assertIn("imported 1 empty outputs", output)
        self.assertIn(self.url, output)

    def test_untrusted_or_unavailable_sources_are_cache_misses(self):
        scenarios = [
            ("event", "pull_request"),
            ("ref", "refs/heads/candidate/x/y"),
            ("sha", "c" * 40),
            ("repo", "attacker/dotfiles"),
            ("expired", True),
            ("attempt", "1"),
            ("denial", ValueError("Latest exact-candidate CI is not successful")),
            ("denial", subprocess.TimeoutExpired("gh", 30)),
            ("denial", [self.url, ValueError("A rerun started during download")]),
        ]
        for field, value in scenarios:
            with self.subTest(field=field, value=value):
                original_run, original_artifact = (
                    copy.deepcopy(self.run),
                    self.artifact.copy(),
                )
                env = os.environ.copy()
                if field in ("event", "ref", "sha"):
                    os.environ[
                        {
                            "event": "GITHUB_EVENT_NAME",
                            "ref": "GITHUB_REF",
                            "sha": "GITHUB_SHA",
                        }[field]
                    ] = value
                elif field == "repo":
                    self.run["head_repository"]["full_name"] = value
                elif field == "expired":
                    self.artifact["expired"] = value
                elif field == "attempt":
                    self.artifact["name"] = f"{cache.VERSION}-{self.sha}-{value}"
                imported, output = self.restore(
                    denial=value if field == "denial" else None
                )
                self.assertEqual(imported, [])
                self.assertIn("normal validation still required", output)
                self.run, self.artifact = original_run, original_artifact
                os.environ.clear()
                os.environ.update(env)

    def test_private_payload_or_metadata_rejects_entire_artifact(self):
        for field, value in (
            (
                "export",
                base64.b64encode(
                    base64.b64decode(self.entry["export"]) + b"PRIVATE-SENTINEL"
                ).decode(),
            ),
            ("path", "/nix/store/" + "0" * 32 + "-private-source"),
            ("deriver", "/nix/store/" + "0" * 32 + "-private-source.drv"),
            ("kind", "symlink"),
        ):
            with self.subTest(field=field):
                bad = self.entry | {field: value}
                imported, output = self.restore(entries=[self.entry, bad])
                self.assertEqual(imported, [])
                self.assertIn("normal validation still required", output)

    def test_nonempty_executable_and_symlink_outputs_are_not_published(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            private = root / "private"
            private.write_text("PRIVATE-SENTINEL")
            executable = root / "executable"
            executable.touch(mode=0o755)
            link = root / "link"
            link.symlink_to(private)
            nonempty_dir = root / "source"
            nonempty_dir.mkdir()
            (nonempty_dir / "input").write_text("PRIVATE-SENTINEL")
            cache.save(
                root / "cache",
                [
                    f"done-delivery-tests={p}"
                    for p in (private, executable, link, nonempty_dir)
                ],
            )
            payload = (root / "cache/checks.json").read_text()
            self.assertEqual(json.loads(payload)["entries"], [])
            self.assertNotIn("PRIVATE-SENTINEL", payload)


if __name__ == "__main__":
    unittest.main()
