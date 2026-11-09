#!/usr/bin/env python3
"""Provision or inspect NUC's HA heartbeat without exporting credentials or HA data."""

import argparse
from collections import Counter
from datetime import UTC, datetime, timedelta
import json
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen

API = "https://healthchecks.io/api/v3"
SLUG = "nuc-ha-runtime"
# The existing NUC Gatus dead-man's switch owns the intended notification routing.
REFERENCE = "a6bbb4df-b118-4262-9881-9939f3ac7e76"


def request(key, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = Request(
        API + path,
        data=data,
        headers={"X-Api-Key": key, "Content-Type": "application/json"},
    )
    with urlopen(req, timeout=20) as response:
        return json.load(response)


def inspect(args):
    args.phase = "read_api_key"
    key = Path(args.api_key_file).read_text().strip()
    args.phase = "find_monitor"
    checks = request(key, f"/checks/?slug={SLUG}")["checks"]
    args.monitor_exists = bool(checks)
    if len(checks) > 1:
        raise ValueError("Heartbeat slug is ambiguous")
    args.phase = "read_reference_check"
    reference = request(key, f"/checks/{REFERENCE}")
    channels = reference["channels"]
    args.phase = "list_notification_channels"
    available = request(key, "/channels/")["channels"]
    args.phase = "validate_notification_channels"
    assigned = set(channels.split(",")) - {""}
    available_ids = {channel["id"] for channel in available}
    args.notification_channels = {
        "reference_count": len(assigned),
        "available_count": len(available),
        "missing_reference_count": len(assigned - available_ids),
        "available_kinds": sorted({channel["kind"] for channel in available}),
    }
    if not assigned or not assigned <= available_ids:
        raise ValueError("Existing NUC notification channels are missing")
    if not checks and args.action == "setup":
        # A retry first reads the slug again. Never blindly retry a POST after
        # an uncertain result, and never modify the reference check or channels.
        args.phase = "create_monitor"
        check = request(
            key,
            "/checks/",
            {
                "name": "nuc/ha-runtime",
                "slug": SLUG,
                "tags": "nuc home-assistant runtime",
                "desc": "Read-only HA runtime check every two minutes. No HA report bodies. Known April 17 backup warning retained.",
                "timeout": 300,
                "grace": 300,
                "channels": channels,
                "unique": ["slug"],
            },
        )
    elif len(checks) == 1:
        check = checks[0]
    else:
        raise ValueError("Heartbeat has not been provisioned")
    args.phase = "validate_monitor"
    if (
        check["slug"] != SLUG
        or check["timeout"] != 300
        or check["grace"] != 300
        or check.get("schedule")
        or check.get("methods", "") not in ("",)
        or check.get("manual_resume", False)
        or check.get("filter_http_body", False)
        or set(check["channels"].split(",")) != assigned
    ):
        raise ValueError("Heartbeat settings differ from the approved monitor")
    result = {
        "observed_at": datetime.now(UTC).isoformat(),
        "monitor": {
            field: check[field]
            for field in ("name", "slug", "status", "timeout", "grace", "n_pings", "last_ping")
        },
        "notification_channel_count": len(assigned),
        "notification_channel_kinds": sorted(
            {channel["kind"] for channel in available if channel["id"] in assigned}
        ),
    }
    if args.action == "setup":
        # Only approved setup can arm the timer. Ordinary deployments and
        # read-only inspection must not start an unprovisioned heartbeat.
        args.phase = "record_provisioning"
        args.ready_file.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        args.ready_file.touch(mode=0o644)
        result["provisioned"] = True
        return result

    result["provisioned"] = args.ready_file.is_file()
    cutoff = datetime.now(UTC) - timedelta(hours=args.since_hours)
    uuid = check["uuid"]
    args.phase = "read_ping_history"
    pings = request(key, f"/checks/{uuid}/pings/")["pings"]
    result["pings"] = [
        {"type": ping["type"], "date": ping["date"], "has_body": bool(ping["body_url"])}
        for ping in pings
        if datetime.fromisoformat(ping["date"]) >= cutoff
    ]
    result["ping_history_oldest_available"] = pings[-1]["date"] if pings else None
    args.phase = "read_status_changes"
    result["flips"] = request(key, f"/checks/{uuid}/flips/?start={int(cutoff.timestamp())}")
    args.phase = "read_health_journal"
    journal = subprocess.run(
        ["journalctl", "-u", "hass-health.service", "--since", cutoff.isoformat(), "-o", "cat", "--no-pager"],
        check=True, capture_output=True, text=True, timeout=20,
    )
    reports = []
    for line in journal.stdout.splitlines():
        if not line.startswith("{"):
            continue
        report = json.loads(line)
        if report.get("schema_version") == 1 and "observed_at" in report:
            reports.append(report)
    reports.sort(key=lambda report: report["observed_at"])
    statuses = Counter(report["status"] for report in reports)
    failures = Counter(
        name
        for report in reports
        for name, check_result in report.get("checks", {}).items()
        if check_result["status"] != "healthy"
    )
    result["journal"] = {
        "reports": len(reports),
        "statuses": dict(statuses),
        "failing_checks": dict(failures),
        "first_observed_at": reports[0]["observed_at"] if reports else None,
        "last_observed_at": reports[-1]["observed_at"] if reports else None,
        "last_status": reports[-1]["status"] if reports else None,
    }
    correlation = Counter()
    for ping in result["pings"]:
        if ping["type"] not in ("success", "fail"):
            continue
        preceding = [
            report for report in reports
            if 0 <= (datetime.fromisoformat(ping["date"]) - datetime.fromisoformat(report["observed_at"])).total_seconds() <= 90
        ]
        state = preceding[-1]["status"] if preceding else "uncorrelated"
        correlation[f"{ping['type']}_{state}"] += 1
    result["ping_report_correlation"] = dict(correlation)
    args.phase = "read_timer_state"
    result["timer_active"] = subprocess.run(
        ["systemctl", "is-active", "--quiet", "hass-health.timer"],
        check=False, timeout=10,
    ).returncode == 0
    result["coverage"] = "Journal aggregate only; API ping history may be capped. No HA report contents or ping bodies exported. Physical outcomes and restic freshness not checked."
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "status"))
    parser.add_argument("--api-key-file", default="/run/agenix/healthchecks-api-key")
    parser.add_argument("--ready-file", type=Path, default=Path(f"/var/lib/hass-health/{SLUG}.ready"))
    parser.add_argument("--since-hours", type=int, choices=range(1, 25), default=2)
    parser.add_argument("--require-live", action="store_true")
    args = parser.parse_args()
    args.monitor_exists = None
    args.notification_channels = None
    try:
        result = inspect(args)
        print(json.dumps(result, sort_keys=True))
        if args.require_live:
            recent = datetime.now(UTC) - timedelta(minutes=5)
            return 0 if (
                args.action == "status"
                and result["provisioned"]
                and result["timer_active"]
                and result["monitor"]["status"] == "up"
                and result["monitor"]["n_pings"] >= 2
                and result["monitor"]["last_ping"]
                and datetime.fromisoformat(result["monitor"]["last_ping"]) >= recent
                and sum(ping["type"] == "success" and datetime.fromisoformat(ping["date"]) >= recent for ping in result["pings"]) >= 2
                and result["journal"]["reports"] >= 2
                and result["journal"]["last_status"] == "healthy"
                and datetime.fromisoformat(result["journal"]["last_observed_at"]) >= recent
                and not any(ping["has_body"] for ping in result["pings"])
            ) else 1
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        # Never print API responses, credential contents, addresses, or journal lines.
        if isinstance(error, HTTPError):
            error.close()
        print(json.dumps({
            "status": "unknown",
            "phase": args.phase,
            "error_type": type(error).__name__,
            "http_status": error.code if isinstance(error, HTTPError) else None,
            "monitor_existed_before_setup": args.monitor_exists,
            "notification_channels": args.notification_channels,
            "error": "Monitor inspection failed. For uncertain setup, read the existing slug before retrying; never blindly repeat a write.",
        }))
        return 2


if __name__ == "__main__":
    sys.exit(main())
