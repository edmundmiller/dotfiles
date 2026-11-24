#!/usr/bin/env python3
"""Read the last 24 hours of allowlisted critical-entity journal evidence."""

from datetime import datetime, timedelta, timezone
import json
import subprocess
import sys

ENTITIES = {
    "climate.main_floor",
    "climate.master_suite",
    "script.goodnight",
    "script.good_morning",
    "script.get_ready_for_bed",
}


def main():
    end = datetime.now(timezone.utc)
    start = end - timedelta(hours=24)
    journal = subprocess.run(
        ["journalctl", "-u", "hass-health.service", "--since", start.isoformat(),
         "--until", end.isoformat(), "-o", "cat", "--no-pager"],
        capture_output=True, text=True, check=True, timeout=20,
    )
    failures = []
    reports = []
    omitted_failures = 0
    for line in journal.stdout.splitlines():
        if not line.startswith("{"):
            continue
        item = json.loads(line)
        if item.get("schema_version") != 1 or "checks" not in item:
            continue
        observed = datetime.fromisoformat(item["observed_at"].replace("Z", "+00:00"))
        if not start <= observed <= end:
            continue
        critical = item["checks"]["critical_entities"]
        status = critical["status"]
        if status not in ("healthy", "unhealthy", "unknown"):
            raise ValueError("Invalid status")
        report = {"observed_at": observed.isoformat(), "status": status}
        reports.append(report)
        if status != "healthy":
            selected = []
            for failure in critical.get("failures", []):
                if (failure.get("entity_id") in ENTITIES
                        and failure.get("state") in ("missing", "unknown", "unavailable")):
                    selected.append({"entity_id": failure["entity_id"], "state": failure["state"]})
                else:
                    omitted_failures += 1
            failures.append({**report, "failures": selected})
    reports.sort(key=lambda report: report["observed_at"])
    failures.sort(key=lambda report: report["observed_at"])
    print(json.dumps({
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "window_start": start.isoformat(), "window_end": end.isoformat(),
        "retained_reports": len(reports),
        "first_report": reports[0] if reports else None,
        "last_report": reports[-1] if reports else None,
        "nonhealthy_critical_reports": failures,
        "omitted_unrecognized_failures": omitted_failures,
        "coverage": "Retained checker reports only; no raw logs, attributes, credentials, HA writes, or physical root-cause evidence.",
    }, sort_keys=True))
    return 0 if reports else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "unknown", "error_type": type(error).__name__}))
        sys.exit(2)
