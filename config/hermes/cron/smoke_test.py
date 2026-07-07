#!/usr/bin/env -S uv run --script
#
# /// script
# dependencies = [
#   "pyyaml",
# ]
# [tool.uv]
# exclude-newer = "2026-07-07T00:00:00Z"
# ///
"""Smoke-test repo-managed Hermes cron sync without a real Hermes gateway.

Run: uv run --script config/hermes/cron/smoke_test.py
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ENTRYPOINT = ROOT / "bin" / "hermes-cron-sync"
if not ENTRYPOINT.exists():
    ENTRYPOINT = ROOT / "config" / "hermes" / "cron" / "sync.py"


def write(path: Path, content: str) -> None:
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")


def run_sync(cron_dir: Path, jobs_json: Path) -> tuple[list[dict[str, object]], list[str]]:
    command = [str(ENTRYPOINT)] if ENTRYPOINT.name == "hermes-cron-sync" else [sys.executable, str(ENTRYPOINT)]
    result = subprocess.run(
        command
        + [
            "--cron-dir",
            str(cron_dir),
            "--dry-run",
            "--jobs-json",
            str(jobs_json),
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    payloads: list[dict[str, object]] = []
    lifecycle: list[str] = []
    for line in result.stdout.splitlines():
        if line.startswith("hermes-cron-api "):
            payloads.append(json.loads(line.removeprefix("hermes-cron-api ")))
        elif line:
            lifecycle.append(line)
    return payloads, lifecycle


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="hermes-cron-smoke-") as tmp:
        root = Path(tmp)
        cron_dir = root / "cron"
        cron_dir.mkdir()

        write(
            cron_dir / "alpha.yml",
            """
            name: new-with-skills
            schedule: 15 9 * * 1-5
            deliver: origin
            workdir: /tmp/hermes-smoke
            enabled: true
            skills:
              - acpx-claude
            prompt: |
              create me
            """,
        )
        write(
            cron_dir / "beta.yml",
            """
            name: existing-null-skills
            schedule: 0 8 * * 1-5
            enabled: true
            skills:
            prompt: |
              edit me
            """,
        )

        first_jobs = root / "first-jobs.json"
        first_jobs.write_text(
            json.dumps({
                "jobs": [
                    {"id": "be0001", "name": "existing-null-skills", "enabled": False},
                ]
            }),
            encoding="utf-8",
        )
        payloads, lifecycle = run_sync(cron_dir, first_jobs)
        assert len(payloads) == 2, payloads
        assert {payload["action"] for payload in payloads} == {"create", "update"}, payloads

        create = next(payload for payload in payloads if payload["action"] == "create")
        update = next(payload for payload in payloads if payload["action"] == "update")
        assert create["name"] == "new-with-skills", create
        assert create["skills"] == ["acpx-claude"], create
        assert create["deliver"] == "origin", create
        assert create["workdir"] == "/tmp/hermes-smoke", create
        assert update["job_id"] == "be0001", update
        assert update["name"] == "existing-null-skills", update
        assert update["skills"] == [], update
        assert lifecycle == ["hermes cron resume be0001"], lifecycle

        second_jobs = root / "second-jobs.json"
        second_jobs.write_text(
            json.dumps({
                "jobs": [
                    {"id": "aa0002", "name": "new-with-skills", "enabled": True},
                    {"id": "be0001", "name": "existing-null-skills", "enabled": True},
                ]
            }),
            encoding="utf-8",
        )
        payloads, lifecycle = run_sync(cron_dir, second_jobs)
        assert len(payloads) == 2, payloads
        assert {payload["action"] for payload in payloads} == {"update"}, payloads
        assert {payload["job_id"] for payload in payloads} == {"aa0002", "be0001"}, payloads
        assert lifecycle == [], lifecycle

    print("hermes cron sync smoke: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
