#!/usr/bin/env python3
"""Exercise the rendered systemd cron heartbeat writer."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import tempfile


def _run(script: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(script)],
        check=False,
        env=env,
        text=True,
        capture_output=True,
    )


def _write_rendered_script(
    source: str, rendered_home: str, replacement_home: Path, script: Path
) -> None:
    rendered_profile_home = Path(rendered_home).parent
    replacement_profile_home = replacement_home.parent
    script.write_text(
        source.replace(str(rendered_profile_home), str(replacement_profile_home)),
        encoding="utf-8",
    )
    script.chmod(0o700)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True)
    parser.add_argument("--script", type=Path, required=True)
    parser.add_argument("--rendered-home", required=True)
    args = parser.parse_args()

    source = args.script.read_text(encoding="utf-8")
    if args.rendered_home not in source:
        raise AssertionError(
            "rendered marker writer does not use its fixed profile home"
        )

    with tempfile.TemporaryDirectory(prefix="hermes-cron-marker-") as temp:
        root = Path(temp)
        profile_home = root / "hermes" / args.profile / ".hermes"
        wrong_home = root / "wrong-hermes-home"
        script = root / "marker-writer"
        _write_rendered_script(source, args.rendered_home, profile_home, script)
        env = os.environ.copy()
        env["HERMES_HOME"] = str(wrong_home)

        # Concurrent timer completions must not collide or leave temporary
        # marker files behind. Both writers are expected to publish valid JSON.
        processes = [
            subprocess.Popen(
                ["bash", str(script)],
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for _ in range(2)
        ]
        results = []
        for process in processes:
            stdout, stderr = process.communicate()
            results.append(
                {
                    "returncode": process.returncode,
                    "stdout": stdout,
                    "stderr": stderr,
                }
            )
        failures = [result for result in results if result["returncode"] != 0]
        if failures:
            raise AssertionError(f"concurrent marker writers failed: {failures!r}")

        marker = profile_home / "cron" / "executor.json"
        if marker.is_dir() or not marker.is_file():
            raise AssertionError(
                f"marker was not published as a regular file: {marker}"
            )
        payload = json.loads(marker.read_text(encoding="utf-8"))
        if set(payload) != {"kind", "unit", "heartbeat_at", "max_age_seconds"}:
            raise AssertionError(f"unexpected marker fields: {payload}")
        if payload["kind"] != "systemd":
            raise AssertionError(f"unexpected marker kind: {payload}")
        expected_unit = f"hermes-{args.profile}-cron-tick.timer"
        if payload["unit"] != expected_unit:
            raise AssertionError(f"unexpected marker unit: {payload}")
        if payload["max_age_seconds"] != 180:
            raise AssertionError(f"unexpected marker age: {payload}")
        heartbeat = datetime.fromisoformat(payload["heartbeat_at"])
        if heartbeat.tzinfo is None:
            raise AssertionError(f"marker heartbeat lacks timezone: {payload}")
        age = (datetime.now(timezone.utc) - heartbeat).total_seconds()
        if not -5 <= age <= payload["max_age_seconds"]:
            raise AssertionError(
                f"marker heartbeat is not fresh: age={age}, payload={payload}"
            )
        if list((marker.parent).glob(".executor.json.*")):
            raise AssertionError("marker writer left temporary files behind")
        if (wrong_home / "cron" / "executor.json").exists():
            raise AssertionError("marker writer followed mutable HERMES_HOME")

        # A pre-existing directory is never replaced by the atomic publish.
        marker.unlink()
        marker.mkdir()
        result = _run(script, env)
        if result.returncode == 0:
            raise AssertionError(
                "marker writer replaced a marker directory: "
                f"stdout={result.stdout!r} stderr={result.stderr!r}"
            )
        if not marker.is_dir():
            raise AssertionError("marker directory was removed after a failed write")
        if "refusing to replace executor marker directory" not in result.stderr:
            raise AssertionError(
                "marker writer failed without explaining the directory refusal: "
                f"stdout={result.stdout!r} stderr={result.stderr!r}"
            )
        if list(marker.parent.glob(".executor.json.*")):
            raise AssertionError("failed marker write left temporary files behind")

        # A profile directory, its fixed .hermes home, or its cron directory
        # must not be followed when an alias is present at any of those levels.
        def run_alias_case(
            name: str, replacement_home: Path, expected_error: str
        ) -> subprocess.CompletedProcess[str]:
            alias_script = root / name
            _write_rendered_script(
                source, args.rendered_home, replacement_home, alias_script
            )
            alias_result = _run(alias_script, env)
            if alias_result.returncode == 0:
                raise AssertionError(
                    f"marker writer followed an alias for {name}: "
                    f"stdout={alias_result.stdout!r} "
                    f"stderr={alias_result.stderr!r}"
                )
            if expected_error not in alias_result.stderr:
                raise AssertionError(
                    f"marker writer rejected {name} without a diagnostic: "
                    f"stdout={alias_result.stdout!r} "
                    f"stderr={alias_result.stderr!r}"
                )
            return alias_result

        profile_alias_root = root / "profile-alias"
        profile_alias_target = root / "profile-alias-target"
        profile_alias_target.mkdir()
        profile_alias_root.symlink_to(profile_alias_target, target_is_directory=True)
        profile_alias_home = profile_alias_root / ".hermes"
        run_alias_case(
            "profile-alias-writer",
            profile_alias_home,
            "refusing symlinked Hermes profile home",
        )
        if (profile_alias_target / ".hermes").exists():
            raise AssertionError("marker writer followed a profile home alias")

        hermes_alias_root = root / "hermes-alias"
        hermes_alias_root.mkdir()
        hermes_alias_target = root / "hermes-alias-target"
        hermes_alias_target.mkdir()
        hermes_alias_home = hermes_alias_root / ".hermes"
        hermes_alias_home.symlink_to(hermes_alias_target, target_is_directory=True)
        run_alias_case(
            "hermes-home-alias-writer",
            hermes_alias_home,
            "refusing symlinked Hermes home",
        )
        if (hermes_alias_target / "cron").exists():
            raise AssertionError("marker writer followed a Hermes home alias")

        cron_alias_root = root / "cron-alias"
        cron_alias_home = cron_alias_root / ".hermes"
        cron_alias_home.mkdir(parents=True)
        cron_alias_target = root / "cron-alias-target"
        cron_alias_target.mkdir()
        (cron_alias_home / "cron").symlink_to(
            cron_alias_target, target_is_directory=True
        )
        run_alias_case(
            "cron-directory-alias-writer",
            cron_alias_home,
            "refusing symlinked cron directory",
        )
        if (cron_alias_target / "executor.json").exists():
            raise AssertionError("marker writer followed a cron directory alias")


if __name__ == "__main__":
    main()
