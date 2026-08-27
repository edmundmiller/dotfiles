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
        script.write_text(
            source.replace(args.rendered_home, str(profile_home)), encoding="utf-8"
        )
        script.chmod(0o700)
        env = os.environ.copy()
        env["HERMES_HOME"] = str(wrong_home)

        # Concurrent timer completions must not collide or leave temporary
        # marker files behind. Both writers are expected to publish valid JSON.
        processes = [
            subprocess.Popen(
                ["bash", str(script)],
                check=False,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for _ in range(2)
        ]
        results = [process.communicate() for process in processes]
        failures = [result for result in results if result[0] != 0]
        if failures:
            raise AssertionError(f"concurrent marker writers failed: {failures}")

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
            raise AssertionError("marker writer replaced a marker directory")
        if not marker.is_dir():
            raise AssertionError("marker directory was removed after a failed write")
        if list(marker.parent.glob(".executor.json.*")):
            raise AssertionError("failed marker write left temporary files behind")


if __name__ == "__main__":
    main()
