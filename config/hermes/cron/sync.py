#!/usr/bin/env python3
"""Sync repo-managed Hermes cron manifests through Hermes' cron API.

The gateway's jobs.json remains Hermes-owned state. This script reads manifests,
uses `hermes cron list --all` for discovery, then drives the same cronjob tool
API that backs `hermes cron create/edit` so fields missing from the CLI flags
(model/provider/toolsets/context) stay declarative too.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - exercised by users outside Nix
    yaml = None


JOB_HEADER_RE = re.compile(r"^\s{2}(?P<id>[0-9a-f]{6,})\s+\[(?P<state>[^]]+)\]")
NAME_RE = re.compile(r"^\s+Name:\s+(?P<name>.+?)\s*$")
STRING_FIELDS = ("name", "schedule", "prompt", "deliver", "workdir", "model", "provider", "base_url", "script")
LIST_FIELDS = ("skills", "context_from", "enabled_toolsets")


class SyncError(RuntimeError):
    pass


def load_manifest(path: Path) -> dict[str, Any]:
    if yaml is None:
        raise SyncError("PyYAML is required; run via Nix or install python3Packages.pyyaml")

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise SyncError(f"{path}: manifest must be a mapping")

    required = ("name", "schedule", "prompt")
    missing = [key for key in required if not data.get(key)]
    if missing:
        raise SyncError(f"{path}: missing required field(s): {', '.join(missing)}")

    for key in STRING_FIELDS:
        if key in data and data[key] is not None and not isinstance(data[key], str):
            raise SyncError(f"{path}: {key} must be a string")

    for key in LIST_FIELDS:
        value = data.get(key, [])
        if value is None:
            value = []
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            raise SyncError(f"{path}: {key} must be a list of strings")
        data[key] = value

    enabled = data.get("enabled", True)
    if not isinstance(enabled, bool):
        raise SyncError(f"{path}: enabled must be true or false")
    data["enabled"] = enabled

    if data.get("deliver") == "origin":
        print(
            f"warning: {path.name}: deliver=origin currently depends on a live origin target and is failing on this gateway",
            file=sys.stderr,
        )

    return data


def discover_jobs(hermes: str, dry_run: bool) -> dict[str, dict[str, str]]:
    if dry_run:
        return {}

    try:
        result = subprocess.run(
            [hermes, "cron", "list", "--all"],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        raise SyncError(f"failed to list Hermes cron jobs: {exc}") from exc

    jobs: dict[str, dict[str, str]] = {}
    current: dict[str, str] | None = None
    for line in result.stdout.splitlines():
        header = JOB_HEADER_RE.match(line)
        if header:
            current = {"id": header.group("id"), "state": header.group("state")}
            continue

        name = NAME_RE.match(line)
        if name and current:
            jobs[name.group("name")] = current
            current = None

    return jobs


def load_jobs_json(path: Path) -> dict[str, dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    jobs = data.get("jobs", data)
    if not isinstance(jobs, list):
        raise SyncError(f"{path}: expected jobs list")

    by_name: dict[str, dict[str, str]] = {}
    for job in jobs:
        if not isinstance(job, dict):
            continue
        name = job.get("name")
        job_id = job.get("id")
        if isinstance(name, str) and isinstance(job_id, str):
            by_name[name] = {
                "id": job_id,
                "state": "active" if job.get("enabled", True) else "paused",
            }
    return by_name


def hermes_python(hermes: str) -> str:
    path = shutil.which(hermes) or hermes
    hermes_path = Path(path).expanduser()
    if hermes_path.exists():
        sibling_python = hermes_path.with_name("python")
        if sibling_python.exists():
            return str(sibling_python)

        try:
            wrapper = hermes_path.read_text(encoding="utf-8", errors="ignore")[:2000]
        except OSError:
            wrapper = ""
        match = re.search(r'exec\s+"(?P<target>[^"]*/venv/bin/hermes)"', wrapper)
        if match:
            python = Path(match.group("target")).with_name("python")
            if python.exists():
                return str(python)

    raise SyncError(f"could not find Hermes venv python from {hermes!r}")


def api_payload(action: str, manifest: dict[str, Any], job_id: str | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "action": action,
        "schedule": manifest["schedule"],
        "prompt": manifest["prompt"],
        "name": manifest["name"],
        "skills": manifest["skills"],
        "deliver": manifest.get("deliver"),
        "model": manifest.get("model"),
        "provider": manifest.get("provider"),
        "base_url": manifest.get("base_url"),
        "script": manifest.get("script"),
        "context_from": manifest["context_from"] or None,
        "enabled_toolsets": manifest["enabled_toolsets"] or None,
        "workdir": manifest.get("workdir"),
        "no_agent": bool(manifest.get("no_agent", False)) or None,
    }
    if job_id:
        payload["job_id"] = job_id
    return {key: value for key, value in payload.items() if value is not None}


def call_cron_api(hermes: str, payload: dict[str, Any], dry_run: bool) -> None:
    if dry_run:
        compact = {key: ("<prompt>" if key == "prompt" else value) for key, value in payload.items()}
        print("hermes-cron-api " + json.dumps(compact, sort_keys=True))
        return

    code = """
import json
import sys
from tools.cronjob_tools import cronjob
payload = json.load(sys.stdin)
result = json.loads(cronjob(**payload))
print(json.dumps(result, sort_keys=True))
if not result.get('success'):
    raise SystemExit(1)
"""
    result = subprocess.run(
        [hermes_python(hermes), "-c", code],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "cron API failed").strip()
        raise SyncError(detail)
    print(result.stdout.strip())


def run_lifecycle(hermes: str, action: str, job_id: str, dry_run: bool) -> None:
    args = [hermes, "cron", action, job_id]
    if dry_run:
        print(" ".join(args))
        return
    subprocess.run(args, check=True, text=True)


def sync_manifest(hermes: str, manifest: dict[str, Any], existing: dict[str, dict[str, str]], dry_run: bool) -> None:
    name = manifest["name"]
    current = existing.get(name)
    if current:
        job_id = current["id"]
        call_cron_api(hermes, api_payload("update", manifest, job_id), dry_run)
        desired_state = "active" if manifest["enabled"] else "paused"
        if current.get("state") != desired_state:
            run_lifecycle(hermes, "resume" if manifest["enabled"] else "pause", job_id, dry_run)
        return

    call_cron_api(hermes, api_payload("create", manifest), dry_run)
    if not manifest["enabled"]:
        print(f"warning: {name!r} is disabled but was just created; run again to pause it", file=sys.stderr)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cron-dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--hermes", default="hermes", help="Hermes executable path/name")
    parser.add_argument("--dry-run", action="store_true", help="Print operations without mutating Hermes")
    parser.add_argument("--jobs-json", type=Path, help="Test hook: discover existing jobs from a jobs.json file")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    hermes = args.hermes
    if not args.dry_run and not shutil.which(hermes):
        raise SyncError(f"Hermes CLI not found: {hermes}")

    manifests = [load_manifest(path) for path in sorted(args.cron_dir.glob("*.yml"))]
    if not manifests:
        print(f"No cron manifests found in {args.cron_dir}")
        return 0

    existing = load_jobs_json(args.jobs_json) if args.jobs_json else discover_jobs(hermes, args.dry_run)
    for manifest in manifests:
        sync_manifest(hermes, manifest, existing, args.dry_run)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SyncError as exc:
        print(f"hermes-cron-sync: {exc}", file=sys.stderr)
        raise SystemExit(1)
