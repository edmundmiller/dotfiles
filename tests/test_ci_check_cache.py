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
import textwrap
import unittest
from unittest.mock import patch
import zipfile

from scripts import ci_check_cache as cache
from scripts import ci_dependency_cache as dependencies


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
        command = shlex.split(step.split("        run: ", 1)[1].splitlines()[0])
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

    def test_main_cache_imports_only_validated_outputs_on_trusted_main_pushes(self):
        scenarios = (
            ("valid", {}, [self.entry], cache.VERSION),
            ("private", {}, [self.entry, self.entry | {"private": "PRIVATE-SENTINEL"}], cache.VERSION),
            ("event", {"GITHUB_EVENT_NAME": "pull_request"}, [self.entry], cache.VERSION),
            ("ref", {"GITHUB_REF": "refs/heads/candidate/x/y"}, [self.entry], cache.VERSION),
            ("repo", {"GITHUB_REPOSITORY": "attacker/dotfiles"}, [self.entry], cache.VERSION),
            ("sha", {"GITHUB_SHA": "c" * 40}, [self.entry], cache.VERSION),
            ("version", {}, [self.entry], "unknown"),
            ("oversize", {}, [self.entry], cache.VERSION),
            ("missing", {}, [self.entry], cache.VERSION),
        )
        for label, env, entries, version in scenarios:
            with self.subTest(label=label), tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / "checks.json"
                source.write_text(json.dumps(dict(version=version, entries=entries)))
                if label == "oversize":
                    source.write_bytes(b" " * (cache.LIMIT + 1))
                elif label == "missing":
                    source.unlink()
                imported = []
                with (
                    patch.dict(os.environ, {"GITHUB_REPOSITORY": "edmundmiller/dotfiles"} | env),
                    patch.object(cache.sys, "argv", ["ci_check_cache", "restore-main", directory]),
                    patch.object(cache.subprocess, "run", side_effect=lambda *a, **kw: imported.append(kw["input"])),
                    contextlib.redirect_stdout(io.StringIO()) as output,
                ):
                    self.assertEqual(cache.main(), 0)
                self.assertEqual(imported, [base64.b64decode(self.entry["export"])] if label == "valid" else [])
                self.assertIn("imported 1 empty outputs" if label == "valid" else "normal validation still required", output.getvalue())

    def test_small_selections_preserve_only_validated_previous_cache_entries(self):
        for private in (False, True):
            with self.subTest(private=private), tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / "checks.json"
                entry = self.entry | ({"private": "PRIVATE-SENTINEL"} if private else {})
                source.write_text(json.dumps(dict(version=cache.VERSION, entries=[entry])))
                cache.save(directory, [])
                payload = source.read_text()
                self.assertEqual(json.loads(payload)["entries"], [] if private else [self.entry])
                self.assertNotIn("PRIVATE-SENTINEL", payload)

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
            ("private", "PRIVATE-SENTINEL"),
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


class PublicDependencyCacheTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.env = {
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_REPOSITORY": "edmundmiller/dotfiles",
            "GITHUB_SHA": self.sha,
            "GITHUB_REF": "refs/heads/main",
        }

    def invoke(self, *command, env=None):
        with (
            patch.dict(os.environ, self.env | (env or {})),
            patch.object(dependencies.candidate_ci, "git", return_value=self.sha),
            patch.object(dependencies.sys, "argv", ["ci_dependency_cache", *command]),
            contextlib.redirect_stdout(io.StringIO()) as output,
            contextlib.redirect_stderr(io.StringIO()) as errors,
        ):
            self.assertEqual(dependencies.main(), 0)
        return output.getvalue(), errors.getvalue()

    def test_only_affected_trusted_pushes_enable_cache(self):
        with patch.object(
            dependencies.subprocess,
            "check_output",
            return_value=json.dumps({"checks": ["ha-behavior-tests"]}),
        ):
            self.assertEqual(self.invoke("plan")[0], "enabled=true\n")
            self.assertEqual(
                self.invoke(
                    "plan",
                    env={"GITHUB_REF": f"refs/heads/candidate/{'b' * 40}/{self.sha}"},
                )[0],
                "enabled=true\n",
            )
        with patch.object(
            dependencies.subprocess,
            "check_output",
            return_value=json.dumps({"checks": ["validation-tests"]}),
        ):
            self.assertEqual(self.invoke("plan")[0], "")
        with patch.object(
            dependencies.subprocess,
            "check_output",
            side_effect=AssertionError("Untrusted run accessed cache machinery"),
        ):
            for env in (
                {"GITHUB_EVENT_NAME": "pull_request"},
                {"GITHUB_EVENT_NAME": "pull_request_target"},
                {"GITHUB_EVENT_NAME": "workflow_dispatch"},
                {"GITHUB_REPOSITORY": "fork/dotfiles"},
                {"GITHUB_REF": "refs/heads/candidate/x/y"},
                {"GITHUB_REF": f"refs/heads/candidate/{self.sha}/{'b' * 40}"},
                {"GITHUB_SHA": "b" * 40},
            ):
                with self.subTest(env=env):
                    self.assertEqual(self.invoke("plan", env=env)[0], "")

    def test_export_contains_only_the_realized_public_closure(self):
        public = "/nix/store/" + "1" * 32 + "-homeassistant"
        unrealized = "/nix/store/" + "2" * 32 + "-unrealized"
        private = "/nix/store/" + "3" * 32 + "-private-host-config"

        def query(command, **kwargs):
            if command[0] == "nix":
                return json.dumps([public, unrealized])
            self.assertEqual(command[3:], [public])
            return public + "\n"

        def write_export(command, **kwargs):
            self.assertEqual(command, ["nix-store", "--export", public])
            kwargs["stdout"].write(b"PUBLIC-PACKAGE")

        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(dependencies.subprocess, "check_output", side_effect=query),
            patch.object(dependencies.subprocess, "run", side_effect=write_export),
            patch.object(Path, "exists", lambda path: str(path) in (public, private)),
        ):
            output, errors = self.invoke("export", directory)
            self.assertEqual(output, "ready=true\n")
            self.assertIn("exported 1 public store paths", errors)
            self.assertEqual(
                (Path(directory) / dependencies.ARCHIVE).read_bytes(), b"PUBLIC-PACKAGE"
            )

    def test_unsafe_closures_and_partial_exports_are_not_saved(self):
        public = "/nix/store/" + "1" * 32 + "-homeassistant"
        for unsafe in (
            public + ".drv",
            "/etc/private",
            public.replace("homeassistant", "ha-behavior-tests"),
        ):
            with (
                self.subTest(unsafe=unsafe),
                tempfile.TemporaryDirectory() as directory,
                patch.object(Path, "exists", return_value=True),
                patch.object(
                    dependencies.subprocess,
                    "check_output",
                    side_effect=[json.dumps([public]), public + "\n" + unsafe + "\n"],
                ),
            ):
                output, errors = self.invoke("export", directory)
                self.assertEqual(output, "")
                self.assertIn("normal validation required", errors)
                self.assertEqual(list(Path(directory).iterdir()), [])

        def fail_export(command, **kwargs):
            kwargs["stdout"].write(b"PARTIAL")
            raise subprocess.CalledProcessError(1, command, stderr="PRIVATE-SENTINEL")

        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(dependencies, "public_paths", return_value=[public]),
            patch.object(dependencies.subprocess, "run", side_effect=fail_export),
        ):
            output, errors = self.invoke("export", directory)
            self.assertEqual(output, "")
            self.assertNotIn("PRIVATE-SENTINEL", errors)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_main_bootstrap_requires_the_exact_current_passing_candidate(self):
        url = "https://github.com/edmundmiller/dotfiles/actions/runs/123"
        run = {
            "run_attempt": 2,
            "repository": {"full_name": "edmundmiller/dotfiles"},
            "head_repository": {"full_name": "edmundmiller/dotfiles"},
        }
        artifact = {
            "id": 456,
            "name": f"public-ha-v1-{self.sha}-2",
            "expired": False,
        }
        for case in (
            "valid",
            "old-attempt",
            "fork",
            "changed-run",
            "failed",
            "extra-file",
        ):
            imported = []
            reads = []

            def api(endpoint):
                if "/artifacts?" in endpoint:
                    item = artifact.copy()
                    if case == "old-attempt":
                        item["name"] = f"public-ha-v1-{self.sha}-1"
                    return {"artifacts": [item]}
                current = copy.deepcopy(run)
                if case == "fork":
                    current["head_repository"]["full_name"] = "fork/dotfiles"
                if case == "changed-run" and reads:
                    current["run_attempt"] = 3
                reads.append(endpoint)
                return current

            def execute(command, **kwargs):
                if command[0] == "gh":
                    with zipfile.ZipFile(kwargs["stdout"], "w") as zipped:
                        zipped.writestr(dependencies.ARCHIVE, b"PUBLIC-PACKAGES")
                        if case == "extra-file":
                            zipped.writestr("private-source", b"REJECT")
                else:
                    imported.append(kwargs["stdin"].read())

            with (
                self.subTest(case=case),
                tempfile.TemporaryDirectory() as directory,
                patch.object(dependencies.candidate_ci, "github", side_effect=api),
                patch.object(
                    dependencies.candidate_ci,
                    "passing_candidate",
                    side_effect=ValueError("Candidate is not passing")
                    if case == "failed"
                    else None,
                    return_value=url,
                ),
                patch.object(dependencies.subprocess, "run", side_effect=execute),
            ):
                self.invoke(
                    "restore-candidate",
                    directory,
                    env={"VALIDATION_BASE": "b" * 40},
                )
                self.assertEqual(
                    imported, [b"PUBLIC-PACKAGES"] if case == "valid" else []
                )
                if case != "valid":
                    self.assertEqual(list(Path(directory).iterdir()), [])

    def test_misses_and_import_errors_leave_validation_authoritative(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(self.invoke("restore", directory)[0], "")
            (Path(directory) / dependencies.ARCHIVE).write_bytes(b"CORRUPT")
            with patch.object(
                dependencies.subprocess,
                "run",
                side_effect=subprocess.CalledProcessError(1, ["nix-store", "--import"]),
            ):
                output, errors = self.invoke("restore", directory)
                self.assertEqual(output, "")
                self.assertIn("normal validation required", errors)

        workflow = (
            Path(__file__).resolve().parents[1] / ".github/workflows/ci.yml"
        ).read_text()
        script = textwrap.dedent(
            workflow.split("      - name: Validate (same runner as hey check)\n", 1)[1]
            .split("        run: |\n", 1)[1]
            .split("      - name:", 1)[0]
        )
        for status, package_builds in ((0, "false"), (17, "false"), (0, "true")):
            with (
                self.subTest(status=status, package_builds=package_builds),
                tempfile.TemporaryDirectory() as directory,
            ):
                trace = Path(directory) / "trace"
                fixture = (
                    'nix() { printf "%s\\n" "$*" > "$TRACE"; return "$STATUS"; }\n'
                )
                result = subprocess.run(
                    ["bash", "-e", "-c", fixture + script],
                    env=os.environ
                    | {
                        "NIX_GITHUB_TOKEN": "fixture-github",
                        "REX_TOKEN": "fixture-rex",
                        "VALIDATION_PACKAGE_BUILDS": package_builds,
                        "RUNNER_TEMP": directory,
                        "TRACE": str(trace),
                        "STATUS": str(status),
                    },
                    capture_output=True,
                )
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(
                    trace.read_text().strip(),
                    "shell .#validation-tools --command python3 scripts/validation.py --ci"
                    + (" --package-builds" if package_builds == "true" else ""),
                )
                self.assertEqual(list(Path(directory).glob("rex-netrc.*")), [])


if __name__ == "__main__":
    unittest.main()
